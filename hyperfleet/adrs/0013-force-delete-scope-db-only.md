---
Status: Proposed
Owner: HyperFleet Team
Last Updated: 2026-05-01
---

# 0013 — Force Delete Scope: Database-Only

**Jira**: [HYPERFLEET-895](https://redhat.atlassian.net/browse/HYPERFLEET-895)

**Related**: [Force Deletion Design](../docs/force-deletion-design.md)

---

## Context

Force delete is an admin escape hatch to hard-delete resources stuck in `Finalizing` state. This ADR records the decision on scope. Force-delete removes database records only and does not attempt infrastructure cleanup.

---

## Decision

Force delete removes records from the HyperFleet database only. Infrastructure managed by adapters (K8s clusters, nodepools, cloud resources) may be orphaned.

---

## Consequences

**Gains:** Unblocks resources stuck in `Finalizing` indefinitely. Simple implementation scoped to the API with no changes to Sentinel or adapters.

**Trade-offs:** K8s resources managed by adapters may be orphaned if adapters did not finish cleanup before force delete. See [Force Deletion Design](../docs/force-deletion-design.md#trade-offs) for full analysis.

---

## Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| Full-stack force delete (DB + infrastructure cleanup) | Couples force delete to adapter availability, the same problem it solves. The extension path preserves this option without blocking the initial implementation. |
| Per-adapter skip annotations | Adds a middle ground that touches API, Sentinel, and adapter framework for a narrow case. See [Force Deletion Design](../docs/force-deletion-design.md#alternatives-considered). |

---

## Extension Path

If orphaned infrastructure becomes a recurring problem, cleanup can be handled via a dedicated endpoint or a cleanup adapter/controller, without changing the existing force-delete API contract.
