---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Testing

> Go-specific code review standard for test coverage, test structure patterns, and test isolation. Applies to all diffs containing `.go` files.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Tests that are absent, poorly structured, or leak state create a false sense of safety. This standard defines the mechanical checks reviewers apply to test code and test coverage of new production code.

### Risk: Debt

Violations produce working code but leave it unprotected against regressions. Missing test coverage means bugs are caught in production instead of CI.

---

## Standard

### TEST-01: Test coverage for new code

Every new exported function, method, or significant code path added in a diff SHOULD have a corresponding test in a `_test.go` file. Reviewers SHOULD flag new logic without any test coverage.

Coverage targets:

- Critical business logic paths: MUST be tested.
- Error paths: SHOULD be tested, not just happy paths.
- Edge cases (empty inputs, nil values, boundary conditions): SHOULD be tested.

### TEST-02: Test structure patterns

Reviewers SHOULD check test functions for these patterns:

- **Table-driven tests** — test functions that repeat similar setup/assertion patterns for different inputs SHOULD use table-driven tests with `t.Run()` subtests. Exception: small test files with 1-2 simple test cases where a table adds unnecessary complexity.
- **`t.Helper()`** — test helper functions (called from multiple tests, accepting `*testing.T`) MUST call `t.Helper()`. Without it, test failure line numbers point to the helper, not the caller.
- **`t.Parallel()`** — test functions that are independent (no shared mutable state, no shared resources) SHOULD call `t.Parallel()`. Only flag when the test file already uses `t.Parallel()` in other tests — respect existing convention.
- **Assertion messages** — assertions using `t.Error()` or `t.Fatal()` SHOULD include descriptive messages that help diagnose failures. Bare `t.Error(err)` without context SHOULD be flagged.

Exceptions:

- Tests that intentionally cannot be parallel (shared database, global state).
- Small test files with 1-2 simple test cases.

### TEST-03: Test isolation and cleanup

Tests that create resources MUST clean up after themselves:

- **Global state** — tests that modify global state (e.g., `os.Setenv`, package-level variables) MUST restore it. Use `t.Cleanup()` or `t.Setenv()` (Go 1.17+).
- **Temporary files** — tests that create files SHOULD use `t.TempDir()` (Go 1.15+) or explicit cleanup.
- **Test servers** — `httptest.NewServer` MUST have `defer s.Close()`.
- **Goroutine leaks** — tests that start goroutines MUST ensure they complete before the test ends (via `sync.WaitGroup`, channel synchronization, or context cancellation).

Exceptions:

- Tests already using `t.Cleanup()` or `defer` for resource management.
- Clearly marked integration test files with expected external dependencies.

---

## Examples

### Table-driven tests

```go
// ✅ Good — table-driven with subtests
func TestValidateCluster(t *testing.T) {
    tests := []struct {
        name    string
        input   Cluster
        wantErr bool
    }{
        {name: "valid cluster", input: Cluster{Name: "test"}, wantErr: false},
        {name: "empty name", input: Cluster{Name: ""}, wantErr: true},
        {name: "name too long", input: Cluster{Name: strings.Repeat("x", 256)}, wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.input.Validate()
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### Test helper with t.Helper()

```go
// ✅ Good — t.Helper() makes failure point to caller
func assertNoError(t *testing.T, err error, msg string) {
    t.Helper()
    if err != nil {
        t.Fatalf("%s: unexpected error: %v", msg, err)
    }
}

// ❌ Bad — failure line number points here, not caller
func assertNoError(t *testing.T, err error, msg string) {
    if err != nil {
        t.Fatalf("%s: unexpected error: %v", msg, err)
    }
}
```

### Test isolation with t.Setenv

```go
// ✅ Good — t.Setenv automatically restores after test
func TestConfigFromEnv(t *testing.T) {
    t.Setenv("HYPERFLEET_LOG_LEVEL", "debug")
    cfg := LoadConfig()
    if cfg.LogLevel != "debug" {
        t.Errorf("expected debug, got %s", cfg.LogLevel)
    }
}

// ❌ Bad — global state leaked to other tests
func TestConfigFromEnv(t *testing.T) {
    os.Setenv("HYPERFLEET_LOG_LEVEL", "debug") // leaked!
    cfg := LoadConfig()
    // other tests may see HYPERFLEET_LOG_LEVEL=debug
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Test coverage is measured in CI but there is no hard coverage gate — reviewers use judgment. Integration tests use [Testcontainers](https://testcontainers.com/) per ADR-0011.

---

## References

### Related HyperFleet Standards

- [Linting Standard](../linting.md) — test-related linters
- [ADR-0011 — Testcontainers for integration tests](../../adrs/0011-testcontainers-for-integration-tests.md)

### External Resources

- [Go Testing Package](https://pkg.go.dev/testing)
- [Go Blog — Table Driven Tests](https://go.dev/wiki/TableDrivenTests)
