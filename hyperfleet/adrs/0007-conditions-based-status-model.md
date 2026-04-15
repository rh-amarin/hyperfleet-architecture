---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0007 — Kubernetes-Style Conditions-Based Status Model

## Context

Multiple Adapters report provisioning outcomes for each cluster and nodepool, and Sentinel needs to detect when a resource is stale or ready. An early phase-based status model (e.g., `Pending → Provisioning → Ready`) was implemented in v0.1.0 but proved too coarse: it could not represent partial readiness (some adapters complete, others still in progress), and it gave Sentinel no signal about which generation each adapter had processed. HYPERFLEET-25 drove the replacement.

## Decision

Resource status is expressed as a list of **named conditions** following Kubernetes condition conventions. Each condition carries:

| Field | Description |
|-------|-------------|
| `type` | Condition name (e.g., `Available`, `Ready`) |
| `status` | `True`, `False`, or `Unknown` |
| `reason` | Machine-readable camel-case string |
| `message` | Human-readable explanation |
| `observed_generation` | API resource generation at the time the Adapter reported |
| `last_transition_time` | RFC 3339 timestamp of the last status → status change |

Two conditions are mandatory on all resources: **`Available`** and **`Ready`**. Initial state after creation is `Available=Unknown, Ready=False` (reason: `AwaitingAdapters`). `Ready=True` requires all configured required Adapters to have reported at the current generation. Adapters report via `POST .../statuses`; the API synthesizes the aggregated view on adapter report updates (see ADR-0008).

## Consequences

**Gains:** Condition granularity exposes partial readiness (e.g., DNS adapter done, HyperShift adapter still running); `observed_generation` on each condition lets clients distinguish "not yet reconciled at this generation" from "reconciliation failed"; the model is familiar to Kubernetes practitioners and aligns with the OCM/HyperShift condition conventions used downstream.

**Trade-offs:** Breaking change from the phase-based model (removed in v0.1.0, not backwards-compatible); Adapter authors must report typed conditions rather than a simple status field; the mandatory `Available` and `Ready` conditions add an opinion about which conditions matter, which may not fit all future resource types.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Phase-based model (`Pending → Provisioning → Ready`) | Cannot represent partial readiness across multiple Adapters; no per-adapter generation tracking; replaced as a breaking change in v0.1.0 |
| Simple boolean `ready` field | No reason/message metadata; no generation tracking; Sentinel cannot distinguish "not started" from "failed" from "in progress" |
| Event-sourced status history | Full history is useful for debugging but adds storage and query complexity beyond MVP requirements; the current model retains `last_transition_time` as a lightweight audit trail |
