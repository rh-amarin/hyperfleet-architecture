---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0010 — JSONB for Provider-Agnostic Cluster and NodePool Spec Storage

## Context

HyperFleet is designed to manage clusters across multiple cloud providers (GCP, AWS, Azure) and cluster types (HyperShift, standard OCP). Each provider requires a different set of fields in the cluster and nodepool `spec` (e.g., GCP requires `projectId`, `region`, `networkConfig`; AWS requires `accountId`, `vpcId`, `availabilityZones`). A normalized relational schema would require a separate table — or at minimum a migration — for every new provider field. HYPERFLEET-18 and HYPERFLEET-20 established the multi-cloud requirement at the design stage.

## Decision

The `spec`, `status.conditions` (JSONB array), and `data` fields on Cluster and NodePool are stored as **PostgreSQL JSONB**. Runtime schema validation is performed in an HTTP middleware layer: the request `spec` is validated against the embedded OpenAPI schema on every `POST`/`PATCH` request before reaching the service layer, so the database never stores an invalid spec. A **GIN index** on the `conditions` JSONB column enables fast condition-subfield queries used by Sentinel (e.g., `status.conditions.Ready.observed_generation`).

## Consequences

**Gains:** Adding a new cloud provider or new spec fields requires no database schema migration; the GIN index on conditions provides O(log n) lookups for Sentinel's generation-mismatch queries without scanning the full JSONB document; JSONB preserves the full JSON structure, enabling CEL expressions in Adapters to traverse arbitrary nested fields via `dig()`.

**Trade-offs:** The database cannot enforce spec field constraints (required fields, value ranges) — this is entirely the application's responsibility via the OpenAPI validation middleware; JSONB fields are opaque to most database monitoring and analytics tools; querying deeply nested spec fields in ad-hoc SQL requires PostgreSQL JSONB path operators (`->>`, `#>>`), which are less readable than standard column queries.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Separate table per provider (e.g., `gcp_cluster_specs`, `aws_cluster_specs`) | Combinatorial explosion with `provider × resource_type` combinations; every new provider requires a schema migration and new handler code |
| Single normalized spec table with provider-typed columns | Sparse columns for each provider; most columns are NULL for any given row; schema migration required for every new provider field |
| Single `spec TEXT` column (raw JSON string) | Simpler than JSONB but no GIN indexing, no operator support (`@>`, `?`), and slower for condition queries that Sentinel relies on |
| External document store (MongoDB, CouchDB) | Adds an operational dependency beyond PostgreSQL; the rest of the data model is relational; two storage systems for one service increases operational complexity |
