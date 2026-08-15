-- Experiment 8 — TiDB — SQL compatibility probes
-- Run: mysql -h 127.0.0.1 -P 4000 -u root -D seminar < 01_compat.sql

-- 1. Window functions
SELECT id, region, RANK() OVER (PARTITION BY region ORDER BY balance DESC) AS r
FROM accounts LIMIT 5;
SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM accounts LIMIT 5;

-- 2. Common table expressions
WITH top_regions AS (
  SELECT region, count(*) AS n FROM accounts GROUP BY region
)
SELECT * FROM top_regions ORDER BY n DESC LIMIT 5;

-- 3. RETURNING on UPDATE — EXPECTED TO FAIL: MySQL/TiDB has no equivalent
UPDATE accounts SET balance = balance + 0 WHERE id = 1 RETURNING id, balance;

-- 4. Foreign key enforcement (expect rejection, error 1452)
INSERT INTO orders (id, customer_id, total)
VALUES (999999999, 999999999, 1.00);

-- 5. JSON access — MySQL/TiDB form
SELECT JSON_EXTRACT('{"key":"value"}', '$.key') AS extracted;

-- 6. Upsert — COLUMN-SCOPED: only the named column is overwritten
INSERT INTO accounts (id, owner, balance, region)
VALUES (1, 'OVERWRITTEN', 12345.00, 'nowhere')
ON DUPLICATE KEY UPDATE balance = VALUES(balance);
SELECT id, owner, balance, region FROM accounts WHERE id = 1;
-- owner and region should be UNCHANGED from their seeded values.

-- 7. Stored procedure — EXPECTED TO FAIL: not supported
CREATE PROCEDURE noop_proc() BEGIN SELECT 1; END;
