USE bank_ks;

-- ========================================================
-- KB1: POINT LOOKUP (Hash)
-- ========================================================
TRACING ON;
SELECT COUNT(*) FROM bank_transactions WHERE transaction_id = 'T1048548';
TRACING OFF;

-- ========================================================
-- KB2: TABLE SCAN
-- ========================================================
TRACING ON;
SELECT COUNT(*) FROM bank_transactions WHERE customer_id = 'C5674116' ALLOW FILTERING;
TRACING OFF;

-- ========================================================
-- KB3: SECONDARY INDEX (2i)
-- ========================================================
CREATE INDEX IF NOT EXISTS idx_customer_cas ON bank_transactions(customer_id);

TRACING ON;
SELECT COUNT(*) FROM bank_transactions WHERE customer_id = 'C5674116';
TRACING OFF;

-- ========================================================
-- KB4: RANGE QUERY (SAI INDEX)
-- ========================================================
CREATE CUSTOM INDEX IF NOT EXISTS idx_amount_sai ON bank_transactions(transaction_amount) USING 'sai';

TRACING ON;
SELECT COUNT(*) FROM bank_transactions WHERE transaction_amount > 50000;
TRACING OFF;

-- ========================================================
-- KB5: ANALYTICAL QUERY (TÍNH CẢ CHI PHÍ TẠO VIEW)
-- ========================================================
-- xóa view cũ
DROP MATERIALIZED VIEW IF EXISTS transactions_by_location;

-- đo thời gian thiết lập materialized view
TRACING ON;
CREATE MATERIALIZED VIEW transactions_by_location AS
SELECT cust_location, transaction_id, transaction_amount
FROM bank_transactions
WHERE cust_location IS NOT NULL
  AND transaction_id IS NOT NULL
PRIMARY KEY (cust_location, transaction_id);
TRACING OFF;

-- đo thời gian querrt=y
TRACING ON;
SELECT cust_location, SUM(transaction_amount)
FROM transactions_by_location
GROUP BY cust_location LIMIT 10;
TRACING OFF;