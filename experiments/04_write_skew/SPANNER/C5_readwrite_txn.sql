-- Experiment 4 — C5 — Spanner Omni, read-write transaction
-- (isolation is not lowerable on Spanner — there is no weaker tier)
-- Expected: one transaction aborts. No write skew.
--
-- TWO INTERACTIVE SHELLS. `execute-sql` cannot hold a transaction open
-- across invocations, so use the interactive shell for the interleaving:
--   docker exec -it spanneromni /google/spanner/bin/spanner sql --database=seminar
-- The prompt becomes `spanner-cli(rw txn)>` once BEGIN; has been accepted.

-- ---------- RESET (via execute-sql, ONE statement per invocation) ----------
-- docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
--   --sql="UPDATE doctors SET on_call = true WHERE id IN (1,2)"
-- docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
--   --sql="UPDATE doctors SET on_call = false WHERE id NOT IN (1,2)"
-- docker exec -i spanneromni /google/spanner/bin/spanner databases execute-sql seminar \
--   --sql="SELECT count(*) FROM doctors WHERE on_call = true"      -- must be 2

-- ---------- SHELL A ----------
BEGIN;                                               -- prompt -> (rw txn)
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2

-- ---------- SHELL B (opened while A's transaction is still open) ----------
BEGIN;
SELECT count(*) FROM doctors WHERE on_call = true;   -- 2

-- ---------- SHELL A ----------
UPDATE doctors SET on_call = false WHERE id = 1;     -- succeeds immediately

-- ---------- SHELL B ----------
UPDATE doctors SET on_call = false WHERE id = 2;     -- succeeds immediately,
                                                     -- did NOT block

-- ---------- SHELL A ----------
COMMIT;   -- succeeds

-- ---------- SHELL B ----------
COMMIT;   -- <== FAILS HERE: Aborted

-- ---------- FINAL CHECK ----------
SELECT count(*) FROM doctors WHERE on_call = true;   -- 1 — invariant held
