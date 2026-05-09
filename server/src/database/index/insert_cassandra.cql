-- xóa toàn bộ database cũ
DROP KEYSPACE IF EXISTS bank_ks;

-- tạo database mới
CREATE KEYSPACE bank_ks
    WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE bank_ks;

-- tạo lại bảng
CREATE TABLE bank_transactions (
        transaction_id text PRIMARY KEY,
        customer_id text,
        customer_dob text,
        cust_gender text,
        cust_location text,
        cust_account_balance double,
        transaction_date text,
        transaction_time int,
        transaction_amount double
);

-- nạp dữ liệu từ file .csv
COPY bank_transactions (transaction_id, customer_id, customer_dob, cust_gender, cust_location, cust_account_balance, transaction_date, transaction_time, transaction_amount)
FROM '/dataset/bank_transactions_clean.csv'
WITH HEADER = TRUE      -- báo có header (bỏ dòng đầu tiên)
AND DELIMITER = ','     -- các cột cách nhau dấu phảy
AND CHUNKSIZE = 1000    -- kích thước mỗi chunk load
AND MAXBATCHSIZE = 100  -- chỉ ghi tối đa 100 dòng mỗi lần
AND NUMPROCESSES = 2    -- giảm số luồng xử lý song song
AND MAXATTEMPTS = 15;   -- số lần xử lý lại khi bị nghẽn
