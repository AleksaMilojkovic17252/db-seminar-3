# Experiment 8 — SQL Compatibility Matrix

Same query/feature set run against all three engines' `seminar` database
(identical schema/data, per Phase 2). Foreign keys and identity/auto-increment
columns were already exercised structurally across the whole project
(every schema file, every seed load); the other five features were tested
fresh here.

| Feature | CockroachDB | TiDB | Spanner Omni |
|---|---|---|---|
| Window functions (`RANK()`/`ROW_NUMBER()`) | ✅ works | ✅ works | ❌ `Unsupported built-in function` — both `RANK` and `ROW_NUMBER` fail identically |
| CTEs (`WITH ... AS`) | ✅ works | ✅ works | ✅ works |
| `RETURNING` / `THEN RETURN` | ✅ works, returns row | ❌ syntax error — MySQL/TiDB has no `RETURNING` on `UPDATE` | ⚠️ accepted (`THEN RETURN` is the correct GoogleSQL syntax), but the CLI didn't print the returned columns — a display quirk, not a rejection |
| Foreign key enforcement | ✅ rejects (`SQLSTATE 23503`) | ✅ rejects (error 1452) | ✅ rejects (own FK violation message) |
| `SERIAL`/identity columns | `IDENTITY` (schema_pg.sql) | `AUTO_INCREMENT` (schema_mysql.sql) | none — no autoincrement concept at all; IDs assigned explicitly by the seed generator (see Phase 2 notes) |
| JSON functions | ✅ `->>'key'` on `::JSONB` | ✅ `JSON_EXTRACT(doc, '$.key')` | ✅ `JSON_VALUE(doc, '$.key')` |
| Upsert (`INSERT ... ON CONFLICT` / equivalent) | ✅ `ON CONFLICT (id) DO UPDATE SET col = excluded.col` — updates only the named column(s) | ✅ `ON DUPLICATE KEY UPDATE col = VALUES(col)` — updates only the named column(s) | ✅ `INSERT OR UPDATE INTO ...` — **replaces the entire row**, not just named columns (genuine semantic difference, not just syntax) |
| Stored procedures (`CREATE PROCEDURE`) | ✅ works (CockroachDB added user-defined procedures in v22.2+) | ❌ syntax error — not supported | ❌ DDL parser error — GoogleSQL has no procedure concept |

## Notable findings, not just pass/fail

- **Window functions on Spanner Omni**: production Spanner documents
  `RANK()`/`ROW_NUMBER()` as standard GoogleSQL functions — their absence
  here is almost certainly a **Preview-build gap in this specific Omni
  release**, not a GoogleSQL dialect limitation. Stated precisely to avoid
  the paper implying Spanner itself lacks window functions.
- **Upsert semantics genuinely differ, not just syntax**: CockroachDB's
  `ON CONFLICT ... DO UPDATE SET` and TiDB's `ON DUPLICATE KEY UPDATE` are
  both column-scoped — you name exactly which columns to overwrite on
  conflict, leaving the rest untouched. Spanner's `INSERT OR UPDATE`
  replaces the **whole row** with whatever the `INSERT` specifies,
  verified directly: `owner`/`region` were overwritten on Spanner even
  though only `balance` was intentionally changed, while CockroachDB and
  TiDB correctly left `owner`/`region` at their original seeded values.
  A team porting upsert logic between these engines would hit a real
  correctness bug here, not just a syntax translation issue.
- **`RETURNING`/`THEN RETURN`**: three genuinely different postures, not a
  binary supported/unsupported split — CockroachDB returns the row
  cleanly, TiDB has no equivalent for `UPDATE` at all, and Spanner accepts
  the correct syntax but the CLI tool didn't surface the result (a Preview
  CLI limitation worth separating from a dialect limitation).
- **Stored procedures**: a genuine three-way split reflecting real
  architectural differences, not just feature-flag gaps — CockroachDB
  added user-defined procedures relatively recently (v22.2+), TiDB has
  never implemented them (MySQL compatibility historically stopped short
  of this), and Spanner's GoogleSQL has no procedural-SQL concept in its
  DDL grammar at all.

## Artifacts

All commands and raw output pasted directly into this session's working
log; representative CLI transcripts also saved under
`experiments/08_standouts/exp8_spanner_0*.txt` and `exp8_tidb_01.txt` for
the queries that overlap with the locality/HTAP demos.
