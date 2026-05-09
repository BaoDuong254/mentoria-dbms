## 1. Các kịch bản kiểm thử (Test Cases)

### Kịch bản 1: Lấy danh sách 10 mentor đầu tiên

**Mục tiêu:** So sánh cơ chế sắp xếp giữa MS SQL Server và Apache Cassandra.

**MS SQL Server**  
_Phương pháp:_ Thực hiện phân trang cho stored procedure.

```sql
USE mentoria;
EXEC dbo.sp_SearchMentors @Page = 1, @Limit = 10;
```

**Apache Cassandra**  
_Phương pháp:_ Sử dụng `LIMIT` cho bảng đã phi chuẩn hóa.

```cql
USE mentoriadbms;
SELECT * FROM mentor_profiles LIMIT 10;
```

**Kết quả kiểm thử:**

- Cả hai hệ thống đều trả về 10 mentor, tuy nhiên thứ tự kết quả khác nhau:
  MS SQL Server sắp xếp theo `user_id` tăng dần do cấu hình trong stored procedure, trong khi Cassandra trả về theo thứ tự token nội bộ của khóa phân vùng.

---

### Kịch bản 2: So sánh hiệu suất INSERT 500.000 dòng với bảng companies

**MS SQL Server**  
_Phương pháp:_ Tạo dữ liệu giả lập trực tiếp bằng SQL Script

```sql
USE mentoria;
INSERT INTO companies (cname)
SELECT TOP 500000
    'Company_New_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR)
FROM sys.all_objects a
CROSS JOIN sys.all_objects b;
```

**Apache Cassandra**  
_Phương pháp:_ Tạo dữ liệu giả lập và đo tốc độ trực tiếp bằng công cụ benchmark `cassandra-stress` với file mô tả yaml

```yaml
keyspace: mentoriadbms

table: companies

table_definition: CREATE TABLE companies (
  company_id   uuid PRIMARY KEY,
  cname        text
  );

columnspec:
  - name: company_id
    size: fixed(16)
    population: seq(31..500030)
  - name: cname
    size: uniform(13..18)
    population: seq(31..500030)

insert:
  partitions: fixed(500)
  batchtype: UNLOGGED

queries:
  read1:
    cql: select * from users where companies = ? and company_id = ?
    fields: samerow
```

```bash
docker run --rm -v "${PWD}:/data" --network host cassandra:latest /opt/cassandra/tools/bin/cassandra-stress user profile=/data/cassandra_stress.yaml n=1000 "ops(insert=1)" no-warmup cl=ONE -rate threads=1000
```

**Kết quả kiểm thử:**

- Cassandra chạy nhanh hơn SQL rất nhiều do chạy nhiều luồng với kích thước batch lớn. Tuy nhiên việc chạy nhiều luồng để nạp batch với kích thước lớn thường không được khuyến khích, tuy tốc độ nhanh hơn nhưng hiệu suất không ổn định, đặc biệt là khi áp dụng cho hệ thống lớn.

### Kịch bản 3: So sánh cơ chế quản lý không gian đĩa vật lý

**MS SQL Server**  
_Phương pháp:_ Truy vấn System Views (`sys.database_files`) để xem trực tiếp cấu trúc và dung lượng file vật lý của Database.

```sql
USE mentoria;
GO
SELECT
    name AS [Tên_Logic],
    type_desc AS [Loại_File],
    physical_name AS [Đường_dẫn_File_Vật_lý],
    (size * 8.0 / 1024) AS [Dung_lượng_MB]
FROM sys.database_files;
```

**Apache Cassandra**  
_Phương pháp:_ Thống kê dung lượng lưu trữ tổng thể của toàn bộ Node bằng công cụ `nodetool`

```bash
docker exec -it mentoria-cassandra nodetool info
```

**Kết quả kiểm thử:**

- **MS SQL Server:** Quản lý dữ liệu tập trung qua 2 file vật lý (`.mdf` và `.ldf`). Số lượng file trên hệ điều hành rất ít, thuận tiện quản lý tập trung nhưng có thể gặp hiện tượng tắc nghẽn I/O Bottleneck khi file phình quá to hoặc ghi dữ liệu liên tục. Ngoài ra hệ thống còn tốn thêm không gian và chi phí lưu trữ file log (`.ldf`)
- **Apache Cassandra:** Lưu trữ dữ liệu theo cấu trúc LSM-Tree, liên tục sinh ra nhiều file nhỏ bất biến (SSTables) để tối ưu tốc độ ghi. Mặc dù tốc độ ghi nhanh hơn đáng kể, nhưng làm tăng số lượng file vật lý trên đĩa, tốn nhiều dung lượng tổng thể hơn và cần các tiến trình gộp file (Compaction) chạy ngầm. Tuy nhiên, do yêu cầu tối thiểu 3 node để đảm bảo tính sẵn sàng, hệ thống tốn nhiều chi phí phần cứng hơn.

---

## Tổng kết đánh giá

### Nhận xét tổng quan

**MS SQL Server** phù hợp với các tác vụ cần tính linh hoạt cao trong truy vấn. Nhờ vào việc hệ thống có hỗ trợ `JOIN` và stored procedure, có khả năng tổng hợp dữ liệu từ nhiều bảng quan hệ mà không cần thiết kế lại cấu trúc. Tuy nhiên, hiệu năng phụ thuộc vào độ phức tạp của truy vấn và kích thước dữ liệu.

**Apache Cassandra** cho thấy ưu thế rõ rệt về tốc độ đọc nhờ chiến lược phi chuẩn hóa, dữ liệu được gộp sẵn và sắp xếp theo mục đích truy vấn ngay tại thời điểm ghi, đem lại tốc độ truy vấn nhanh, ổn định, các tác vụ hầu hết đều có thể thực hiện chỉ với một câu lệnh `SELECT` duy nhất. Đổi lại, mỗi trường hợp truy vấn cần một bảng được thiết kế riêng, làm tăng độ phức tạp trong quản lý cấu trúc dữ liệu.

---

### Kết luận

Hai hệ thống không có hệ thống nào vượt trội hoàn toàn — mỗi hệ thống phù hợp với một bài toán khác nhau:

- Chọn **MS SQL Server** khi cần truy vấn linh hoạt, dữ liệu có quan hệ chặt chẽ, hoặc logic nghiệp vụ phức tạp.
- Chọn **Apache Cassandra** khi cần tốc độ đọc cao, dữ liệu lớn, hoặc mô hình truy vấn cố định và có thể dự đoán trước.
- Trong thực tế, hai hệ thống có thể được kết hợp song song — SQL Server đảm nhận các nghiệp vụ phức tạp, Cassandra phụ trách các tác vụ đọc hiệu năng cao.
