# Kiểm thử và so sánh 2 hệ quản trị dữ liệu MS SQL Server và Apache Cassandra
## 1. Kiểm thử để so sánh ánh xạ kiểu dữ liệu và phương pháp truy xuất của 2 hệ quản trị
-- Chạy lệnh sau trong SQL truy vấn user_id từ bảng users theo email 'john.doe@example.com', kiểm thử sự tồn tại dữ liệu trong bảng mentor để xác định vai trò của user này rồi truy xuất dữ liệu
<!-- 
    USE mentoria;
    SELECT u.user_id, u.first_name, u.last_name, u.email
    FROM users u
    INNER JOIN mentors m ON u.user_id = m.user_id
    WHERE u.email = 'john.doe@example.com';
-->
-- Chạy lệnh sau ở Cassandra để lấy các giá trị yêu cầu thỏa điều kiện email là 'john.doe@example.com' từ bảng users_by_email
    <!-- 
    USE mentoriadbms;
    SELECT user_id, first_name, last_name, role, status
    FROM users_by_email
    WHERE email = 'john.doe@example.com'; 
    -->
## 2. Kiểm thử để so sánh tập dữ liệu đầu ra giữa bảng mentor_profiles (Cassandra) và thủ tục lưu trữ dbo.sp_SearchMentors (MS SQL Server)
-- Truy cập dbo.sp_SearchMentors của SSMS để xuất ra 10 dòng đầu
    <!-- 
    USE mentoria;
    EXEC dbo.sp_SearchMentors @Page = 1, @Limit = 10; 
    -->
-- Truy cập mentor_profiles của Cassandra để xuất ra 10 dòng đầu
    <!-- 
    USE mentoriadbms;
    SELECT * FROM mentor_profiles LIMIT 10; 
    -->
-- Kết quả kiểm thử là 2 bảng có dữ liệu tương đồng
## 3. Kiểm thử để truy xuất dữ liệu của 1 đối tượng từ 1 thuộc tính của đối tượng trong 2 hệ quản trị dữ liệu
-- Thực hiện phép JOIN truy xuất dữ liệu từ nhiều bảng khác nhau để hợp nhất các thuộc tính của user có ID là 1 trong SQL
    <!-- 
    USE mentoria;
    DECLARE @MentorId INT = 1;
    SELECT
        'MENTOR_INFO' AS type,
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.avatar_url,
        u.country,
        u.timezone,
        u.status,
        m.bio,
        m.headline,
        m.response_time,
        m.cv_url,
        m.bank_name,
        m.account_number
    FROM users u
    JOIN mentors m ON m.user_id = u.user_id
    WHERE u.user_id = @MentorId 
    -->
--Truy cập trực tiếp vào bảng mentor_profiles trong Cassandra để tìm mentor có mentor_id tương ứng
    <!-- 
    USE mentoriadbms;
    SELECT * FROM mentor_profiles
    WHERE mentor_id = a1000000-0000-0000-0000-000000000001; 
    -->
## 4. Kiểm thử để tìm và lọc dữ liệu trong 2 hệ quản trị
--Truy cập vào thủ tục dbo.sp_SearchMentors để lọc dữ liệu theo các tham số @SkillName = 'Docker'và @MinRating = 4.0
    <!-- 
    EXEC dbo.sp_SearchMentors
        @SkillName = 'Docker',
        @MinRating = 4.0; 
    -->
--Truy cập trực tiếp vào bảng mentors_by_skill trong Cassandra để lọc dữ liệu theo điều kiện skill_name = 'Docker' và rating >= 4.0
    <!-- 
    SELECT * FROM mentors_by_skill
    WHERE skill_name = 'Docker'
        AND rating >= 4.0 
    -->