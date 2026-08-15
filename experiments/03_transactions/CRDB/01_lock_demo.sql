-- Experiment 3 — CockroachDB — lock/intent observation
--
-- TWO TERMINALS. Do not run this file end-to-end; step through it.
-- Open both with:
--   cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar
--
-- ============ TERMINAL A ============ (leave the transaction OPEN)
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
-- STOP HERE. Do not commit yet. Switch to terminal B.

-- ============ TERMINAL B ============ (while A is still open)
SET allow_unsafe_internals = true;   -- same session as the query below
SELECT database_name, table_name, lock_key_pretty, txn_id,
       lock_strength, durability, isolation_level, granted
FROM crdb_internal.cluster_locks;
-- Expect: two Exclusive, Unreplicated intents held by A's txn on rows 1
-- and 2 of `accounts`, both tagged isolation_level = SERIALIZABLE.
-- Note what does NOT happen: nothing is blocked.

-- ============ TERMINAL A ============
COMMIT;
