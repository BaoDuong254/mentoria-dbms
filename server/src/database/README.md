# Cơ sở dữ liệu — Hướng dẫn cài đặt

Tài liệu này hướng dẫn cách thiết lập hai hệ quản trị cơ sở dữ liệu được dùng trong bài tập lớn: **Microsoft SQL Server 2022** và **Apache Cassandra**. Hai hệ thống này được cài đặt song song để so sánh cơ chế xử lý truy vấn, tối ưu hoá và lưu trữ.

---

## Tổng quan các file

```text
server/src/database/
├── docker-compose.yml          ← Khởi động cả hai DBMS bằng Docker
│
├── SQL.sql                     ← Schema SQL Server (26 bảng)
├── trigger.sql                 ← Trigger SQL Server
├── procedure.sql               ← Stored procedures
├── function.sql                ← User-defined functions
├── INSERT_DATA.sql             ← Dữ liệu mẫu SQL Server
├── create_indexes.sql          ← Nonclustered Index
│
├── cassandra_schema.cql        ← Schema Cassandra (keyspace + tables)
├── cassandra_insert_data.cql   ← Dữ liệu mẫu Cassandra
│
├── query/                      ← Kịch bản kiểm thử so sánh hai DBMS
├── index/                      ← Tài liệu về index
├── dataStorage_and_Management/ ← Tài liệu về lưu trữ và quản lý dữ liệu
└── backup_and_recovery/        ← Tài liệu về backup và phục hồi
```

---

## Khuyến nghị môi trường chạy

> **Khi đo thời gian thực thi (performance benchmarking), hãy chạy cả hai DBMS qua Docker.**

Lý do: chạy bằng Docker đảm bảo cả hai hệ thống hoạt động trong môi trường tài nguyên tương đương (cùng máy chủ, cùng mức cấp phát CPU/RAM của container runtime). Nếu SQL Server được cài đặt native trên máy còn Cassandra chạy Docker (hoặc ngược lại), kết quả đo lường sẽ bị lệch do sự khác biệt về overhead hệ điều hành và tài nguyên phần cứng.

| Mục đích                               | SQL Server        | Cassandra         |
| -------------------------------------- | ----------------- | ----------------- |
| **Đo hiệu năng (khuyến khích)**        | Docker            | Docker            |
| **Phát triển / kiểm thử thông thường** | SSMS (cài native) | Docker + DataGrip |

---

## Cách 1 — Chạy cả hai bằng Docker (khuyến khích để benchmark)

File `docker-compose.yml` trong thư mục này khởi động đồng thời SQL Server và Cassandra.

```bash
# Chạy từ thư mục server/src/database/
docker compose up -d
```

Sau khi khởi động, hai service sẵn sàng tại:

| Service    | Host        | Port    | Thông tin đăng nhập                               |
| ---------- | ----------- | ------- | ------------------------------------------------- |
| SQL Server | `localhost` | `14330` | User: `sa` / Password: `SuperStrong@Password2026` |
| Cassandra  | `localhost` | `9042`  | Không yêu cầu xác thực (mặc định)                 |

> Dừng và xoá container: `docker compose down`
> Xoá luôn volume (mất toàn bộ dữ liệu): `docker compose down -v`

---

## Cách 2 — SQL Server qua SSMS, Cassandra qua Docker

Phù hợp khi bạn đã có SQL Server cài sẵn trên máy và chỉ cần chạy Cassandra riêng lẻ.

**Khởi động chỉ Cassandra:**

```bash
docker run -d --name cassandra-db -p 9042:9042 cassandra:latest
```

Kết nối SQL Server bằng SSMS như bình thường. Kết nối Cassandra từ DataGrip theo hướng dẫn ở mục [Kết nối DataGrip vào Cassandra](#kết-nối-datagrip-vào-cassandra).

---

## Khởi tạo SQL Server

Chạy các file sau theo đúng thứ tự trong SSMS hoặc `sqlcmd`. Nếu dùng Docker, kết nối tới `localhost,14330` với tài khoản `sa`.

```text
1. SQL.sql          ← Tạo schema (26 bảng)
2. trigger.sql      ← Tạo trigger
3. procedure.sql    ← Tạo stored procedures
4. function.sql     ← Tạo functions
5. INSERT_DATA.sql  ← Nạp dữ liệu mẫu
6. create_indexes.sql ← Tạo nonclustered index
```

**Dùng SSMS:** mở từng file, chọn đúng database, nhấn **F5**.

**Dùng `sqlcmd`:**

```powershell
$server = "localhost,14330"
$user   = "sa"
$pass   = "SuperStrong@Password2026"
$db     = "mentoria"

sqlcmd -S $server -U $user -P $pass -i SQL.sql
sqlcmd -S $server -U $user -P $pass -d $db -i trigger.sql
sqlcmd -S $server -U $user -P $pass -d $db -i procedure.sql
sqlcmd -S $server -U $user -P $pass -d $db -i function.sql
sqlcmd -S $server -U $user -P $pass -d $db -i INSERT_DATA.sql
sqlcmd -S $server -U $user -P $pass -d $db -i create_indexes.sql
```

---

## Khởi tạo Cassandra

**Bước 1 — Vào `cqlsh` bên trong container:**

```bash
docker exec -it cassandra-db cqlsh
```

> Cassandra mất khoảng 30–60 giây để khởi động hoàn toàn. Nếu lệnh trên báo lỗi kết nối, đợi thêm rồi thử lại.

**Bước 2 — Chạy file schema** (tạo keyspace `mentoriadbms` và tất cả các bảng):

```bash
docker exec -i cassandra-db cqlsh < cassandra_schema.cql
```

**Bước 3 — Nạp dữ liệu mẫu:**

```bash
docker exec -i cassandra-db cqlsh < cassandra_insert_data.cql
```

Hoặc nếu muốn chạy tay từng câu lệnh, vào `cqlsh` rồi dùng `SOURCE`:

```cql
SOURCE '/path/to/cassandra_schema.cql';
SOURCE '/path/to/cassandra_insert_data.cql';
```

**Kiểm tra keyspace đã tạo thành công:**

```cql
DESCRIBE KEYSPACES;
USE mentoriadbms;
DESCRIBE TABLES;
```

---

## Kết nối DataGrip vào Cassandra

DataGrip hỗ trợ Cassandra thông qua driver Cassandra (CQL). Cấu hình như sau:

1. **New Data Source** → chọn **Apache Cassandra**
2. **Host:** `localhost` | **Port:** `9042`
3. **Keyspace:** `mentoriadbms` (để trống nếu muốn xem tất cả keyspace)
4. Không cần username/password (Cassandra mặc định không bật xác thực)
5. Nhấn **Test Connection** → **OK**

> Lưu ý: DataGrip kết nối qua driver JDBC/CQL từ máy host, không cần vào trong container. Tuy nhiên, khi chạy kịch bản kiểm thử có dùng `TRACING`, cần vào `cqlsh` trong container (xem [`query/README.md`](query/README.md)) vì DataGrip không hiển thị trace output đầy đủ.

---

## Liên kết tài liệu liên quan

- [`query/README.md`](query/README.md) — Hướng dẫn chạy các kịch bản kiểm thử so sánh hai DBMS
- [`index/README.md`](index/README.md) — Tài liệu về chiến lược index
- [`dataStorage_and_Management/README.md`](dataStorage_and_Management/README.md) — Lưu trữ và quản lý dữ liệu
- [`backup_and_recovery/`](backup_and_recovery/) — Backup và phục hồi
