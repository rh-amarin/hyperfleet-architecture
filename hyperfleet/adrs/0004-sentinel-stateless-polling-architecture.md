---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0004 — Sentinel as a Stateless Polling Reconciliation Loop

## Context

HyperFleet needs a mechanism to detect when cluster and nodepool resources require provisioning or deprovisioning work, and to trigger the correct Adapter workflow at the right moment. The trigger mechanism must handle stale resources (ready but not confirmed recently), generation mismatches (spec updated but adapters haven't caught up), and debounced not-ready resources — all without tight coupling between the API service and the Adapters. HYPERFLEET-32 drove the evaluation.

## Decision

**Sentinel** is a standalone stateless Go service that polls the HyperFleet REST API at a configurable interval (default 5 s) and publishes a CloudEvent to the broker for each resource that meets a configured CEL-based trigger condition. Sentinel holds no persistent state; the HyperFleet API is the single source of truth. Multiple Sentinel instances can run in parallel, each watching a disjoint label-filtered subset of resources (horizontal sharding). Sentinel's sole responsibility is "decide when" — it never executes provisioning logic.

Default trigger conditions (all expressed in CEL, overridable via config):

| Condition | Trigger |
|-----------|---------|
| `is_new_resource` | generation = 1 and not yet ready |
| `generation_mismatch` | API generation > observed generation in conditions |
| `ready_and_stale` | ready resource not confirmed in > 30 minutes |
| `not_ready_and_debounced` | not-ready resource stuck for > 10 seconds |

## Consequences

**Gains:** Stateless design means Sentinel scales horizontally without coordination; no database or CRD installation required; polling interval and trigger logic are tunable per deployment without recompilation; the clear separation between "detect" (Sentinel) and "execute" (Adapter) makes each independently deployable and testable.

**Trade-offs:** Polling introduces a trigger latency bounded by the poll interval (up to 5 s); at-least-once delivery means Adapters must be idempotent; multiple Sentinel instances must be configured with non-overlapping label selectors by the operator — there is no automatic partition assignment.

Polling consumes more resources, since querying the API responds with full API resource payload, when just a small part of the information will be delivered in the message.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Transactional Outbox pattern (DB trigger → broker) | Couples message publishing to the API database transaction; requires the API service to own broker connectivity; adds a background outbox processor to the API deployment |
| Kubernetes CRD Operator | Requires CRD installation on every management cluster; higher operational overhead; the team wanted cluster-lifecycle management to work without modifying the target cluster's API surface |
| Event-driven push from API on state change | The API is intentionally a "dumb CRUD" layer (ADR-0003); adding push logic violates the separation of concerns and makes the API aware of downstream consumers |
| Long-polling / watch endpoint on HyperFleet API | Would require implementing a streaming watch mechanism in the API, significantly increasing API complexity for what is essentially a polling concern |
