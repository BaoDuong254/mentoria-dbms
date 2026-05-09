USE BankDB;
GO

-- tắt thông báo
SET NOCOUNT ON;
SET STATISTICS IO OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 1: POINT LOOKUP (CLUSTERED INDEX)';
PRINT '=======================================================';
-- dọn cache với buffer
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

SET STATISTICS TIME ON;
SELECT * INTO #T1 FROM BankTransactions WHERE TransactionID = 1048548;
SET STATISTICS TIME OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 2: FULL TABLE SCAN (NO INDEX)';
PRINT '=======================================================';
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

SET STATISTICS TIME ON;
SELECT * INTO #T2 FROM BankTransactions WHERE CustomerID = 'C5674116';
SET STATISTICS TIME OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 3: NONCLUSTERED INDEX (SECONDARY INDEX)';
PRINT '=======================================================';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_customer')
CREATE NONCLUSTERED INDEX idx_customer ON BankTransactions(CustomerID);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

SET STATISTICS TIME ON;
SELECT * INTO #T3 FROM BankTransactions WHERE CustomerID = 'C5674116';
SET STATISTICS TIME OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 4: RANGE QUERY VOI INDEX';
PRINT '=======================================================';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_amount')
CREATE NONCLUSTERED INDEX idx_amount ON BankTransactions(TransactionAmount);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

SET STATISTICS TIME ON;
SELECT * INTO #T4 FROM BankTransactions WHERE TransactionAmount > 50000;
SET STATISTICS TIME OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 5: ANALYTICAL QUERY (GROUP BY)';
PRINT '=======================================================';
CHECKPOINT;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
DBCC FREEPROCCACHE WITH NO_INFOMSGS;

SET STATISTICS TIME ON;
SELECT CustLocation, COUNT(*) as Count, SUM(TransactionAmount) as Total
INTO #T5
FROM BankTransactions GROUP BY CustLocation;
SET STATISTICS TIME OFF;
GO

PRINT '=======================================================';
PRINT 'KICH BAN 6: COLUMNSTORE INDEX (ANALYSIS OPTIMIZATION)';
PRINT '=======================================================';

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