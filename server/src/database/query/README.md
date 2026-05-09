# Kịch bản kiểm thử truy vấn — SQL Server vs Cassandra

Thư mục này chứa hai file kịch bản kiểm thử song song nhau, mỗi file thực hiện cùng ba testcase trên hai hệ quản trị cơ sở dữ liệu khác nhau để quan sát sự khác biệt về cơ chế xử lý truy vấn.

| File        | Hệ thống                  | Công cụ chạy       |
| ----------- | ------------------------- | ------------------ |
| `query.sql` | Microsoft SQL Server 2022 | SSMS hoặc `sqlcmd` |
| `query.cql` | Apache Cassandra          | `cqlsh`            |

---

## Yêu cầu trước khi chạy

### SQL Server

- SQL Server 2022 đang chạy (local hoặc Docker)
- Schema và dữ liệu đã được khởi tạo (xem hướng dẫn tại [`server/src/database/README.md`](../README.md))
- Stored procedure `dbo.sp_SearchMentors` và `dbo.sp_DashboardStatistics` đã được tạo

### Cassandra

- Cassandra node đang chạy (local hoặc Docker)
- Keyspace và các bảng đã tồn tại:
  - `mentors_by_skill`
  - `meetings_by_mentor`
  - `revenue_by_mentor`
- Dữ liệu mẫu đã được nạp vào các bảng trên

---

## Cách chạy

### Chạy `query.sql` trên SQL Server

**Dùng SSMS (SQL Server Management Studio):**

1. Mở SSMS, kết nối tới SQL Server instance
2. Mở file `query.sql` (`File → Open → File...`)
3. Chọn đúng database (`USE mentoria` hoặc tên database tương ứng)
4. Chạy từng testcase bằng cách bôi đen đoạn cần chạy rồi nhấn **F5**

**Dùng `sqlcmd` (command line):**

```powershell
sqlcmd -S localhost -d mentoria -U <DB_USER> -P <DB_PASS> -i query.sql
```

**Đọc kết quả đo lường:**

- `SET STATISTICS TIME ON` → xem thời gian CPU và elapsed time trong tab **Messages**
- `SET STATISTICS IO ON` → xem số **logical reads** (số trang dữ liệu được đọc từ buffer pool)

---

### Chạy `query.cql` trên Cassandra

**Khởi động `cqlsh`:**

```bash
# Kết nối local (Cassandra cài trực tiếp trên máy)
cqlsh

# Hoặc chỉ định host/port
cqlsh 127.0.0.1 9042
```

**Nếu chạy Cassandra bằng Docker**, `cqlsh` phải được chạy bên trong container thay vì gọi trực tiếp từ máy host, vì `TRACING` yêu cầu phiên làm việc tương tác (interactive session) — không thể dùng cờ `-f` để pipe file vào từ bên ngoài và nhận trace output đầy đủ.

Truy cập vào container trước, sau đó mở `cqlsh`:

```bash
# Thay 'cassandra' bằng tên container thực tế (kiểm tra bằng: docker ps)
docker exec -it cassandra cqlsh
```

Sau khi vào được prompt `cqlsh>`, chạy các câu lệnh theo hướng dẫn phía dưới như bình thường.

**Chọn keyspace trước khi chạy:**

```cql
USE mentoria;
```

**Chạy từng câu lệnh:** Dán từng khối lệnh vào `cqlsh` và nhấn Enter.

**Chạy cả file:**

```bash
cqlsh -f query.cql
```

> **Lưu ý:** `query.cql` có dòng placeholder `mentor_id = 00000000-0000-0000-0000-000000000001` ở Testcase 2 Bước 2. Thay bằng một `mentor_id` thực tế có trong bảng `meetings_by_mentor` trước khi chạy.

---

## Mô tả các testcase

### Testcase 1 — Plan Cache

**Mục tiêu:** Quan sát tác động của bộ nhớ đệm execution plan lên thời gian thực thi.

|                      | SQL Server                                                                         | Cassandra                                                       |
| -------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| **Lần 1**            | `DBCC FREEPROCCACHE` xóa cache → cold execution, optimizer phải biên dịch lại plan | `TRACING ON` → ghi lại trace đầy đủ                             |
| **Lần 2**            | Plan đã được cache → warm execution, bỏ qua bước biên dịch                         | `TRACING ON` → Cassandra parse lại từ đầu (không có plan cache) |
| **Kết quả mong đợi** | Elapsed time Lần 2 < Lần 1 (plan được tái sử dụng)                                 | Thời gian Lần 1 ≈ Lần 2 (không có cơ chế cache)                 |

---

### Testcase 2 — Query Translation Pipeline

**Business query:** Tìm tất cả Mentor có kỹ năng React, rating ≥ 4.0, country = United States, đã có ít nhất 1 phiên Completed trong 365 ngày gần nhất; sắp xếp theo doanh thu giảm dần.

|                    | SQL Server                                  | Cassandra                                            |
| ------------------ | ------------------------------------------- | ---------------------------------------------------- |
| **Cách thực hiện** | 1 câu lệnh SELECT với nhiều JOIN + GROUP BY | 3 bước riêng biệt, kết quả giao nhau ở tầng ứng dụng |
| **Lý do**          | Optimizer tự tìm execution plan tối ưu      | Không hỗ trợ JOIN cross-partition hay GROUP BY       |

**Các bước phía Cassandra:**

1. **Bước 1** — Lọc mentor theo `skill_name` (partition key) và `rating` (clustering column); lọc `country` tại application
2. **Bước 2** — Với mỗi `mentor_id`, truy vấn `meetings_by_mentor` lọc theo `meeting_date` và `status` (cần `ALLOW FILTERING`)
3. **Bước 3** — Đọc doanh thu từ bảng pre-aggregated `revenue_by_mentor` thay vì `SUM()` lúc runtime

---

### Testcase 3 — Heuristic Optimization & Predicate Pushdown

**Mục tiêu:** Quan sát khả năng optimizer tự động thu hẹp phạm vi quét dữ liệu theo điều kiện date range.

|                      | SQL Server                                                            | Cassandra                                                            |
| -------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **Lần 1**            | Date range 12 tháng — invoices scan lớn, logical reads cao            | Đọc toàn bộ partition `'all'`                                        |
| **Lần 2**            | Date range 3 tháng — invoices scan nhỏ hơn, logical reads giảm rõ rệt | Query **giống hệt** Lần 1 (không thể biểu diễn điều kiện date range) |
| **Kết quả mong đợi** | Logical reads Lần 2 < Lần 1                                           | Logical reads Lần 1 = Lần 2                                          |

**Điểm tương phản chính:** SQL Server tự động điều chỉnh execution plan tại runtime theo giá trị tham số. Cassandra không có optimizer — hiệu quả filter hoàn toàn phụ thuộc vào schema design từ lúc thiết kế (phải "bake" điều kiện lọc vào data model).

---

## Cách đọc kết quả

### SQL Server — `STATISTICS TIME`

```
SQL Server Execution Times:
   CPU time = 16 ms, elapsed time = 45 ms.
```

So sánh **elapsed time** giữa các lần chạy.

### SQL Server — `STATISTICS IO`

```
Table 'invoices'. Scan count 1, logical reads 312, ...
```

So sánh **logical reads** giữa Lần 1 (12 tháng) và Lần 2 (3 tháng) trong Testcase 3.

### Cassandra — `TRACING`

Sau mỗi câu lệnh có `TRACING ON`, `cqlsh` in ra bảng trace gồm:

- **activity** — các bước xử lý nội bộ
- **duration** — thời gian mỗi bước (microseconds)
- **source** — node xử lý

So sánh tổng duration giữa các lần chạy để xác nhận Cassandra không có plan cache.
