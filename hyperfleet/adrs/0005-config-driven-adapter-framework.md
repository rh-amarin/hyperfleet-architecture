---
Status: Active
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-15
---

# 0005 — Config-Driven Adapter Framework (Single Binary, Multiple Deployments)

## Context

HyperFleet requires multiple distinct provisioning Adapters (GCP validation, DNS placement, landing zone, HyperShift cluster creation, nodepool management). Each Adapter performs a different task but follows the same execution lifecycle: receive a CloudEvent, extract parameters, evaluate preconditions, apply Kubernetes or Maestro resources, and report status back to the HyperFleet API. Without a shared framework, each Adapter would duplicate the event handling, retry, observability, and status-reporting scaffolding. HYPERFLEET-45 drove the design.

## Decision

**`hyperfleet-adapter`** is a single Go binary that implements the full four-phase execution pipeline in code. All business logic for a specific provisioning task is declared in a **flat YAML configuration file** (`AdapterTaskConfig`) — no custom Go code is needed per adapter deployment. The same binary is deployed multiple times with different ConfigMaps

The concrete adapters will be developed by provider teams (GCP, ROSA)

The four phases are:

| Phase | Description |
|-------|-------------|
| **Param** | Extracts named parameters from env vars, CloudEvent payload, and live Kubernetes resource status via the HyperFleet API |
| **Pre-conditions** | Evaluates CEL preconditions; outcomes are `proceed`, `wait/retry`, or `fail` |
| **Resource** | Applies, discovers, or deletes Kubernetes resources (`k8sclient`) or OCM ManifestWork objects (`maestroclient`) via a unified `TransportClient` interface |
| **Post/Status** | Builds a structured status payload using CEL expressions against discovered resource state and POSTs it to the HyperFleet API |

## Consequences

**Gains:** Adapter authors write only YAML — no Go compilation or container build required per new provisioning task; the framework binary has a single build pipeline and test suite; dry-run mode allows full pipeline simulation without real infrastructure; the `TransportClient` abstraction means YAML configs are portable between direct Kubernetes and OCM/Maestro targets.

**Trade-offs:** All adapter logic must fit within the CEL + four-phase execution model; highly unusual workflows (e.g., multi-step human-approval gates) cannot be expressed in the current YAML schema without framework changes; breaking changes to the config schema (e.g., the flat YAML migration in v0.2.0) require coordinated updates to every deployed ConfigMap.

The DSL for adapters is restricted to fixed phases to keep complexity low.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| One repository per Adapter (separate Go binaries) | Duplicates ~80% of event handling, retry, observability, and status-reporting code; separate release cycles for identical infrastructure increase maintenance burden |
| Callback-based Go plugin system | Requires adapter authors to write Go and recompile the binary per task; eliminates the low-code operator onboarding goal |
| Lua or JavaScript scripting engine embedded in the binary | Security sandbox is harder to reason about than CEL; no first-class Kubernetes/Maestro resource type support |
| Argo Workflows / Tekton | Adds an external dependency and operator install requirement; workflow definitions live outside the HyperFleet config standard |
