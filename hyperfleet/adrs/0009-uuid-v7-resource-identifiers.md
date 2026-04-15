---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0009 — UUID v7 for Cluster and NodePool Identifiers

## Context

HyperFleet clusters are provisioned via HyperShift, which requires an RFC 4122-compliant UUID in `spec.clusterID`. The early HyperFleet API used opaque, non-UUID primary IDs that were incompatible with this requirement. HYPERFLEET-732 evaluated two paths: replace existing IDs with UUID v7, or add a separate UUID v4 field alongside the existing ID.

## Decision

The primary identifier for every **Cluster** and **NodePool** resource is a **UUID v7** (time-ordered, RFC 4122 compliant). UUID v7 IDs are displayed as lowercase with hyphens (e.g., `01965b2a-f4c3-7e81-b12d-4a8f6c920d55`). The option to keep the existing opaque ID and add a parallel UUID field was rejected by team vote; a single ID field eliminates the dual-identifier ambiguity for all callers.

UUID v7 is used in place of UUID v4 (not alongside it) because:

1. UUID v7 is structurally identical to UUID v4 — both are 128-bit, RFC 4122 variant 2 — so all tooling that accepts UUID v4 accepts UUID v7.
2. The time-ordered prefix enables natural sort by creation time without a secondary `created_at` index on ID-only queries.
3. HyperShift does not distinguish v4 from v7 at the binary level.

## Consequences

**Gains:** RFC 4122 compliance satisfies HyperShift's `spec.clusterID` requirement without an extra field; time-ordered IDs allow pagination and debugging queries to use the ID prefix as a rough creation timestamp; a single primary identifier eliminates the need for callers to track two ID fields per resource.

**Trade-offs:** UUID v7 is a newer spec (RFC 9562, 2024); older ID generation libraries do not support it natively and require an explicit dependency (`google/uuid` v1.6+ or equivalent); the migration from opaque IDs to UUID v7 was a breaking API change for any consumer relying on the old format.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Keep existing opaque ID, add a UUID v4 field | Introduces dual-identifier ambiguity for every API caller; Adapters and HyperShift integration would need to know which field to use in which context; rejected by team vote |
| UUID v4 (random) | Structurally accepted by HyperShift but provides no ordering benefit; no meaningful improvement over the status quo beyond RFC 4122 compliance |
| ULID (Universally Unique Lexicographically Sortable Identifier) | Time-ordered and sortable but not RFC 4122 compliant; incompatible with HyperShift's UUID requirement |
| Sequential integer IDs | Simple but reveals resource count to callers; not globally unique across environments; incompatible with distributed ID generation in multi-replica API deployments |
