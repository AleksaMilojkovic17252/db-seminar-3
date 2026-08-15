# Experiment 5 — Results — CockroachDB

## Measured

Three calls, three separate connections:

```
1785253941830227394.0000000000
1785253944273571133.0000000000
1785253945958757268.0000000000
```

Monotonically increasing. Because the three calls came from three separate
client connections with no shared transaction state, this shows the cluster
clock advancing, not a per-session counter.

**Clock offset across the 3 nodes:** fluctuates in the **0–50 µs** range
over the observed period — far below the default `--max-offset` of 500 ms.

Raw output: `experiments/05_clocks/exp5_crdb_timestamps.txt`.
Screenshot: `results/screenshots/exp5_crdb_clockoffset.png`.

## What it means

| Property | CockroachDB |
|---|---|
| Mechanism | Hybrid Logical Clock (HLC) |
| Centralisation | **none** — each node computes locally, adjusted by observed peer timestamps |
| Hardware requirement | none beyond ordinary NTP-grade sync |
| Cost paid | uncertainty restarts when a read falls inside the uncertainty window |

The measured 0–50 µs offset is four orders of magnitude inside the 500 ms
tolerance, which is why uncertainty restarts are rare in practice on a
single machine — and also why this figure should not be read as evidence
about a real wide-area deployment, where the whole point of the bound is
network and drift conditions this test cannot reproduce.

Contrast with the other two: TiDB routes every transaction start through one
PD process; Spanner assigns the timestamp server-side at commit and waits
out its uncertainty interval. Three different answers to the same problem,
with three different costs.
