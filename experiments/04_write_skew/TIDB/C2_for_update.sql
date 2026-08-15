-- Experiment 4 — C2 — TiDB, default isolation + SELECT ... FOR UPDATE
-- with an UNCONDITIONAL write.
--
-- The runbook predicted "blocks/aborts -> no skew". That prediction is
-- WRONG, and finding out why is the point of this condition.
--
-- TWO TERMINALS. Step through; do not run end-to-end.

-- ---------- RESET ----------
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2

-- ---------- TERMINAL A ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true FOR UPDATE;   -- 2
UPDATE doctors SET on_call = false WHERE id = 1;
-- Do NOT commit yet. Start terminal B now, then come back.

-- ---------- TERMINAL B (start right after A's SELECT, before A's COMMIT) ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true FOR UPDATE;
-- This BLOCKS, waiting on A's still-open transaction.
-- (Measured: 16.154s, until A committed.)

-- ---------- TERMINAL A ----------
COMMIT;   -- B now unblocks and its SELECT returns 1, not the stale 2

-- ---------- TERMINAL B ----------
-- The read was fresh. The write ignores it anyway:
UPDATE doctors SET on_call = false WHERE id = 2;   -- unconditional, runs
COMMIT;

-- ---------- FINAL CHECK ----------
SELECT count(*) FROM doctors WHERE on_call = true;   -- 0 — STILL SKEWED
