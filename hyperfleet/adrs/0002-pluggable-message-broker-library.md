---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0002 — Pluggable Message Broker via hyperfleet-broker Library

## Context

HyperFleet must run in at least two environments: a local development environment where cloud services may be unavailable (developers use RabbitMQ) and production environments on GCP (uses Pub/Sub) or AWS. Sentinel and every Adapter need a message broker, but importing RabbitMQ or GCP Pub/Sub SDKs directly in each component would tie every service to a concrete broker and make environment switching a multi-repository change.

## Decision

All broker access goes through **`hyperfleet-broker`**, a dedicated Go library that exposes a `Publisher` / `Subscriber` interface. Three concrete implementations ship in the library:

- **Stub** — in-memory, zero-dependency, used in unit tests
- **RabbitMQ** — AMQP via `rabbitmq/amqp091-go` + `ThreeDotsLabs/watermill-amqp`, topic exchange, configurable exchange type (default `topic`)
- **GCP Pub/Sub** — `cloud.google.com/go/pubsub/v2` + `ThreeDotsLabs/watermill-googlecloud`

The active implementation is selected at startup via the broker configuration YAML (`BROKER_CONFIG_FILE`). No component repository imports a broker SDK directly; this is a hard constraint enforced by project guidelines.

## Consequences

**Gains:** Swapping broker backends requires only a config change, no code changes in Sentinel or any Adapter; the stub implementation makes unit tests deterministic and fast; a single `MetricsRecorder` in the library provides consistent broker-level Prometheus metrics across all components; the watermill abstraction layer adds built-in retry and middleware support.

**Trade-offs:** The stub implementation may diverge from real broker semantics (ordering guarantees, redelivery behavior) and mask bugs that only surface on real brokers; all components are coupled to the `hyperfleet-broker` release cycle; adding a new broker backend requires a library release before it can be used by any component.

The additional config file for the broker is some added complexity for deployments.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| RabbitMQ only (no abstraction) | GCP Pub/Sub is the production target; locking to RabbitMQ would require rework before production deployment |
| Apache Kafka | Higher operational overhead for the team's current scale; Kafka's partition model is not needed given the per-resource CloudEvent rate |
| Direct GCP Pub/Sub with local emulator | The Pub/Sub emulator has feature gaps; local developers would need gcloud tooling installed, increasing onboarding friction |
| NATS | Not part of the Red Hat / OpenShift supported technology stack at the time of the decision |
| libraries in components | Component code/config become aware of the concrete broker implementation |
