---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Naming

> Go-specific code review standard for identifier naming conventions. Applies to all diffs containing `.go` files. Function complexity checks are in [Code Quality](code-quality.md).

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Inconsistent naming creates cognitive overhead and makes code harder to navigate. This standard defines the mechanical naming checks reviewers apply to new or renamed identifiers, based on Go community conventions.

### Risk: Style

Violations produce working code but reduce readability and consistency. Naming issues rarely cause bugs but consistently slow down reviewers and onboarding.

---

## Standard

### NAME-01: Stuttering

Exported identifiers SHOULD NOT repeat the package name. Go uses the package name as a qualifier at call sites, so repetition creates stutter.

- `user.UserService` → `user.Service`
- `user.UserID` → `user.ID`
- `cluster.ClusterStatus` → `cluster.Status`

### NAME-02: Acronym casing

Acronyms in identifiers SHOULD use consistent casing per Go convention — all caps for common acronyms:

- `Id` → `ID`
- `Url` → `URL`
- `Http` → `HTTP`
- `Api` → `API`
- `Json` → `JSON`
- `Sql` → `SQL`

### NAME-03: Getter naming

Simple field accessor methods SHOULD NOT use the `Get` prefix. Go convention is `X()` for getters, `SetX()` for setters:

- `GetName()` → `Name()`
- `GetStatus()` → `Status()`

### NAME-04: Interface naming

Single-method interfaces SHOULD follow the `-er` suffix convention:

- Interface with method `Read` → `Reader`, not `Readable` or `IReader`
- Interface with method `Write` → `Writer`
- Interface with method `Close` → `Closer`

### Exceptions

Reviewers MUST NOT flag:

- Identifiers required by interfaces from external packages (e.g., `ServeHTTP` from `net/http`).
- Generated code or protobuf definitions.
- Identifiers that would conflict with existing names if renamed.
- HyperFleet project-specific naming conventions defined in other standards (e.g., [Configuration Standard](../configuration.md) for config keys).

---

## Examples

### Stuttering

```go
// ✅ Good — package-qualified name reads well: cluster.Status
package cluster

type Status string

// ❌ Bad — stutter: cluster.ClusterStatus
package cluster

type ClusterStatus string
```

### Acronym casing

```go
// ✅ Good
type HTTPClient struct {
    BaseURL string
    APIKey  string
}

// ❌ Bad
type HttpClient struct {
    BaseUrl string
    ApiKey  string
}
```

### Getter naming

```go
// ✅ Good — Go convention
func (c *Cluster) Name() string { return c.name }

// ❌ Bad — Java-style getter
func (c *Cluster) GetName() string { return c.name }
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `revive` is enabled in golangci-lint and catches some naming issues (stuttering, acronym casing via `var-naming`). `stylecheck` is available but not currently enabled. See the [Linting Standard](../linting.md) for the enabled set.

---

## References

### Related HyperFleet Standards

- [Code Quality](code-quality.md) — function complexity (complementary concern)
- [Linting Standard](../linting.md) — `revive`, `stylecheck` linters
- [Configuration Standard](../configuration.md) — config key naming conventions

### External Resources

- [Effective Go — Names](https://golang.org/doc/effective_go#names)
- [Go Code Review Comments — Initialisms](https://github.com/golang/go/wiki/CodeReviewComments#initialisms)
- [Go Code Review Comments — Getters](https://github.com/golang/go/wiki/CodeReviewComments#getters)
