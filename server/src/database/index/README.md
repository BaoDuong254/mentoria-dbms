# Hướng Dẫn Setup Hệ Thống CSDL SQL Server & Cassandra và chạy các các kịch bản.

Tài liệu này tổng hợp toàn bộ quy trình thiết lập Docker, cấu hình mount dữ liệu từ ổ đĩa máy Host và script import hơn 1 triệu dòng dữ liệu giao dịch ngân hàng vào hai DBMS cùng với chạy và so sánh các kịch bản kiểm thử.

---

## 1. Cấu Trúc Project

- Cấu trúc hệ thống test

```bash
DBScript/
|__ bank_transactions.csv           # chứa dữ liệu thô
|__ bank_transactions_clean.csv     # chứa dữ liệu đã được làm sạch
|__ clean_data.py                   # script python làm sạch dữ liệu
|__ docker-compose.yml              # cấu hình hai dbms trên docker
|__ insert_cassandra.cql            # tạo bảng Cassandra và nạp dữ liệu
|__ insert_sqlserver.sql            # tạo bảng SQL Server và nạp dữ liệu
|__ load_data.bat                   # nạp dữ liệu vào 2 dbms cùng lúc (1 click)
|__ README.md                       # file mô tả (ur reading)
|__ Scenario.md                     # file mô tả các kịch bản test
|__ test_indexing_cassandra.cql     # script hiện thực các kịch bản trong cassansdra
|__ test_indexing_ sqlserver.sql    # script hiện thực các kịch bản trong sql server
|__ Run.bat                         # script chạy các kịch bản test
|__ txt files                       # các file kết quả sau khi chaỵ
```

## 2. Cấu Hình Docker (docker-compose.yml)

```yaml
services:
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: sql-server-db
    ports:
      - "14330:1433"
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=SuperStrong@Password2026
    volumes:
      # Đưa ra một thư mục riêng biệt ở gốc: /dataset
      # Chỉnh lại theo đúng thư mục chứa folder này
      - "E:/University/Thirdyear/Second_semester/DBMS/Dataset:/dataset"

  cassandra:
    image: cassandra:latest
    container_name: cassandra-db
    ports:
      - "9042:9042"
    volumes:
      # Dùng chung đường dẫn /dataset cho đồng bộ và dễ nhớ
      - "E:/University/Thirdyear/Second_semester/DBMS/Dataset:/dataset"
```

## 3. Quy trình kết nối database

- Mở terminal tại thư mục này và chạy `docker compose up -d`
- Mở Docker Desktop và kiểm tra caá container có chạy chưa
- Đối với SQL Server:

```text
1. Mở DataGrip chọn Data source => Chọn Microsoft SQL Server
2. Kết nối tới localhost cổng 14430
3. Tải driver Microsoft SQL Server về (nếu chưa có)
4. Bật tùy chọn Trust Server Certificate thành true trong Advanced/General
5. Ở input User nhập `sa`, input Password nhập `SuperStrong@Password2026`
6. Chọn Test connection, nếu trả về status OK thì click Apply và click OK
```

- Đối với Cassandra, cũng làm tương tự như cách setup SQL Server:

```text
1. Mở DataGrip kết nối tới localhost cổng mặc định
2. Chọn test connection rồi Ok nếu thành công
```

## 4. Quy trình chạy sau khi đã setup

1. Chạy load_data.bat với quyền admin
2. Chạy run.bat với quyền admin
3. Mở 2 file Result_Cassandra.txt và Result_SQLServer.txt ra và xem kết quả
