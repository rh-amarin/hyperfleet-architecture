---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Code Quality

> Go-specific code review standard for constants, struct initialization completeness, and function complexity. Applies to all diffs containing `.go` files.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Magic values, incomplete struct initialization, and overly complex functions reduce maintainability and hide bugs. This standard defines the mechanical checks reviewers apply to code structure and organization.

### Risk: Debt

Violations produce working code but degrade readability, maintainability, or debuggability. Magic values make behavior harder to trace; incomplete struct initialization silently produces zero values that may not be correct.

---

## Standard

### QUAL-01: Constants and magic values

Package-level `var` declarations whose values never change SHOULD be `const`.

Inline literal strings used as fixed identifiers, config keys, filter expressions, or semantic values SHOULD be named constants. Magic numbers used as thresholds, sizes, or multipliers SHOULD be named constants.

If the [Linting Standard](../linting.md) configuration defines naming or configuration conventions for constants, those conventions apply.

Exceptions:

- Test files where inline values improve readability.
- Zero values (`0`, `""`, `nil`) used as defaults.

### QUAL-02: Struct field initialization completeness

When new fields are added to a struct, every constructor and factory function (`NewFoo()`, `newFoo()`) that creates instances of that struct SHOULD initialize the new field. Reviewers SHOULD flag constructors that produce a zero value for the new field when a meaningful default is expected.

### QUAL-03: Function complexity

Functions longer than 60 lines or with more than 4 levels of nesting SHOULD be reviewed for simplification:

- **Guard clauses** — deep nesting from `if err != nil` or validation checks SHOULD use early returns instead.
- **Function length** — functions over 60 lines SHOULD be decomposed into smaller, well-named helpers.
- **Cyclomatic complexity** — functions with more than 5 branching paths (if/else, switch cases, loops) SHOULD be flagged for decomposition.

Exceptions:

- Table-driven test functions that are long but structurally simple.
- Generated code.
- Functions that are inherently sequential (e.g., multi-step initialization) where splitting would reduce readability.

---

## Examples

### Constants vs magic values

```go
// ✅ Good — named constants with clear meaning
const (
    maxRetries     = 3
    defaultTimeout = 30 * time.Second
    clusterSubset  = "clusters"
)

// ❌ Bad — magic values scattered in code
if retries > 3 {                        // what does 3 mean?
    return fmt.Errorf("timeout after %v", 30*time.Second)
}
broker.Subscribe(ctx, "clusters")        // string literal as identifier
```

### Struct initialization completeness

```go
type Config struct {
    Host    string
    Port    int
    Timeout time.Duration // NEW FIELD
}

// ✅ Good — new field initialized
func NewConfig(host string, port int) *Config {
    return &Config{
        Host:    host,
        Port:    port,
        Timeout: 30 * time.Second, // explicit default for new field
    }
}

// ❌ Bad — new field is zero value (0s timeout = no timeout)
func NewConfig(host string, port int) *Config {
    return &Config{
        Host: host,
        Port: port,
        // BUG: Timeout is 0s — likely not intended
    }
}
```

### Guard clauses vs nesting

```go
// ✅ Good — early returns reduce nesting
func process(cluster *Cluster) error {
    if cluster == nil {
        return errNilCluster
    }
    if cluster.Status != StatusActive {
        return fmt.Errorf("cluster %s not active", cluster.ID)
    }
    return reconcile(cluster)
}

// ❌ Bad — unnecessary nesting
func process(cluster *Cluster) error {
    if cluster != nil {
        if cluster.Status == StatusActive {
            return reconcile(cluster)
        } else {
            return fmt.Errorf("cluster %s not active", cluster.ID)
        }
    } else {
        return errNilCluster
    }
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `goconst` (magic values) and `govet` (struct alignment) are enabled in golangci-lint. Complexity linters (`gocognit`/`gocyclo`) are available but not currently enabled — review is the primary enforcement for QUAL-03. See the [Linting Standard](../linting.md) for the enabled set.

---

## References

### Related HyperFleet Standards

- [Linting Standard](../linting.md) — `goconst`, complexity linters
- [Naming](naming.md) — naming conventions (complementary concern)
- [Configuration Standard](../configuration.md) — config value naming conventions

### External Resources

- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Effective Go](https://golang.org/doc/effective_go)
