-- Experiment 4 — C1 — TiDB at its DEFAULT isolation
-- (Repeatable Read, which is Snapshot Isolation in TiDB)
-- Expected: BOTH commit. Write skew.
--
-- TWO TERMINALS. Step through; do not run end-to-end.
--   mysql -h 127.0.0.1 -P 4000 -u root -D seminar

-- ---------- RESET (either terminal) ----------
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2

-- ---------- TERMINAL A ----------
SELECT @@transaction_isolation;                      -- expect REPEATABLE-READ
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2

-- ---------- TERMINAL B ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2

-- ---------- TERMINAL A ----------
UPDATE doctors SET on_call = false WHERE id = 1;     -- succeeds immediately

-- ---------- TERMINAL B ----------
UPDATE doctors SET on_call = false WHERE id = 2;     -- succeeds immediately,
                                                     -- DID NOT BLOCK

-- ---------- TERMINAL A ----------
COMMIT;   -- succeeds

-- ---------- TERMINAL B ----------
COMMIT;   -- succeeds

-- ---------- FINAL CHECK ----------
SELECT count(*) FROM doctors WHERE on_call = true;   -- 0 — INVARIANT VIOLATED
