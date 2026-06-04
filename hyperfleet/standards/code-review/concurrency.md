---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-29
---

# Code Review: Concurrency

> Go-specific code review standard for concurrency safety, goroutine lifecycle management, and loop variable capture. Applies to all diffs containing `.go` files.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Data races and goroutine leaks are among the hardest bugs to reproduce and debug. This standard defines the mechanical checks reviewers apply to every concurrency-related construct in a diff.

### Risk: Bug

Violations are race conditions or resource leaks. A data race can cause memory corruption; a leaked goroutine consumes resources indefinitely.

---

## Standard

### CONC-01: Concurrency safety

Every variable captured by a goroutine or closure MUST have proper synchronization (mutex, atomic, channel). This includes variables accessed from HTTP handlers, which run in separate goroutines.

Reviewers MUST flag unprotected shared reads/writes, including:

- Map access from multiple goroutines (concurrent map read/write is a runtime panic in Go).
- Struct fields modified without a lock when the struct is shared.
- Package-level variables mutated after `init()` without synchronization.

### CONC-02: Goroutine lifecycle

Every goroutine started in a diff SHOULD have a clear shutdown mechanism: context cancellation, done channel, or `sync.WaitGroup`. Fire-and-forget goroutines with no way to stop them SHOULD be flagged.

Exception: goroutines that perform bounded work and terminate naturally (one-shot operations, background metric flush with a fixed iteration) do not need an explicit shutdown mechanism.

Reviewers SHOULD verify:

- The goroutine respects context cancellation (checks `ctx.Done()`).
- `sync.WaitGroup` `Add()` is called before the goroutine starts, not inside it.
- The parent function waits for goroutine completion when appropriate.

### CONC-03: Loop variable capture

**Go 1.22+ projects:** This check does not apply. Go 1.22 introduced per-iteration loop variable scoping, which eliminates this class of bug. Reviewers MUST check the project's `go.mod` minimum Go version before flagging.

**Pre-Go 1.22 projects:** Every `for` loop that launches a goroutine (`go func()`) or creates a closure MUST either pass the loop variable as a function argument or rebind it with a local copy.

### Exceptions

Reviewers MUST NOT flag:

- Single-goroutine programs or `main()` functions with no concurrency.
- Test helpers that are only called from a single test goroutine.
- Package-level variables that are set once during `init()` and never mutated afterward (effectively immutable).
- Mutex-protected code where the lock is acquired in a wrapper function (trace the call chain before flagging).

---

## Examples

### Shared state protection

```go
// ✅ Good — protected with sync.RWMutex
type Cache struct {
    mu    sync.RWMutex
    items map[string]interface{}
}

func (c *Cache) Get(key string) interface{} {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.items[key]
}

// ❌ Bad — unprotected concurrent map access
var cache = make(map[string]interface{})

func Get(key string) interface{} {
    return cache[key] // RACE — concurrent map read/write is a runtime panic
}
```

### Goroutine lifecycle

```go
// ✅ Good — goroutine receives work via channel and respects cancellation
func Process(ctx context.Context, workCh <-chan Job) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            case job, ok := <-workCh:
                if !ok {
                    return // channel closed
                }
                handle(job)
            }
        }
    }()
}

// ❌ Bad — goroutine runs forever, no shutdown mechanism
func Process() {
    go func() {
        for {
            work() // leaked goroutine — runs until process exits
        }
    }()
}
```

### Loop variable capture (pre-Go 1.22)

```go
// ✅ Good — loop variable shadowed
for _, item := range items {
    item := item // shadow the loop variable
    go func() {
        process(item)
    }()
}

// ❌ Bad — all goroutines see the last value of item
for _, item := range items {
    go func() {
        process(item) // BUG: item is the loop variable, not a copy
    }()
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `go vet` and the `-race` flag detect some data races at test time. The [Linting Standard](../linting.md) includes `govet` via golangci-lint. However, static analysis cannot catch all concurrency bugs — review is essential.

---

## References

### Related HyperFleet Standards

- [Linting Standard](../linting.md) — `govet` catches some concurrency issues
- [Resource Lifecycle](resource-lifecycle.md) — context propagation rules (related concern)

### External Resources

- [Go Blog — Share Memory By Communicating](https://go.dev/blog/codelab-share)
- [Go Data Race Detector](https://go.dev/doc/articles/race_detector)
- [Go Blog — Fixing For Loops in Go 1.22](https://go.dev/blog/loopvar-preview)
