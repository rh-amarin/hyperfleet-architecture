---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Performance

> Go-specific code review standard for allocation patterns, preallocation, and performance anti-patterns. Applies to all diffs containing `.go` files.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Unnecessary allocations in hot paths and N+1 query patterns are the most common performance issues caught during review. This standard defines the mechanical checks reviewers apply to allocation-heavy and I/O-heavy code.

### Risk: Debt

Violations produce working code but waste resources. Preallocation and batch queries are easy wins; missing them in hot paths causes latency spikes under load.

---

## Standard

### PERF-01: Slice and map preallocation

When the final size of a slice or map is known or estimable (e.g., `len(input)`), the allocation SHOULD include a capacity hint:

- `make([]T, 0, expectedLen)` instead of `var s []T` or `make([]T, 0)`.
- `make(map[K]V, expectedLen)` instead of `make(map[K]V)`.

Exceptions:

- Small, fixed-size collections (e.g., `[]string{"a", "b"}`).
- One-time initialization code (e.g., in `main()` or `init()`).

### PERF-02: String concatenation in loops

String concatenation with `+=` inside loops SHOULD be flagged. Use `strings.Builder` instead.

### PERF-03: Unnecessary allocations in hot paths

Creating new slices, maps, or structs inside tight loops when they could be allocated once outside the loop and reused or reset SHOULD be flagged.

### PERF-04: Defer in tight loops

`defer` inside `for` loops MUST be flagged. Deferred calls accumulate until the enclosing function returns, not per iteration. This causes memory accumulation proportional to iteration count.

Resolution: extract the loop body into a separate function or call cleanup explicitly per iteration.

Exceptions:

- `defer` in loops with a statically known iteration count of 3 or fewer items.
- `defer` in a loop that unconditionally executes exactly one iteration and returns immediately.

These exceptions do NOT apply when the iteration count depends on input or runtime state, even if it "usually" has one iteration.

### PERF-05: N+1 query patterns

Code that iterates over a collection and makes individual database/API calls per item SHOULD use a batch operation instead (e.g., `WHERE IN` clause instead of per-item `SELECT`).

---

## Examples

### Slice preallocation

```go
// ✅ Good — preallocated with known capacity
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, transform(item))
}

// ❌ Bad — slice grows through multiple reallocations
var results []Result
for _, item := range items {
    results = append(results, transform(item))
}
```

### String builder

```go
// ✅ Good — strings.Builder avoids O(n²) allocation
var b strings.Builder
for _, name := range names {
    b.WriteString(name)
    b.WriteString(", ")
}
result := b.String()

// ❌ Bad — O(n²) string allocation in loop
var result string
for _, name := range names {
    result += name + ", " // new string allocated every iteration
}
```

### Defer in loops

```go
// ✅ Good — cleanup per iteration via extracted function
for _, path := range paths {
    if err := processFile(path); err != nil {
        return err
    }
}

func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close() // defer scoped to this function, not the loop
    return parse(f)
}

// ❌ Bad — defers accumulate until outer function returns
for _, path := range paths {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close() // BUG: all defers run when the enclosing function exits
    parse(f)
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `prealloc` is available but not currently enabled in golangci-lint — review is the primary enforcement for PERF-01. N+1 detection requires semantic understanding that static analysis cannot provide — review is essential.

---

## References

### Related HyperFleet Standards

- [Linting Standard](../linting.md) — `prealloc`, `ineffassign` linters

### External Resources

- [Effective Go — Allocation](https://golang.org/doc/effective_go#allocation_new)
- [Go Performance Tips](https://github.com/dgryski/go-perfbook)
