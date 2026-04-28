-- =============================================
-- PHẦN 1: SAO LƯU (BACKUP)
-- =============================================
USE [mentoria];
GO
BACKUP DATABASE [mentoria] 
TO DISK = N'D:\mentoria-dbms-main\mentoria.bak' //thay đổi đường dẫn và tên file sao lưu theo ý muốn
WITH FORMAT, INIT, NAME = 'Full Backup of mentoria';
GO

-- =============================================
-- PHẦN 2: KHÔI PHỤC (RESTORE)
-- =============================================
USE master;
GO
-- Ngắt các kết nối có thể dùng để restore
ALTER DATABASE [mentoria] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
-- Thực hiện khôi phục từ file sao lưu
RESTORE DATABASE [mentoria] 
FROM DISK = N'D:\mentoria-dbms-main\mentoria.bak' 
WITH REPLACE;
GO
-- Mở lại quyền truy cập bình thường
ALTER DATABASE [mentoria] SET MULTI_USER;
GO