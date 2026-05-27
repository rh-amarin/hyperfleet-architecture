---
Status: Active
Owner: HyperFleet Adapter Team
Last Updated: 2026-05-25
---

# 0017 — Selective Message Acknowledgment in Adapters

## Context

The HyperFleet adapter framework processes CloudEvents from a message broker and interacts with multiple external systems: the HyperFleet API (HTTP), Kubernetes API, cloud provider APIs, and the broker itself. Failures occur at each of these boundaries.

The current strategy acknowledges (ACKs) every message regardless of processing outcome:

- Configuration errors fail fast at startup
- Broker connection errors retry with exponential backoff
- API/K8s errors are logged and processing continues
- **All processed events are acknowledged regardless of outcome**

This "always ACK" approach conflates errors that will resolve on retry (transient) with errors that will never succeed no matter how many times the event is reprocessed (terminal). A malformed event is reprocessed on every Sentinel reconciliation cycle — consuming adapter capacity indefinitely — while a transient API timeout waits up to 30 minutes for the next reconciliation instead of retrying immediately via the broker.

## Decision

Move from **always ACK** to **selective ACK/NACK based on error classification**.

Every error during event processing is classified into exactly one of two categories:

| Category | Adapter Behavior | Broker Behavior |
|----------|-----------------|-----------------|
| **Transient** | Return `error` to broker library | NACK — redelivers the message with backoff |
| **Terminal** | Report error status to API, log at `error` level, return `nil` | ACK — message is not redelivered |

Messages that exhaust the broker's max delivery attempts are routed to a Dead Letter Queue (DLQ) via the broker's native DLQ mechanism. DLQ configuration is provider-specific and outside the scope of this decision.

The full error mapping tables, DLQ configuration, observability requirements, and implementation details are in the [Adapter Error Handling Guide](../components/adapter/framework/adapter-error-handling.md).

## Consequences

### Gains

- **Unprocessable message protection**: Terminal errors are immediately ACK'd, preventing a single bad event from blocking the adapter indefinitely
- **Faster recovery**: Transient errors are retried via the broker in seconds, instead of waiting up to 30 minutes for Sentinel's next reconciliation cycle
- **Actionable alerting**: Operators can distinguish between "system is retrying" (normal) and "system gave up" (needs attention)
- **DLQ as safety net**: Messages that exhaust retries are preserved for inspection and replay, not silently dropped

### Trade-offs

- **Complexity**: Error classification adds decision logic to every error path in the adapter framework
- **Ambiguous errors**: Some errors are hard to classify (e.g., HTTP 404 on a resource that might be created soon). Conservative defaults may need tuning
- **Dual retry path**: Sentinel's reconciliation loop already retries failed events. Broker-level retry adds faster recovery but operators must understand both mechanisms
- **DLQ infrastructure**: Must be provisioned and monitored per environment

### Acceptable Because

- The broker library's `HandlerFunc` contract already supports this — returning `error` vs `nil` is the only change
- Broker-native DLQ is supported by both Pub/Sub and RabbitMQ with no application-level infrastructure
- The default classification for unknown errors is Terminal (ACK), preserving the current "always ACK" behavior for unclassified errors

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| **Always ACK, rely solely on Sentinel reconciliation for retry** | Current behavior. Sentinel's interval for healthy clusters is 30 minutes — transient errors (e.g., 30-second API timeout) unnecessarily delay recovery |
| **Always NACK on any error** | Unprocessable events (malformed payload) would be redelivered indefinitely, consuming adapter capacity until hitting max delivery attempts |
| **Application-level DLQ (adapter writes to a separate topic/DB)** | Adds infrastructure and code complexity. Broker-native DLQ is simpler and already supported |
| **Circuit breaker per downstream dependency** | Orthogonal to error classification. Can be added as a post-MVP enhancement on top of this model |

## References

- [Adapter Error Handling Guide](../components/adapter/framework/adapter-error-handling.md) — Full error mapping tables, DLQ configuration, and observability
- [Adapter Framework Design — Error Handling Strategy](../components/adapter/framework/adapter-frame-design.md#error-handling-strategy)
- [Adapter Status Contract — Pattern 6: Adapter Error](../components/adapter/framework/adapter-status-contract.md#pattern-6-adapter-error)
- [HyperFleet Error Model and Codes Standard](../standards/error-model.md)
- [ADR-0005 — Config-Driven Adapter Framework](0005-config-driven-adapter-framework.md)
