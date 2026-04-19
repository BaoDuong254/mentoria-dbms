-- Bước 1: Kiểm tra trạng thái các Node trong cụm
-- nodetool status

-- Bước 2: Tạo Snapshot để lưu trạng thái hiện tại
-- (Chạy lệnh này ở Terminal)
-- nodetool snapshot -t pre_demo_backup mentoriadbms

-- Bước 3: Kiểm tra dữ liệu trước khi xóa
SELECT count(*) FROM mentoriadbms.users_by_id;

-- Bước 4: Giả lập lỗi (Dừng 1 Node trong cụm 3 Node)
-- (Chạy lệnh này ở Terminal/Docker)
-- docker stop cassandra-node-3

-- Bước 5: Truy vấn lại dữ liệu (Vẫn phải ra kết quả cũ)
-- Chứng minh tính Fault Tolerance: 1 Node sập hệ thống vẫn chạy
SELECT count(*) FROM mentoriadbms.users_by_id;