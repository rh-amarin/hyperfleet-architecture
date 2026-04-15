---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-16
---

# 0008 — Dynamic Status Aggregation (Compute on Write)

## Context

Multiple Adapters report individual condition updates for each cluster and nodepool. The HyperFleet API must present a synthesized `Available` / `Ready` view to callers. Two approaches were prototyped in a POC (referenced in HYPERFLEET-25 / HYPERFLEET-5): a background aggregation processor that maintains a pre-computed status record, and dynamic computation that derives the aggregated status on each GET request from the stored per-adapter condition rows.

## Decision

The API computes **aggregated status synchronously on the write path** — on resource creation, resource replacement, and adapter status upsert — and persists the result to a `status_conditions` JSONB column on the resource row. No background processor or materialized status cache exists. GET requests return the stored `status_conditions` value directly without triggering recomputation.

On each write event, the service layer reads all `adapter_statuses` rows for the resource and derives `Available` and `Ready` by evaluating which configured required Adapters have reported at the current generation:

- `Ready=True` requires every Adapter listed in `required_adapters` (operator-configured) to have a condition row at `observed_generation = resource.generation` with `Available=True`.
- `Available` uses stickier logic: when adapters report at mixed generations and the previous state was `True`, `Available` remains `True` until all required adapters report at the new generation.
- An adapter may report `Available=Unknown` only on its first report for a resource; subsequent `Unknown` reports are discarded. Only `True` and `False` trigger aggregation.

## Consequences

**Gains:** GET latency is constant regardless of adapter count — no aggregation work on the read path; no background process to operate, monitor, or restart; simpler data model (one `adapter_statuses` table, no separate aggregated status table); aggregation cost is proportional to write frequency (adapter reports), not read frequency (Sentinel polls).

**Trade-offs:** A brief propagation window exists between an adapter completing its upsert and the aggregation write committing — Sentinel may observe the previous aggregated state within this window; write latency on the adapter-status upsert path scales linearly with the number of Adapters per resource (each upsert reads all adapter rows for the resource); there is no history of intermediate aggregated states (only the current snapshot stored in `status_conditions`).

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Background aggregation processor (event-driven watcher) | POC showed added operational complexity (process crashes leave stale aggregated state); eventual consistency window means Sentinel may read stale `Ready` status and under- or over-trigger; introduces a background goroutine that is harder to test deterministically |
| Compute on every GET request | Aggregation cost would scale with Sentinel poll rate (thousands of resources at 5 s intervals), adding unnecessary database load; rejected in favour of compute-on-write which amortises the cost across the lower-frequency write path |
| Event-sourced status with materialized snapshots | Correct eventual consistency but requires a snapshot mechanism, compaction policy, and additional storage; over-engineered for the cluster-count scale of HyperFleet MVP |
