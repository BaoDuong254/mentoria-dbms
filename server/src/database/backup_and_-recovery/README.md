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

Chạy lệnh xóa "ép buộc" (bất chấp khóa ngoại):

USE [mentoria];
GO

-- 1. Tắt tất cả kiểm tra ràng buộc
EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";

-- 2. Xóa dữ liệu theo thứ tự (Để không bị mâu thuẫn dữ liệu khi bật lại Check)
DELETE FROM dbo.meetings;
DELETE FROM dbo.messages;
DELETE FROM dbo.feedbacks;
DELETE FROM dbo.bookings;
DELETE FROM dbo.Mentors;
DELETE FROM dbo.Skills;
DELETE FROM dbo.Users;

-- 3. Bật lại kiểm tra ràng buộc (Lúc này data trống hết rồi nên nó sẽ KHÔNG báo lỗi)
EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";

-- 4. Kiểm tra xem còn gì không
SELECT 'Kết quả' AS Status, 'Dữ liệu đã được xóa sạch, sẵn sàng Restore' AS Message;
GO

Hoặc xóa luôn database hiện tại:

USE master;
GO
RESTORE DATABASE [mentoria]
FROM DISK = N'D:\mentoria-dbms-main\mentoria.bak' -- Nhớ đúng đường dẫn file ông đã backup nhé
WITH REPLACE;
GO

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
