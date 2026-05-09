CREATE DATABASE BankDB;
GO

USE BankDB;
GO

-- xóa các bảng cũ
IF OBJECT_ID('BankTransactions', 'U') IS NOT NULL DROP TABLE BankTransactions;
IF OBJECT_ID('BankTransactions_Staging', 'U') IS NOT NULL DROP TABLE BankTransactions_Staging;
GO

-- tạo bảng trung gian lấy dữ liệu thô (ko có key)
CREATE TABLE BankTransactions_Staging (
        TransactionID VARCHAR(50),
        CustomerID VARCHAR(50),
        CustomerDOB VARCHAR(50),
        CustGender CHAR(1),
        CustLocation VARCHAR(100),
        CustAccountBalance FLOAT,
        TransactionDate VARCHAR(50),
        TransactionTime INT,
        TransactionAmount FLOAT
);
GO

-- tạo bảng thật
CREATE TABLE BankTransactions (
        TransactionID INT PRIMARY KEY,  -- đổi từ varchar sang int
        CustomerID VARCHAR(50),
        CustomerDOB VARCHAR(50),
        CustGender CHAR(1),
        CustLocation VARCHAR(100),
        CustAccountBalance FLOAT,
        TransactionDate VARCHAR(50),
        TransactionTime INT,
        TransactionAmount FLOAT
);
GO

-- đổ dữ liệu vào bảng tạm
BULK INSERT BankTransactions_Staging
    FROM '/dataset/bank_transactions_clean.csv'
    WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
    );
GO

-- insert dữ liệu vào bảng chính chỉnh phần transaction_id
INSERT INTO BankTransactions
SELECT
    CAST(REPLACE(TransactionID, 'T', '') AS INT),
    CustomerID,
    CustomerDOB,
    CustGender,
    CustLocation,
    CustAccountBalance,
    TransactionDate,
    TransactionTime,
    TransactionAmount
FROM BankTransactions_Staging;
GO

-- dọn bảng tạm
DROP TABLE BankTransactions_Staging;
GO
