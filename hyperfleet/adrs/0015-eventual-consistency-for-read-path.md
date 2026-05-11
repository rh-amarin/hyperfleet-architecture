---
Status: Active
Owner: HyperFleet Team
Last Updated: 2026-05-08
---

# 0015 — Eventual Consistency for the API Read Path

## Context

Sentinels and adapters poll the API continuously, resulting in high read traffic volume. To avoid additional latency and connection pool pressure, the transaction middleware skips transaction creation for read operations (GET requests). This means all read operations may return data that is slightly stale relative to concurrent writes.

The most visible effect is on LIST endpoints, which execute COUNT and SELECT as two independent queries. Under concurrent modifications (inserts or deletes between the two queries), the reported `total` may not match the actual number of items returned, and pagination may skip or duplicate records.

## Decision

Do not use database transactions for read operations. This accepts eventual consistency on the entire read path. For LIST endpoints specifically, do not use window functions to guarantee COUNT/SELECT consistency.

## Consequences

**Gains:** No additional latency on read endpoints. No additional database connection pool pressure from read transactions.

**Trade-offs:** Under concurrent modifications, clients may observe stale data on any GET request. For LIST endpoints specifically, this includes inaccurate total counts, skipped records, or duplicate records across pages.

**Mitigations:** HyperFleet's reconciliation model naturally limits the impact. Sentinels and adapters repoll on intervals, so any inconsistency in a single response is corrected on the next polling cycle.

## Alternatives Considered

The following alternatives were evaluated for ensuring COUNT/SELECT consistency within paginated LIST responses:

| Alternative | Why Rejected |
|-------------|--------------|
| Window function (`COUNT(*) OVER()`) | 32% p99 latency regression, 48% throughput reduction. Postgres scans all matching rows for the window count regardless of page size. |
| Read-only transaction (`BEGIN READ ONLY` wrapping COUNT + SELECT) | 12% p99 latency regression, 22% throughput reduction. Adds overhead to every LIST call. |
| Cursor-based pagination | Eliminates COUNT entirely. Requires a breaking API contract change (removes `total` field, removes direct page access). |

## Benchmark Data

Local benchmarks: 10,000 clusters, 1,000 requests, 10 concurrency, page size 10, 15 runs per approach.

| Approach | p99 Latency | Throughput |
|----------|-------------|------------|
| No transaction (current) | 31.4ms | 789 req/sec |
| Window function | 41.5ms (+32%) | 409 req/sec (-48%) |
| Read-only transaction | 35.1ms (+12%) | 618 req/sec (-22%) |

## References

- [HYPERFLEET-870](https://redhat.atlassian.net/browse/HYPERFLEET-870) — Investigation and benchmark analysis
