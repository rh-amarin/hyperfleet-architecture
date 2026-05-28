---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Resource Lifecycle

> Go-specific code review standard for resource cleanup, context propagation, and timer management. Applies to all diffs containing `.go` files.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Leaked resources — unclosed files, unreleased connections, orphaned contexts — accumulate silently until they cause production incidents (file descriptor exhaustion, connection pool starvation, memory growth). This standard defines the mechanical checks reviewers apply to every resource creation site in a diff.

### Risk: Bug

Violations are resource leaks. A leaked database connection starves the pool; an uncancelled context holds memory until the parent is cancelled (which may be never).

---

## Standard

### RES-01: Resource cleanup on all paths

Every resource created in a diff (files, connections, contexts with cancel, HTTP response bodies, exporters, tracer providers, database transactions) MUST be cleaned up on ALL code paths, including early `return` and error branches.

Cleanup SHOULD use `defer` immediately after successful creation. Exceptions: inside loops (see [PERF-04](performance.md#perf-04-defer-in-tight-loops) — extract to a function instead), when LIFO ordering of `defer` would cause incorrect cleanup sequence, or when cleanup is conditional on success (e.g., don't delete a temp file that was successfully renamed).

- `defer file.Close()`
- `defer cancel()` (for `context.WithCancel` / `context.WithTimeout`)
- `defer resp.Body.Close()` (for HTTP response bodies)
- `defer tx.Rollback()` (for database transactions — no-op after commit)
- `defer exporter.Shutdown(ctx)` (for OpenTelemetry exporters)

Reviewers MUST trace all code paths from creation to function exit and flag any path where cleanup is skipped.

### RES-02: Context propagation

Every function that receives a `context.Context` parameter SHOULD propagate it to downstream calls. Using `context.Background()` or `context.TODO()` when a parent context is available SHOULD be flagged.

Exceptions:

- Startup initialization code where no parent context exists yet.
- Background workers that intentionally outlive the request context (MUST document why).
- `context.TODO()` with a tracking ticket reference is acceptable as temporary tech debt.

### RES-03: `time.After` in loops

`time.After` inside a `for` loop or inside a `select` within a loop MUST be flagged as a memory leak. Each iteration allocates a timer that is not garbage collected until it fires.

Use `time.NewTimer` with `Reset()` instead.

---

## Examples

### Resource cleanup with defer

```go
// ✅ Good — defer immediately after creation
f, err := os.Open(path)
if err != nil {
    return fmt.Errorf("open %s: %w", path, err)
}
defer f.Close()

// ❌ Bad — cleanup skipped on early return
f, err := os.Open(path)
if err != nil {
    return err
}
data, err := io.ReadAll(f)
if err != nil {
    return err // BUG: f is never closed on this path
}
f.Close()
```

### Context propagation

```go
// ✅ Good — parent context propagated
func Handler(ctx context.Context) error {
    return doWork(ctx) // downstream respects cancellation
}

// ❌ Bad — parent context discarded
func Handler(ctx context.Context) error {
    return doWork(context.Background()) // cancellation signal lost
}
```

### Timer in loops

```go
// ✅ Good — timer reused, properly stopped before reset
timer := time.NewTimer(timeout)
defer timer.Stop()
for {
    select {
    case msg := <-ch:
        if !timer.Stop() {
            <-timer.C // drain channel before reset
        }
        timer.Reset(timeout)
        process(msg)
    case <-timer.C:
        return errTimeout
    }
}

// ❌ Bad — time.After allocates a new timer every iteration
for {
    select {
    case msg := <-ch:
        process(msg)
    case <-time.After(timeout): // LEAK: timer GC'd only when it fires
        return errTimeout
    }
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `govet` catches some context misuse. `bodyclose` is available but not currently enabled in golangci-lint. Most resource lifecycle issues require path-sensitive analysis that static tools miss — review is the primary enforcement.

---

## References

### Related HyperFleet Standards

- [Graceful Shutdown Standard](../graceful-shutdown.md) — resource cleanup during process termination
- [Linting Standard](../linting.md) — `bodyclose` and related linters
- [Concurrency](concurrency.md) — goroutine lifecycle (related concern)

### External Resources

- [Effective Go — Defer](https://golang.org/doc/effective_go#defer)
- [Go Blog — Context](https://go.dev/blog/context)
