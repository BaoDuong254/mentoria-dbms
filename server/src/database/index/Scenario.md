# Kịch bản so sánh SQL Server và Cassandra

---
## Kịch bản 1: Truy xuất bằng (=) với khóa chính
- Mục tiêu: Đánh giá tốc độ khi truy xuất 1 dòng duy nhất dựa trên khóa chính
### SQL Server
```text
SELECT * INTO #T1 FROM BankTransactions WHERE TransactionID = 1048548;
```

### Cassandra
```text
SELECT COUNT(*) FROM bank_transactions WHERE transaction_id = 'T1048548';
```

## Kịch bản 2: Truy xuất trên cột chưa đánh index
- Mục tiêu: Quan sát hành vi của DBMS khi người dùng cố tình tìm kiếm trên một cột không được tối ưu (CustomerID)
### SQL Server
```text
SELECT * INTO #T2 FROM BankTransactions WHERE CustomerID = 'C5674116';
```

### Cassandra
```text
SELECT COUNT(*) FROM bank_transactions WHERE customer_id = 'C5674116' ALLOW FILTERING;
```

## Kịch bản 3: Đánh chỉ mục phụ trên cột thường
- Mục tiêu: Cải thiện tốc độ truy vấn cho kịch bản 2 bằng cách đánh chỉ mục
### SQL Server
```text
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_customer')
CREATE NONCLUSTERED INDEX idx_customer ON BankTransactions(CustomerID);

SELECT * INTO #T3 FROM BankTransactions WHERE CustomerID = 'C5674116';
```

### Cassandra
```text
CREATE INDEX IF NOT EXISTS idx_customer_cas ON bank_transactions(customer_id);
SELECT COUNT(*) FROM bank_transactions WHERE customer_id = 'C5674116';
```

## Kịch bản 4: Truy vấn theo khoảng giá trị
- Mục tiêu: Lấy các giao dịch có số tiền lớn hơn 50.000
### SQL Server
```text
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_amount')
CREATE NONCLUSTERED INDEX idx_amount ON BankTransactions(TransactionAmount);

SELECT * INTO #T4 FROM BankTransactions WHERE TransactionAmount > 50000;
```

### Cassandra
```text
CREATE CUSTOM INDEX IF NOT EXISTS idx_amount_sai ON bank_transactions(transaction_amount) USING 'sai';
SELECT COUNT(*) FROM bank_transactions WHERE transaction_amount > 50000;
```

## Kịch bản 5: Truy vấn có Group by
- Mục tiêu: Khả năng báo cáo thống kê
### SQL Server
```text
SELECT CustLocation, COUNT(*) as Count, SUM(TransactionAmount) as Total
INTO #T5
FROM BankTransactions GROUP BY CustLocation;
```

### Cassandra
```text
DROP MATERIALIZED VIEW IF EXISTS transactions_by_location;

CREATE MATERIALIZED VIEW transactions_by_location AS
SELECT cust_location, transaction_id, transaction_amount
FROM bank_transactions
WHERE cust_location IS NOT NULL
  AND transaction_id IS NOT NULL
PRIMARY KEY (cust_location, transaction_id);

SELECT cust_location, SUM(transaction_amount)
FROM transactions_by_location
GROUP BY cust_location LIMIT 10;
```

## Kịch bản 6: Truy vấn có Group by với CulumnStore Index trong SQL Server
- Mục tiêu: Minh chứng tốc độ truy vấn khi dùng ColumnStore Index
### SQL Server
```text
-- tạo bảng mới
IF OBJECT_ID('BankTransactions_Columnar', 'U') IS NOT NULL
    DROP TABLE BankTransactions_Columnar;

SELECT * INTO BankTransactions_Columnar FROM BankTransactions;

-- đánh chỉ mục column store
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Bank_Transactions
    ON BankTransactions_Columnar;
GO

-- xóa cache
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

-- querry với group by
SET STATISTICS TIME ON;
SELECT CustLocation, COUNT(*) as Count, SUM(TransactionAmount) as Total
INTO #T6
FROM BankTransactions_Columnar GROUP BY CustLocation;
SET STATISTICS TIME OFF;
GO
```
