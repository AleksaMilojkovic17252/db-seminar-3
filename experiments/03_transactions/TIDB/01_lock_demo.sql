-- Experiment 3 — TiDB — pessimistic lock observation
--
-- THREE TERMINALS. Do not run this file end-to-end; step through it.
-- Open each with:
--   mysql -h 127.0.0.1 -P 4000 -u root -D seminar
--
-- ============ TERMINAL A ============ (leave the transaction OPEN)
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
-- STOP HERE. Do not commit. Switch to terminal C.

-- ============ TERMINAL C ============ (observer, while A is open)
-- Do NOT filter on STATE: an open-but-idle transaction reports 'Idle',
-- not 'Running'. MEM_BUFFER_KEYS is the signal that locks are held.
SELECT id, start_time, state, mem_buffer_keys, mem_buffer_bytes, session_id
FROM information_schema.cluster_tidb_trx;
-- Expect A's transaction with MEM_BUFFER_KEYS = 2 (the two locked rows).

-- ============ TERMINAL B ============ (contender — same row as A)
BEGIN;
UPDATE accounts SET balance = balance - 1 WHERE id = 1;
-- This BLOCKS. It does not return until A commits or rolls back.

-- ============ TERMINAL C ============ (while B is blocked)
SELECT * FROM information_schema.data_lock_waits;
-- Expect one row: B's txn id waiting on A's txn id, with KEY_INFO
-- identifying the contended row. Cross-check the two txn ids against
-- cluster_tidb_trx above.

-- ============ TERMINAL A ============
COMMIT;   -- B now unblocks

-- ============ TERMINAL B ============
COMMIT;
