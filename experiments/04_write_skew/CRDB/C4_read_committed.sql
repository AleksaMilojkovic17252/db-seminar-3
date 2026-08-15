-- Experiment 4 — C4 — CockroachDB FORCED to Read Committed
-- Expected: BOTH transactions commit. Write skew, on the same engine as C3.
--
-- This is the condition that makes the experiment a controlled experiment
-- rather than a vendor comparison. Only the isolation level changes.
--
-- TWO TERMINALS. Step through; do not run end-to-end.

-- ---------- RESET (either terminal) ----------
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2

-- ---------- TERMINAL A ----------
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;                          -- expect: read committed
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2
UPDATE doctors SET on_call = false WHERE id = 1;     -- UPDATE 1

-- ---------- TERMINAL B (opened and read while A is still in flight) ----------
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2 (A not yet committed)
UPDATE doctors SET on_call = false WHERE id = 2;     -- UPDATE 1

-- ---------- TERMINAL A ----------
COMMIT;   -- succeeds, no error

-- ---------- TERMINAL B ----------
COMMIT;   -- succeeds, no error

-- ---------- FINAL CHECK ----------
SELECT count(*) FROM doctors WHERE on_call = true;   -- 0 — INVARIANT VIOLATED
