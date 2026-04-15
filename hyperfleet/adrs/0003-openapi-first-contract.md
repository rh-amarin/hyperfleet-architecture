---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0003 — OpenAPI 3.0 as the System Contract (API-First Development)

## Context

Sentinel and every Adapter consume the HyperFleet REST API. External tooling and future third-party integrations will also depend on it. Without a machine-readable contract reviewed before implementation, API shape tends to drift: field names change across handlers, error responses are inconsistent, and consumers must reverse-engineer the API from source code. HYPERFLEET-18 established that "getting the OpenAPI specification correct from the start is paramount."

## Decision

The **OpenAPI 3.0.3 specification** (`openapi/openapi.yaml`) is the single source of truth for the HyperFleet API. Code is generated from the spec using **`oapi-codegen`**. Key conventions:

- The spec is authored in **TypeSpec** and compiled to OpenAPI 3.0.3; only the compiled OpenAPI file is committed.
- Generated Go stubs (server interfaces, request/response types) are **not committed to git**; developers run `make generate-all` after clone.
- The compiled spec is **embedded in the binary** (`//go:embed`) and served at `/api/hyperfleet/v1/openapi` at runtime.
- All API errors conform to **RFC 9457 Problem Details** (`application/problem+json`) with structured `HYPERFLEET-CAT-NUM` error codes.
- The API is versioned under the `/api/hyperfleet/v1/` prefix; no version negotiation is needed during the MVP lifecycle.

## Consequences

**Gains:** All consumers (Sentinel, Adapters, CLI tools) generate type-safe clients directly from the spec; the embedded spec enables contract testing against the live binary; RFC 9457 error responses are consistent across all endpoints; spec reviews surface API design issues before any handler is written.

**Trade-offs:** Generated code is not in git, so a broken codegen tool blocks all development; the TypeSpec → OpenAPI compilation step adds a tooling dependency; developers unfamiliar with `oapi-codegen` must learn its opinionated code layout before contributing.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| gRPC / Protobuf | REST with JSON is better suited for HTTP-native clients and third-party tooling; the team's operator audience is more familiar with REST; Kubernetes-style API conventions (conditions, labels, pagination) map naturally to REST |
| Hand-crafted Go types (no spec) | Drift between documented API and implementation is inevitable; no auto-generated clients for Sentinel/Adapter; every schema change requires updating multiple files manually |
| openapi-generator-cli | `oapi-codegen` produces leaner, idiomatic Go with fewer dependencies; `openapi-generator-cli` requires a JVM runtime in the developer environment |
| GraphQL | Adds a query language layer that is not needed for the CRUD-heavy cluster lifecycle domain; fewer off-the-shelf Red Hat tooling integrations |
