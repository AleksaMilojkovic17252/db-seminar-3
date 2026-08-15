-- Experiment 8 — CockroachDB — SQL compatibility probes
-- Run: cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar -f 01_compat.sql
--
-- Same seven features probed on all three engines. Foreign keys and
-- identity columns are already exercised structurally by every schema file
-- and seed load, so they are confirmed rather than freshly tested here.

-- 1. Window functions
SELECT id, region, RANK() OVER (PARTITION BY region ORDER BY balance DESC) AS r
FROM accounts LIMIT 5;
SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM accounts LIMIT 5;

-- 2. Common table expressions
WITH top_regions AS (
  SELECT region, count(*) AS n FROM accounts GROUP BY region
)
SELECT * FROM top_regions ORDER BY n DESC LIMIT 5;

-- 3. RETURNING on UPDATE
UPDATE accounts SET balance = balance + 0 WHERE id = 1 RETURNING id, balance;

-- 4. Foreign key enforcement (expect rejection, SQLSTATE 23503)
INSERT INTO orders (id, customer_id, total)
VALUES (999999999, 999999999, 1.00);

-- 5. JSON access — CockroachDB uses the Postgres ->> operator on JSONB
SELECT ('{"key":"value"}'::JSONB)->>'key' AS extracted;

-- 6. Upsert — COLUMN-SCOPED: only the named column is overwritten
INSERT INTO accounts (id, owner, balance, region)
VALUES (1, 'OVERWRITTEN', 12345.00, 'nowhere')
ON CONFLICT (id) DO UPDATE SET balance = excluded.balance;
SELECT id, owner, balance, region FROM accounts WHERE id = 1;
-- owner and region should be UNCHANGED from their seeded values.

-- 7. Stored procedure
CREATE PROCEDURE noop_proc() LANGUAGE SQL AS $$ SELECT 1; $$;
DROP PROCEDURE noop_proc;
