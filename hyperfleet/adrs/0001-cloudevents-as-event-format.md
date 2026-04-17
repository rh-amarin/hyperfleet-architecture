---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0001 — CloudEvents as the Inter-Component Event Format

## Context

HyperFleet requires a standard event format to carry reconciliation signals from Sentinel to Adapters via the message broker. Without a shared contract, each component would need to negotiate payload shape independently, making it impossible to swap broker implementations or add new Adapters without coordinating schema changes across every consumer.

## Decision

All events published by Sentinel and consumed by Adapters conform to the **CloudEvents v1.0 specification** (`github.com/cloudevents/sdk-go/v2`). Event type follows the format `com.redhat.hyperfleet.<kind>.reconcile.<version>` (e.g., `com.redhat.hyperfleet.clusters.reconcile.v1`). Event IDs use **UUID v7** (time-ordered) to enable natural ordering and correlation. Distributed tracing context is propagated via the W3C `traceparent` CloudEvents extension attribute so that a single reconciliation cycle produces one connected trace across Sentinel, Broker, and Adapter.

As additional info, CloudEvents is also the format used by Maestro.

## Consequences

**Gains:** Vendor-neutral event schema decouples producers from consumers; any broker that carries CloudEvents (RabbitMQ, GCP Pub/Sub, Kafka) requires no payload changes; W3C `traceparent` propagation provides end-to-end distributed traces at zero protocol overhead; time-ordered UUID v7 event IDs allow replay and deduplication logic without secondary timestamps.

**Trade-offs:** All components must depend on the CloudEvents SDK; teams must learn CloudEvents attribute conventions; the `specversion` field introduces one extra protocol-level hop when compared to a raw JSON payload.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Custom JSON payloads per event type | No standard schema → each Adapter had to negotiate payload shape with Sentinel; adding a new Adapter required bilateral changes |
| AsyncAPI-described payloads without CloudEvents wrapper | Provides documentation contract but no runtime envelope; tracing context would require a custom extension field, duplicating what CloudEvents already provides |
| gRPC streaming | Requires a persistent gRPC channel; incompatible with the broker-mediated, at-least-once delivery model chosen for Sentinel → Adapter communication |
