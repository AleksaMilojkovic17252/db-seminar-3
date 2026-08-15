-- Experiment 4 — C2b — TiDB, FOR UPDATE *plus* an explicit
-- application-level invariant check. This is the version that works.
--
-- The difference from C2 is one conditional: session B branches on the
-- value its locked read returned, instead of writing regardless.
--
-- TWO TERMINALS. Step through; do not run end-to-end.

-- ---------- RESET ----------
UPDATE doctors SET on_call = true  WHERE id IN (1,2);
UPDATE doctors SET on_call = false WHERE id NOT IN (1,2);
SELECT count(*) FROM doctors WHERE on_call = true;   -- must be 2

-- ---------- TERMINAL A ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true FOR UPDATE;   -- 2
-- Invariant check: taking one off call leaves 1 >= 1, so proceed.
UPDATE doctors SET on_call = false WHERE id = 1;
COMMIT;

-- ---------- TERMINAL B (blocked on A's lock until A commits) ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true FOR UPDATE;
-- Returns 1 (fresh, post-A value).
-- Invariant check: taking one off call would leave 0. ABORT instead.
ROLLBACK;

-- ---------- FINAL CHECK ----------
SELECT count(*) FROM doctors WHERE on_call = true;   -- 1 — invariant held
