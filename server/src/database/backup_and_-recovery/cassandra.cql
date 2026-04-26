-- =============================================
-- PHẦN 1: THIẾT LẬP CLUSTER (ÍT NHẤT 2 NODES)
-- =============================================

-- Chạy Node chính (Seed Node)
docker run --name cassandra-bachkhoa -p 9042:9042 -e CASSANDRA_HEAP_SIZE=512M -e CASSANDRA_MAX_HEAP_SIZE=1G -d cassandra:latest

-- Chạy Node phụ (Backup Node) - Chờ Node chính xanh rồi mới chạy lệnh này
docker run --name cassandra-node-2 --link cassandra-bachkhoa:cassandra -e CASSANDRA_HEAP_SIZE=512M -e CASSANDRA_MAX_HEAP_SIZE=1G -d cassandra:latest

-- Kiểm tra trạng thái Cluster (Phải hiện 2 dòng UN mới đạt)
docker exec -it cassandra-bachkhoa nodetool status

-- =============================================
-- PHẦN 2: SAO LƯU (BACKUP/REPLICATION)
-- =============================================

-- Bước 1: Thiết lập Keyspace nhân bản trên cả 2 node (Thao tác trong DataGrip)
CREATE KEYSPACE IF NOT EXISTS mentoria 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 2};

-- Bước 2: Tạo Snapshot thủ công cho Keyspace (Thao tác trong Terminal)
docker exec -it cassandra-bachkhoa nodetool snapshot -t manual_backup mentoria

-- =============================================
-- PHẦN 3: KHÔI PHỤC (RECOVERY/FAILOVER)
-- =============================================

-- Kịch bản 1: Phục hồi khi sập Node (Tự động)
-- Hành động: Stop container cassandra-bachkhoa. Dữ liệu vẫn được truy xuất từ Node 2.
SELECT * FROM mentoria.[tên_bảng];

-- Kịch bản 2: Phục hồi từ Snapshot (Thủ công)
-- Sau khi đã copy file từ thư mục snapshot vào thư mục data, chạy lệnh refresh:
docker exec -it cassandra-bachkhoa nodetool refresh mentoria [tên_bảng];