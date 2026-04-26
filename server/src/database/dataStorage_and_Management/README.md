## 1. Các kịch bản kiểm thử (Test Cases)

### Kịch bản 1: Lấy một số thông tin cơ bản về người dùng qua email

**Mục tiêu:** So sánh ánh xạ kiểu dữ liệu và phương pháp truy xuất.

**MS SQL Server**  
_Phương pháp:_ Sử dụng phép `JOIN` tại thời điểm truy vấn, truy xuất dữ liệu trên hai bảng thông qua khóa ngoại.

```sql
USE mentoria;
SELECT u.user_id, u.first_name, u.last_name, u.email
FROM users u
INNER JOIN mentors m ON u.user_id = m.user_id
WHERE u.email = 'john.doe@example.com';
```

**Apache Cassandra**  
_Phương pháp:_ Truy xuất trực tiếp dữ liệu từ bảng đã được thiết kế chuyên biệt nhờ khóa phân vùng email.

```sql
USE mentoriadbms;
SELECT user_id, first_name, last_name, role, status
FROM users_by_email
WHERE email = 'john.doe@example.com';
```

**Kết quả kiểm thử:**

- Cả hai hệ thống trả về cùng một đối tượng mentor, tuy nhiên `user_id` được biểu diễn khác nhau: MS SQL Server dùng kiểu `INT` (số nguyên), Apache Cassandra dùng kiểu `UUID`
- Thời gian thực thi gần như tương đương, SQL nhanh hơn vài ms do đây là phép `JOIN` cơ bản trên 2 bảng.

---

### Kịch bản 2: Lấy danh sách 10 mentor đầu tiên

**Mục tiêu:** So sánh tập dữ liệu đầu ra với phương pháp phân trang qua stored procedure của MS SQL Server và phương pháp giới hạn số bản ghi bằng `LIMIT` trong Apache Cassandra .

**MS SQL Server**  
_Phương pháp:_ Thực hiện phân trang cho stored procedure.

```sql
USE mentoria;
EXEC dbo.sp_SearchMentors @Page = 1, @Limit = 10;
```

**Apache Cassandra**  
_Phương pháp:_ Sử dụng `LIMIT` cho bảng đã phi chuẩn hóa.

```sql
USE mentoriadbms;
SELECT * FROM mentor_profiles LIMIT 10;
```

**Kết quả kiểm thử:**

- Hai bảng đều trả về tập kết quả chứa 10 mentor đầu tiên tương đồng.
- Cassandra có tốc độ phản hồi nhanh hơn khoảng 1 giây do dữ liệu đã được sắp xếp sẵn bên trong cấu trúc của nó.

---

### Kịch bản 3: Truy xuất hồ sơ chi tiết của mentor theo ID

**Mục tiêu:** Lấy toàn bộ thông tin chi tiết của mentor qua `user_id`.

**MS SQL Server**  
_Phương pháp:_ Thực hiện phép `JOIN` các bảng thành phần lại với nhau để hợp nhất các dữ liệu về mentor.

```sql
USE mentoria;
DECLARE @MentorId INT = 1;
SELECT
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
WHERE u.user_id = @MentorId;
```

**Apache Cassandra**  
_Phương pháp:_ Truy cập trực tiếp vào bảng gộp chứa toàn bộ dữ liệu về mentor.

```sql
USE mentoriadbms;
SELECT * FROM mentor_profiles
WHERE mentor_id = a1000000-0000-0000-0000-000000000001;
```

**Kết quả kiểm thử:**

- MS SQL Server trả về dữ liệu tổng hợp dựa trên phép `JOIN` trích xuất thuộc tính từ 2 bảng `users` và `mentors`.
- Apache Cassandra trả về toàn bộ dữ liệu chỉ thông qua một câu lệnh `SELECT` duy nhất trên bảng `mentor_profiles`, nhanh hơn phép JOIN của SQL vài ms.

---

### Kịch bản 4: Tìm kiếm và lọc mentor theo điều kiện

**Mục tiêu:** Truy xuất danh sách các mentor có kỹ năng `Docker` và điểm rating từ `4.0` trở lên.

**MS SQL Server**  
_Phương pháp:_ Truyền tham số vào stored procedure để lọc dữ liệu theo điều kiện.

```sql
USE mentoria;
EXEC dbo . sp_SearchMentors
    @SkillName = 'Docker',
    @MinRating = 4.0;
```

**Apache Cassandra**  
_Phương pháp:_ Truy xuất trực tiếp trên bảng được thiết kế riêng cho mục đích tìm kiếm theo kỹ năng kết hợp với thứ tự rating.

```sql
USE mentoriadbms;
SELECT * FROM mentors_by_skill
WHERE skill_name = 'Docker'
AND rating >= 4.0
```

**Kết quả kiểm thử:**

- Cả hai hệ thống đều lọc ra được danh sách mentor có kỹ năng `Docker` và rating >= `4.0`.
- MS SQL Server dùng stored procedure mang lại sự linh hoạt cao, dễ dàng tìm kiếm tổng hợp trên nhiều bảng quan hệ.
- Apache Cassandra tận dụng khóa phân vùng `skill_name` để định vị partition, sau đó lọc tiếp theo clustering key `rating`, nhanh hơn đáng kể so với SQL Server phải duyệt qua nhiều bảng quan hệ.
- Cassandra có tốc độ phản hồi nhanh hơn SQL khoảng 2 giây, kiểm thử này thể hiện ưu thế của Cassandra trong tác vụ đọc khi thiết kế bảng tối ưu theo truy vấn.

---

## Tổng kết đánh giá

### Bảng so sánh kết quả kiểm thử

| Kịch bản                            | MS SQL Server                                                       | Apache Cassandra                                  | Xử lí nhanh hơn     |
| ----------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------- | ------------------- |
| 1. Truy xuất người dùng qua email   | `JOIN` 2 bảng tại thời điểm truy vấn                                | Truy xuất trực tiếp qua khóa phân vùng            | SQL Server (vài ms) |
| 2. Lấy danh sách 10 mentor đầu tiên | Phân trang qua stored procedure                                     | Giới hạn bản ghi bằng `LIMIT`                     | Cassandra (~1s)     |
| 3. Truy xuất hồ sơ chi tiết theo ID | `JOIN` 2 bảng tại thời điểm truy vấn, trích xuất nhiều cột chi tiết | Truy xuất trực tiếp qua khóa phân vùng            | Cassandra (vài ms)  |
| 4. Tìm kiếm và lọc theo điều kiện   | Lọc linh hoạt nhiều tham số qua stored procedure                    | Lọc trực tiếp qua khóa phân vùng và khóa phân cụm | Cassandra (~2s)     |

---

### Nhận xét tổng quan

**MS SQL Server** phù hợp với các tác vụ cần tính linh hoạt cao trong truy vấn. Nhờ vào việc hệ thống có hỗ trợ `JOIN` và stored procedure, có khả năng tổng hợp dữ liệu từ nhiều bảng quan hệ mà không cần thiết kế lại cấu trúc. Tuy nhiên, hiệu năng phụ thuộc vào độ phức tạp của truy vấn và kích thước dữ liệu.

**Apache Cassandra** cho thấy ưu thế rõ rệt về tốc độ đọc nhờ chiến lược phi chuẩn hóa, dữ liệu được gộp sẵn và sắp xếp theo mục đích truy vấn ngay tại thời điểm ghi, đem lại tốc độ truy vấn nhanh, ổn định, các tác vụ hầu hết đều có thể thực hiện chỉ với một câu lệnh `SELECT` duy nhất. Đổi lại, mỗi trường hợp truy vấn cần một bảng được thiết kế riêng, làm tăng độ phức tạp trong quản lý cấu trúc dữ liệu.

---

### Kết luận

Hai hệ thống không có hệ thống nào vượt trội hoàn toàn — mỗi hệ thống phù hợp với một bài toán khác nhau:

- Chọn **MS SQL Server** khi cần truy vấn linh hoạt, dữ liệu có quan hệ chặt chẽ, hoặc logic nghiệp vụ phức tạp.
- Chọn **Apache Cassandra** khi cần tốc độ đọc cao, dữ liệu lớn, hoặc mô hình truy vấn cố định và có thể dự đoán trước.
- Trong thực tế, hai hệ thống có thể được kết hợp song song — SQL Server đảm nhận các nghiệp vụ phức tạp, Cassandra phụ trách các tác vụ đọc hiệu năng cao.
