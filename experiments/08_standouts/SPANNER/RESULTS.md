# Experiment 8 — Results — Spanner Omni

## Part 1 — interleaved-table locality

### Query A — the optimizer eliminated the join entirely

```sql
SELECT o.id, oi.item_id, oi.product_id, oi.quantity
FROM orders o JOIN order_items oi ON oi.id = o.id LIMIT 20
```

The plan **never scans `orders`** — only a single `TableScan` on
`order_items` inside one Distributed Union
(`distribution_table: order_items`). Because interleaving guarantees
`order_items.id` *is* the parent order's id, `o.id` can be read directly off
the child row.

`remote_server_calls: 0/0`, `rows_scanned: 20`.

This is stronger evidence than "the join stayed co-located" would have been:
the optimizer did not merely avoid a network hop, it proved the join was
redundant.

### Query B — forcing a real join

Asking for `o.total`, a column that exists only on `orders`, forces the join
to happen:

```
cpu_time: 6.82 ms, elapsed_time: 8.35 ms
data_bytes_read: 112,514, rows_scanned: 40, rows_returned: 20
remote_server_calls: 0/0
```

### The control — the same join without interleaving

Run against `order_items_flat`, a non-interleaved twin, the identical query
scans **26x more rows**.

Raw output: `experiments/08_standouts/exp8_spanner_interleaved_plan.txt`,
`exp8_spanner_flat_plan.txt`, `exp8_spanner_01.txt`–`exp8_spanner_05.txt`.
Screenshot: `results/screenshots/exp8_spanner_interleaved_plan.png`.

### Caveat, stated because it matters

`remote_server_calls: 0/0` on the RF=1 deployment is **not** proof that
interleaving preserved locality — there was only one server, so nothing
could have been remote. The real evidence here is the **26x row-scan
difference** and the join elimination, both of which are
replication-independent. This is also why the demo was not re-run at RF=3:
Experiment 1 shows everything still fits in one group even there, so a
repeat would reproduce `0` for the wrong reason.

## Part 2 — SQL compatibility

| Feature | Result |
|---|---|
| Window functions | **fails** — `Unsupported built-in function`, both `RANK` and `ROW_NUMBER`, identically |
| CTEs | works |
| `THEN RETURN` (GoogleSQL's `RETURNING`) | accepted — correct syntax — but the CLI did not print the returned columns. A **display** quirk, not a rejection |
| Foreign key enforcement | rejects, with its own FK violation message |
| Identity columns | **none** — no autoincrement concept at all; ids assigned explicitly by the seed generator |
| JSON access | `JSON_VALUE(doc, '$.key')` |
| Upsert | `INSERT OR UPDATE INTO ...` — **replaces the entire row** |
| Stored procedures | **fails** — DDL parser error; GoogleSQL has no procedure concept |
| Full-text search | works — `SEARCH(Name_Tokens, 'phone')` on the bundled `retail-sample` database |

Full matrix: `experiments/08_standouts/exp8_compatibility.md`.
Full-text output: `experiments/08_standouts/exp8_spanner_fulltext.txt`.

## The two rows worth stating precisely

**Window functions.** Production Spanner documents `RANK()` and
`ROW_NUMBER()` as standard GoogleSQL functions. Their absence here is almost
certainly a gap in **this specific Preview build**, not a dialect
limitation. Say it that way — do not let it become "Spanner lacks window
functions."

**Upsert is a genuine semantic difference, not syntax.** Verified directly:
`owner` and `region` were overwritten on Spanner even though only `balance`
was meant to change, while CockroachDB and TiDB left them at their seeded
values. A team porting upsert logic between these engines hits a real
correctness bug, and no amount of syntax translation catches it.

## Not redone at RF=3

Dialect support has no replication dependency. The locality demo was
assessed and deliberately not re-run — see the caveat above.
