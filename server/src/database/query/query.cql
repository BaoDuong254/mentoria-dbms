-- Testcase 1: Plan cache

-- Lần 1
TRACING ON;
SELECT mentor_id, first_name, last_name, rating
FROM mentors_by_skill
WHERE skill_name = 'React'
LIMIT 10;
TRACING OFF;

-- Lần 2: cùng cấu trúc query, param khác — Cassandra vẫn parse lại (không có plan cache)
TRACING ON;
SELECT mentor_id, first_name, last_name, rating
FROM mentors_by_skill
WHERE skill_name = 'Python'
LIMIT 10;
TRACING OFF;

-- Testcase 2: Query Translation Pipeline
-- Business query: "Tìm tất cả Mentor có kỹ năng React, rating >= 4.0, country = United States,
-- đã có ít nhất 1 phiên Completed trong 365 ngày gần nhất; sắp xếp theo doanh thu giảm dần."
--
-- SQL Server thực hiện toàn bộ trong 1 câu lệnh: parser → optimizer → execution plan → result.
-- Cassandra KHÔNG hỗ trợ JOIN hay GROUP BY cross-partition.
-- Truy vấn phải được tách thành 3 bước độc lập; kết quả giao nhau ở tầng ứng dụng.

-- Bước 1: Lọc mentor theo skill và rating
-- skill_name = partition key  → single-partition read, không scan toàn bảng
-- rating >= 4.0              → hợp lệ vì rating là clustering column (ORDER BY rating DESC)
-- country = 'United States'  → KHÔNG nằm trong primary key, phải lọc ở application sau khi nhận kết quả
SELECT mentor_id, first_name, last_name, rating, country, status
FROM mentors_by_skill
WHERE skill_name = 'React'
  AND rating >= 4.0
LIMIT 100;

-- Bước 2: Với mỗi mentor_id (đã lọc country + status ở app), lấy các meeting Completed trong 365 ngày
-- Cassandra không JOIN — đây là N queries riêng biệt, mỗi query cho 1 mentor_id
-- meeting_date >= ? → hợp lệ vì meeting_date là clustering column
-- status = 'Completed' → dùng secondary index (idx_meetings_mentor_status), cần ALLOW FILTERING
SELECT meeting_id, meeting_date, status, amount_paid
FROM meetings_by_mentor
WHERE mentor_id = 00000000-0000-0000-0000-000000000001 -- placeholder value
  AND meeting_date >= '2025-01-07'
  AND status = 'Completed'
ALLOW FILTERING;

-- Bước 3: Đọc doanh thu từ bảng pre-aggregated thay cho SUM(inv.amount_total) trong SQL Server
-- revenue_by_mentor được ghi sẵn mỗi khi có invoice → không aggregate lúc query
-- ORDER BY total_revenue DESC khả thi vì total_revenue là clustering column
SELECT mentor_id, mentor_name, total_revenue, completed_meetings
FROM revenue_by_mentor
WHERE bucket = 'all'
ORDER BY total_revenue DESC
LIMIT 50;

-- Testcase 3: Heuristic Optimization — Predicate Pushdown
--
-- SQL Server tự động thu hẹp invoices scan dựa trên @StartDate/@EndDate tại runtime.
-- Cassandra không có optimizer — hiệu quả filter hoàn toàn do schema design quyết định.
--
-- revenue_by_mentor: PRIMARY KEY ((bucket), total_revenue DESC, mentor_id)
-- Không có cột ngày trong primary key → không thể đẩy date predicate xuống storage layer.
-- Hệ quả: dù muốn lấy dữ liệu 12 tháng hay 30 ngày, Cassandra vẫn đọc cùng 1 partition.

-- Lần 1 — Tương đương SQL Server lần 1 (12 tháng): đọc toàn bộ partition 'all'
TRACING ON;
SELECT mentor_id, mentor_name, total_revenue, completed_meetings
FROM revenue_by_mentor
WHERE bucket = 'all'
ORDER BY total_revenue DESC
LIMIT 50;
TRACING OFF;

-- Lần 2 — Tương đương SQL Server lần 2 (3 tháng): query buộc phải giống hệt lần 1
-- revenue_by_mentor không có cột ngày trong schema → không thể biểu diễn điều kiện "3 tháng"
-- dù bằng cú pháp nào. Cassandra đọc cùng 1 partition, cùng lượng data.
-- Đây chính là điểm tương phản: SQL Server logical reads giảm từ lần 1 → lần 2;
-- Cassandra không có gì thay đổi.
TRACING ON;
SELECT mentor_id, mentor_name, total_revenue, completed_meetings
FROM revenue_by_mentor
WHERE bucket = 'all'
ORDER BY total_revenue DESC
LIMIT 50;
TRACING OFF;

-- Kết luận: SQL Server tự động điều chỉnh execution plan theo date range tại runtime
-- (logical reads giảm từ lần 1 → lần 2).
-- Cassandra không có optimizer → 2 query trên đọc cùng lượng data, date range không tác động gì.
--
-- Phương án duy nhất để đạt hiệu quả tương đương: redesign schema tại design time
-- developer phải "bake" chiến lược filter vào data model ngay từ đầu:
--
-- CREATE TABLE revenue_by_mentor_monthly (
--   bucket          TEXT,
--   year_month      TEXT,    -- 'YYYY-MM' — clustering column, cho phép range scan theo tháng
--   mentor_id       UUID,
--   monthly_revenue DECIMAL,
--   PRIMARY KEY ((bucket), year_month, mentor_id)
-- ) WITH CLUSTERING ORDER BY (year_month DESC, mentor_id ASC);
--
-- WHERE bucket = 'global' AND year_month >= '2025-11'  -- tương đương filter 6 tháng
-- → Đây là "manual predicate pushdown" — developer tự quyết định tại design time,
--   không có optimizer nào làm điều này tự động tại runtime.
