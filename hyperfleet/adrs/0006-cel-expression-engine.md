---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0006 — CEL as the Shared Expression Evaluation Engine

## Context

Both Sentinel and the Adapter framework require configurable expression evaluation: Sentinel needs operator-defined reconciliation trigger logic (e.g., "trigger if generation mismatch and cluster not ready for > 10 s"), and the Adapter needs preconditions, parameter extraction, status payload construction, and post-action skip conditions — all expressed by the person writing the YAML config rather than a Go developer. The expression engine must be sandboxed (no arbitrary code execution), compilable at startup for fail-fast validation, and extensible with HyperFleet-specific functions.

## Decision

**Google CEL (Common Expression Language)** (`github.com/google/cel-go`) is the expression evaluation engine used in both Sentinel and the Adapter. CEL programs are compiled once at startup; a compilation error fails the service before it enters its reconciliation loop. Custom functions registered in both components:

| Function | Available in | Purpose |
|----------|-------------|---------|
| `now()` | Adapter | Returns current time as RFC 3339 string for time-based preconditions |
| `toJson(v)` | Adapter | Serializes a CEL value to a JSON string |
| `dig(map, key)` | Adapter | Traverses nested maps safely (equivalent to `?.orValue()` chaining) |

In Sentinel, intermediate parameters are evaluated in **topological dependency order** (Kahn's algorithm); circular dependencies are detected at startup and cause a fatal error.

## Consequences

**Gains:** CEL is type-safe and sandboxed — arbitrary code execution is not possible; compilation at startup means invalid expressions are caught before any CloudEvent is processed; the same engine in Sentinel and Adapter reduces the cognitive load for operators writing both Sentinel trigger conditions and Adapter preconditions; CEL is maintained by Google and is the expression language of Kubernetes admission webhooks (familiar to the team's audience).

**Trade-offs:** CEL is not Turing-complete; complex multi-step control flow must be modelled as separate phases rather than a single expression; debugging CEL errors in production requires inspecting structured logs rather than using a REPL; operators unfamiliar with CEL must learn its type system and `?.orValue()` optional chaining idioms.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| `expr-lang/expr` | Evaluated during the HYPERFLEET-45 spike; CEL was preferred for its Red Hat / Kubernetes ecosystem alignment and stronger type system |
| `casbin` / `govaluate` | Policy-focused; `govaluate` is no longer actively maintained; neither provides first-class proto/struct field access needed for Kubernetes condition evaluation |
| `hyperjumptech/grule-rule-engine` | Rule engine semantics add unnecessary complexity for what are essentially boolean precondition expressions |
| OPA / Rego | Excellent for policy, but OPA is typically run as a separate server; embedding it adds ~30 MB to the binary and complicates startup validation |
| Go `text/template` | Turing-complete but not sandboxed; no type safety; error messages at evaluation time are hard to surface cleanly in structured logs |
