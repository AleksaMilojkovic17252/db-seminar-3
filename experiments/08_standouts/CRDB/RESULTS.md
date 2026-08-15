# Experiment 8 — Results — CockroachDB

## SQL compatibility

| Feature | Result |
|---|---|
| Window functions (`RANK()`, `ROW_NUMBER()`) | works |
| CTEs (`WITH ... AS`) | works |
| `RETURNING` on `UPDATE` | works — returns the row cleanly |
| Foreign key enforcement | rejects, `SQLSTATE 23503` |
| Identity columns | `IDENTITY` (`schema/schema_pg.sql`) |
| JSON access | `->>'key'` on `::JSONB` |
| Upsert | `ON CONFLICT (id) DO UPDATE SET col = excluded.col` — **column-scoped**: only the named column is overwritten, `owner` and `region` keep their seeded values |
| Stored procedures | **works** — user-defined procedures since v22.2 |

Full matrix: `experiments/08_standouts/exp8_compatibility.md`.

## The two rows that actually matter

**Stored procedures** split three ways: CockroachDB yes, TiDB no, Spanner
no. Not a feature-flag gap — it reflects real differences in what each
engine's SQL layer is. CockroachDB added them relatively recently; TiDB's
MySQL compatibility historically stopped short of them; GoogleSQL has no
procedural-SQL concept in its DDL grammar at all.

**Upsert** is where CockroachDB and TiDB agree and Spanner diverges
semantically, not just syntactically. Both `ON CONFLICT ... DO UPDATE SET`
and TiDB's `ON DUPLICATE KEY UPDATE` are column-scoped: you name exactly
which columns to overwrite and the rest are untouched. Spanner's
`INSERT OR UPDATE` replaces the **whole row**. See `../SPANNER/RESULTS.md`
— a team porting upsert logic between these engines hits a correctness bug,
not a translation problem.

## Not redone at RF=3

SQL dialect support does not depend on replication factor. Checked before
deciding, not assumed.
