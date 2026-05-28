---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review: Security

> Language-agnostic code review standard for injection prevention, secrets exposure, and input validation. Applies to all diffs regardless of file types.

---

## Table of Contents

1. [Overview](#overview)
2. [Standard](#standard)
3. [Examples](#examples)
4. [Enforcement](#enforcement)
5. [References](#references)

---

## Overview

Security vulnerabilities introduced during code review — injection, secrets exposure, path traversal — are the most consequential defects a reviewer can catch. This standard defines the mechanical checks reviewers apply to every place where external input enters the system.

### Risk: Bug

Violations are vulnerabilities. An SQL injection can expose or destroy production data; a leaked secret can compromise the entire system.

---

## Standard

### SEC-01: Injection prevention

Every place in a diff where external input (HTTP parameters, environment variables, user-provided strings, file content) is incorporated into SQL queries, shell commands, template rendering, or structured queries MUST use parameterized or escaped construction.

Reviewers MUST flag:

- String interpolation or concatenation to build SQL queries, shell commands, or LDAP filters.
- Template rendering with unescaped user input.
- Shell command execution with unsanitized arguments.

Sanitization and validation requirements in the [Error Model Standard](../error-model.md) apply.

### SEC-02: Secrets exposure

Every log statement, error message, HTTP response body, and metric label in a diff MUST be checked against the redaction requirements in the [Logging Specification](../logging-specification.md) and [Error Model Standard](../error-model.md).

Reviewers MUST flag:

- API tokens, passwords, credentials, or cloud provider access keys in log output, error messages, or response bodies.
- Secrets passed via URL query parameters (visible in access logs).
- Hardcoded secrets in source code (including test fixtures that use real credentials).
- PII in logs or metrics without explicit redaction.

### SEC-03: Path traversal and input validation

Every place where external input constructs file paths, URLs, or resource identifiers MUST be validated:

- **Path traversal** — `../` sequences or absolute paths from user input MUST be sanitized. Reviewers SHOULD verify use of path-safe construction.
- **Input validation at system boundaries** — HTTP handlers, CLI argument parsers, webhook receivers, and config file readers MUST validate required fields, enforce type constraints, and bound input size (e.g., max length on string fields, max size on uploaded files).

Exceptions:

- Internal function calls where input comes from trusted, already-validated sources.
- Config files that are not user-facing.

---

## Examples

### SQL injection

```sql
-- ✅ Good — parameterized query
SELECT * FROM clusters WHERE id = $1

-- ❌ Bad — string concatenation
SELECT * FROM clusters WHERE id = '` + userInput + `'
```

### Secrets in logs

```text
# ✅ Good — secret redacted
log("connecting to API", endpoint=endpoint)

# ❌ Bad — secret in log output
log("connecting to API", endpoint=endpoint, token=apiToken)
```

### Path traversal

```text
# ✅ Good — path validated against base directory
cleanPath = canonicalize(userPath)
if not cleanPath.startsWith(baseDir):
    return error("invalid path")

# ❌ Bad — user input used directly as file path
data = readFile(userPath)  // traversal: userPath = "../../etc/passwd"
```

### Go-specific

#### Command injection

```go
// ✅ Good — arguments passed as separate strings, not shell-interpreted
cmd := exec.Command("kubectl", "get", "pods", "-n", namespace)

// ❌ Bad — shell injection via string interpolation
cmd := exec.Command("sh", "-c", fmt.Sprintf("kubectl get pods -n %s", namespace))
```

#### SQL with database/sql

```go
// ✅ Good — parameterized query
rows, err := db.QueryContext(ctx, "SELECT * FROM clusters WHERE id = $1", clusterID)

// ❌ Bad — string formatting
rows, err := db.QueryContext(ctx, fmt.Sprintf("SELECT * FROM clusters WHERE id = '%s'", clusterID))
```

#### filepath.Clean for path safety

```go
// ✅ Good — clean, join, and validate with path separator to prevent prefix bypass
requested := filepath.Clean(filepath.Join(baseDir, userInput))
if !strings.HasPrefix(requested, baseDir+string(os.PathSeparator)) && requested != baseDir {
    return fmt.Errorf("path traversal attempt: %s", userInput)
}

// ❌ Bad — HasPrefix without separator allows bypass
// userInput = "../uploadsfoo" → requested = "/tmp/uploadsfoo" passes HasPrefix("/tmp/uploads")
requested := filepath.Clean(filepath.Join(baseDir, userInput))
if !strings.HasPrefix(requested, baseDir) { // BYPASS: prefix match without separator
    return fmt.Errorf("path traversal attempt: %s", userInput)
}
```

---

## Enforcement

Enforced via the [three-layer review model](../../docs/automated-pr-review-strategy.md).

Partially automated: `gitleaks` is enabled via pre-commit hooks for secret scanning. `gosec` is available but not currently enabled in golangci-lint. Most injection and path traversal patterns require semantic understanding — review is essential.

---

## References

### Related HyperFleet Standards

- [Error Model Standard](../error-model.md) — sanitization requirements for error responses
- [Logging Specification](../logging-specification.md) — sensitive data redaction rules
- [Linting Standard](../linting.md) — `gosec`, `gitleaks` integration

### External Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [CWE-22: Path Traversal](https://cwe.mitre.org/data/definitions/22.html)
