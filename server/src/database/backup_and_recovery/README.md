📘 HƯỚNG DẪN KIỂM THỬ: SAO LƯU & KHÔI PHỤC (DBMS)
Tài liệu này hướng dẫn cách chạy kịch bản "Giả lập thảm họa và Khôi phục dữ liệu" trên cả hai hệ quản trị SQL Server và Cassandra.

# 1. SQL Server (Thao tác trên SSMS)

Bước 1: Tạo bản sao lưu (Backup).

Mở SSMS, mở một Query mới và chạy:

SQL
USE master;
GO
BACKUP DATABASE [mentoria]
TO DISK = N'D:\mentoria-dbms-main\mentoria.bak' -- Lưu ý: Sửa đúng đường dẫn folder
WITH FORMAT, INIT, NAME = 'Full Backup of mentoria';
GO

Mở theo đường link sẽ thấy file back up

Bước 2: Giả lập thảm họa (Disaster)

USE [mentoria];
GO

-- 1. Tắt tạm thời kiểm tra ràng buộc (Safety First)
EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";

-- 2. NHÓM 1: Các bảng giao dịch và tương tác (Xóa đầu tiên)
-- Đây là những bảng chứa dữ liệu phát sinh từ người dùng
DELETE FROM dbo.feedbacks;
DELETE FROM dbo.messages;
DELETE FROM dbo.sended;
DELETE FROM dbo.meetings;
DELETE FROM dbo.invoices;
DELETE FROM dbo.bookings;
DELETE FROM dbo.slots;

-- 3. NHÓM 2: Các bảng chi tiết của Plan và Profile
DELETE FROM dbo.mentorships_benefits;
DELETE FROM dbo.plan_sessions;
DELETE FROM dbo.plan_mentorships;
DELETE FROM dbo.plan_registerations; -- Tên bảng theo file seed của ông
DELETE FROM dbo.mentor_languages;
DELETE FROM dbo.set_skill;
DELETE FROM dbo.own_skill;
DELETE FROM dbo.work_for;
DELETE FROM dbo.user_social_links;

-- 4. NHÓM 3: Các bảng thực thể chính (Cha của nhóm 1 & 2)
DELETE FROM dbo.plans;
DELETE FROM dbo.mentors;
DELETE FROM dbo.mentees;

-- 5. NHÓM 4: Các bảng danh mục và gốc (Gốc của toàn bộ hệ thống)
DELETE FROM dbo.users;
DELETE FROM dbo.categories;
DELETE FROM dbo.skills;
DELETE FROM dbo.companies;
DELETE FROM dbo.job_title;
DELETE FROM dbo.discounts;
DELETE FROM dbo.notifications;

-- 6. Bật lại kiểm tra ràng buộc
EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";

-- 7. Reset Identity (Tùy chọn)
-- Nếu ông muốn lần sau INSERT data nó bắt đầu lại từ ID = 1
-- EXEC sp_MSforeachtable "DBCC CHECKIDENT ('?', RESEED, 0)";

Bước 3: Khôi phục (Recovery)
Trước khi khôi phục cần tắt server đi để tránh deadlock
Chạy lệnh Restore:

SQL
USE master;
GO
ALTER DATABASE [mentoria] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [mentoria] FROM DISK = N'D:\mentoria-dbms-main\mentoria.bak' WITH REPLACE;
ALTER DATABASE [mentoria] SET MULTI_USER;
GO
Kiểm chứng: F5 lại Web, dữ liệu sẽ quay lại đầy đủ. ✅

# 2. Hệ quản trị Cassandra (Thao tác trên Docker & DataGrip)

Kịch bản này kiểm tra khả năng High Availability (HA) và Fault Tolerance (Chịu lỗi). Hệ thống được thiết lập với 2 Node chạy song song, dữ liệu được tự động nhân bản (Replicated).

Bước 1: Khởi tạo Cluster 2 Node bằng Docker
Để tạo node phụ và kết nối vào node chính, sử dụng tham số --link và cấu hình RAM phù hợp:

PowerShell
1.Khởi chạy Node chính (Seed Node)
docker run --name cassandra-bachkhoa -p 9042:9042 -e CASSANDRA_HEAP_SIZE=512M -e CASSANDRA_MAX_HEAP_SIZE=1G -d cassandra:latest

2.Khởi chạy Node phụ (Secondary Node)
Đợi Node chính hiện trạng thái 'Healthy' hoặc 'Running' rồi mới chạy lệnh này
docker run --name cassandra-node-2 --link cassandra-bachkhoa:cassandra -e CASSANDRA_HEAP_SIZE=512M -e CASSANDRA_MAX_HEAP_SIZE=1G -d cassandra:latest

Bước 2: Kiểm tra trạng thái liên kết
Mở Terminal và kiểm tra xem hai node đã nhận diện nhau chưa:

PowerShell
docker exec -it cassandra-bachkhoa nodetool status
Kết quả chuẩn: Phải hiển thị 2 dòng có trạng thái UN (Up/Normal) với 2 địa chỉ IP nội bộ khác nhau.

Bước 3: Thiết lập chiến thuật sao lưu (Replication)
Vào DataGrip, tạo Keyspace và bảng dữ liệu với chiến thuật nhân bản toàn phần:

SQL
-- Tạo Keyspace với Replication Factor = 2 (Dữ liệu luôn có 2 bản sao trên 2 node)
CREATE KEYSPACE IF NOT EXISTS mentoria
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 2};

USE mentoria;

-- Tạo bảng dữ liệu mẫu
CREATE TABLE IF NOT EXISTS test_recovery (id int PRIMARY KEY, val text);
INSERT INTO test_recovery (id, val) VALUES (1, 'Data nhân bản trên Cluster');
Bước 4: Giả lập thảm họa và Khôi phục (Failover Test)
Hành động: Stop container cassandra-bachkhoa (giả lập node chính bị sập).

Kiểm chứng: Thực hiện lệnh truy vấn trong DataGrip:

SQL
SELECT \* FROM mentoria.test_recovery;
Kết quả: Dữ liệu vẫn được trả về bình thường từ Node 2. Hệ thống không bị gián đoạn (Zero Downtime).
[!WARNING]: Lưu ý đổi tên database theo tên đặt trên máy, đổi địa chỉ theo địa chỉ cá nhân
