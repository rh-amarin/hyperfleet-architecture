---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-16
---

# 0011 — Testcontainers for Integration Tests

## Context

HyperFleet components (API, Sentinel, Adapter) each have layers that require real infrastructure to test meaningfully: the API service relies on PostgreSQL for its DAO and service layers; Sentinel integrates with a message broker (RabbitMQ) for event publishing; the Adapter exercises a Kubernetes control plane through envtest. Unit tests with mocks cover internal logic but cannot catch schema mismatches, query correctness, broker protocol behaviour, or Kubernetes admission behaviour.

The team needed a strategy to run real-infrastructure tests without requiring developers to maintain a local database or broker, and without relying on shared external services in CI.

## Decision

All HyperFleet components use **testcontainers-go** to spin up real infrastructure containers during integration test runs. Each component provisions only the infrastructure it owns:

| Component | Container | Image |
|-----------|-----------|-------|
| hyperfleet-api | PostgreSQL | `postgres:14.2` |
| hyperfleet-sentinel | RabbitMQ | `rabbitmq:3.13-management-alpine` |
| hyperfleet-adapter | Kubernetes envtest | custom (`INTEGRATION_ENVTEST_IMAGE`) |

Containers start in-process via the Docker/Podman daemon — no `docker-compose` file, no external orchestration. Each component applies its own lifecycle pattern suited to the cost of starting that container:

- **hyperfleet-api**: A single `TestcontainerFactory` is created once per test binary run and shared across all integration tests. Database migrations run automatically on startup. The factory implements the same `SessionFactory` interface used in production, so no test-specific seams exist in application code.
- **hyperfleet-sentinel**: A singleton RabbitMQ container is created in `TestMain` via `sync.Once` and shared across all tests in the package.
- **hyperfleet-adapter**: Expensive containers (envtest K8s API server) are shared via `StartSharedContainer` in `TestMain`; cheap or isolated containers use `StartContainer(t)` with automatic `t.Cleanup()` teardown.

Integration tests are isolated from unit tests:
- hyperfleet-api and hyperfleet-adapter separate them by directory (`test/integration/`) and a dedicated Makefile target.
- hyperfleet-sentinel additionally gates them behind a `//go:build integration` build tag.

All components set `TESTCONTAINERS_RYUK_DISABLED=true` in CI to avoid Ryuk compatibility issues with Podman (documented in HYPERFLEET-625). Teardown imposes a 30-second hard timeout and falls back to direct `docker`/`podman` CLI invocation to prevent CI runners from hanging.

## Consequences

**Gains:** Integration tests exercise the full stack down to real infrastructure with no mocks in the infrastructure layer; schema evolution, query correctness, broker protocol handling, and Kubernetes admission behaviour are all caught before merge; containers start and stop in-process, so no shared state between CI jobs and no external service to manage; the `SessionFactory` abstraction means testcontainer setup is invisible to application code.

**Trade-offs:** Integration test runs are slower than unit tests and require a local Docker or Podman daemon — developers without a daemon cannot run integration tests locally; testcontainers-go versions differ across components (API on v0.33.0, Sentinel and Adapter on v0.40.0), which may cause subtle behavioural differences and complicates shared upgrade efforts; the Ryuk resource reaper must be disabled in Podman environments, meaning leaked containers from aborted test runs require manual cleanup.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| `docker-compose` for test infrastructure | Requires external process management and a running compose stack before tests start; harder to integrate with `go test` lifecycle and parallel CI jobs |
| SQL mocks (`go-sqlmock`) and broker mocks for all tests | Already used at the unit level; cannot catch schema mismatches, real query planner behaviour, broker protocol errors, or Kubernetes admission webhook logic |
| Shared staging environment | Creates shared state between developers and CI runs; flaky when concurrently mutated; requires network access and credentials in local environments |
| In-memory SQLite for database tests | Schema and query incompatibilities with PostgreSQL-specific features (JSONB, advisory locks, `FOR UPDATE SKIP LOCKED`) make it unsuitable for HyperFleet's data model |
