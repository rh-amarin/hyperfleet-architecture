---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-27
---

# Code Review Standards

> Prescriptive code review guidelines for all HyperFleet repositories. Each standard is a standalone document consumed by human reviewers, CodeRabbit, and Claude Code review skills (`/review-local`, `/review-pr`). See [Automated PR Review Strategy](../../docs/automated-pr-review-strategy.md) for the three-layer review model.

---

## Catalog

| Check | Summary | Risk | When it triggers |
|-------|---------|------|------------------|
| [error-handling](error-handling.md) | Error checking, wrapping, and HTTP handler returns | Bug | Go diffs |
| [concurrency](concurrency.md) | Shared state protection, goroutine lifecycle, loop variable capture | Bug | Go diffs |
| [exhaustiveness](exhaustiveness.md) | Switch/select completeness, nil/bounds guards | Bug | Go diffs |
| [resource-lifecycle](resource-lifecycle.md) | Cleanup on all paths, context propagation, timer leaks | Bug | Go diffs |
| [code-quality](code-quality.md) | Constants, struct initialization, function complexity | Debt | Go diffs |
| [testing](testing.md) | Coverage for new code, test structure, isolation and cleanup | Debt | Go diffs |
| [naming](naming.md) | Go naming conventions (stuttering, acronyms, getters, interfaces) | Style | Go diffs |
| [performance](performance.md) | Preallocation, defer in loops, N+1 queries | Debt | Go diffs |
| [security](security.md) | Injection, secrets exposure, path traversal, input validation | Bug | All diffs |
| [code-hygiene](code-hygiene.md) | TODOs without tickets, log levels, typos | Debt | All diffs |

## Risk tiers

Risk reflects **production consequences of violation**, not difficulty of fixing.

- **Bug** — violation is a bug, leak, race condition, or vulnerability. Unchecked errors, resource leaks, missing returns, SQL injection, secrets in logs.
- **Debt** — code works but maintainability or performance suffers. Preallocation, test structure, function complexity.
- **Style** — legitimate trade-offs exist either way. Naming preferences where both options are valid Go.

The catalog risk is the document-level default. Individual rules within a document use RFC 2119 keywords (MUST/SHOULD/MAY) for requirement level, which may differ from the document default when production consequence warrants it (e.g., PERF-04 "defer in loops" uses MUST within the Debt-level performance document because it causes memory accumulation).

## Applicability

- **Go-specific** standards (8): apply only when the diff contains `.go` files.
- **Language-agnostic** standards (2: security, code-hygiene): apply to every diff regardless of file types.

Generated code, vendored dependencies, and files excluded by the [Generated Code Policy](../generated-code-policy.md) MUST NOT be reviewed against these standards.

## References

- [Automated PR Review Strategy](../../docs/automated-pr-review-strategy.md)
- [Linting and Static Analysis Standard](../linting.md) — automated checks that complement these review guidelines
- [Generated Code Policy](../generated-code-policy.md) — exclusion rules for generated files
- [Working Agreement — Code Review](../../docs/working-agreement.md) — reviewer/author expectations
