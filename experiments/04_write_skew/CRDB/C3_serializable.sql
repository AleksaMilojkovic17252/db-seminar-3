-- Experiment 4 — C3 — CockroachDB at its DEFAULT isolation (Serializable)
-- Expected: one transaction is rejected. No write skew.
--
-- TWO TERMINALS. Step through; do not run end-to-end.
--   cockroachdb-26 sql --insecure --host=localhost:26257 -d seminar

-- ---------- RESET (either terminal) ----------
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2

-- ---------- TERMINAL A ----------
SHOW transaction_isolation;                          -- expect: serializable
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2
UPDATE doctors SET on_call = false WHERE id = 1;     -- UPDATE 1, succeeds

-- ---------- TERMINAL B (while A is still open) ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2
UPDATE doctors SET on_call = false WHERE id = 2;     -- UPDATE 1, succeeds

-- ---------- TERMINAL A ----------
COMMIT;   -- <== FAILS HERE. SQLSTATE 40001, RETRY_SERIALIZABLE.

-- ---------- TERMINAL B ----------
COMMIT;   -- succeeds cleanly

-- ---------- FINAL CHECK ----------
SELECT id, on_call FROM doctors WHERE id IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- 1 — invariant held
