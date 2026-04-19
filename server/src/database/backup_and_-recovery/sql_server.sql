-- Bước 1: Tạo bản sao lưu (Full Backup)
-- Nhớ tạo folder C:\backup trước khi chạy lệnh này
BACKUP DATABASE [mentoria] 
TO DISK = 'C:\backup\mentoria_full.bak' 
WITH FORMAT, NAME = 'Full Backup of Mentoria';

-- Bước 2: Giả lập sự cố (Xóa sạch bảng Mentors)
DELETE FROM Mentors;
-- SELECT * FROM Mentors; -- Chạy dòng này để thấy bảng trống trơn

-- Bước 3: Phục hồi dữ liệu từ bản sao lưu
USE master;
ALTER DATABASE [mentoria] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [mentoria] 
FROM DISK = 'C:\backup\mentoria_full.bak' 
WITH REPLACE;
ALTER DATABASE [mentoria] SET MULTI_USER;

-- Bước 4: Kiểm tra kết quả (Dữ liệu phải quay trở lại)
USE mentoria;
SELECT COUNT(*) AS Total_Mentors FROM Mentors;