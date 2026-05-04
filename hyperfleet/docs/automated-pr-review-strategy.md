---
Status: Draft
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-20
---

# Automated PR review strategy

## Table of contents

- [Overview](#overview)
- [Problem statement](#problem-statement)
- [Current state](#current-state)
- [Capability mapping](#capability-mapping)
  - [CodeRabbit capabilities](#coderabbit-capabilities)
  - [Claude Code review skill capabilities](#claude-code-review-skill-capabilities)
  - [Overlap matrix](#overlap-matrix)
- [Gap analysis](#gap-analysis)
  - [What only CodeRabbit can do](#what-only-coderabbit-can-do)
  - [What CodeRabbit can do when properly configured](#what-coderabbit-can-do-when-properly-configured)
  - [What only the review skill can do](#what-only-the-review-skill-can-do)
- [Recommendation](#recommendation)
- [Trade-offs](#trade-offs)
- [Alternatives considered](#alternatives-considered)

---

## Overview

This document evaluates the overlap and differentiation between CodeRabbit and the HyperFleet Claude Code review skill (`/review-pr`) to determine where each tool provides unique value. The goal is to avoid building redundant capabilities and focus investment on genuine differentiation.

## Problem statement

PR reviews are a bottleneck in the development workflow. We currently have two automated review tools available:

1. **CodeRabbit** - Already integrated, providing general-purpose automated reviews
2. **Claude Code `/review-pr` skill** - Custom-built skill with HyperFleet-specific checks

A team discussion raised the question: _where is the juice worth the squeeze?_ CodeRabbit already offers features we are not fully leveraging (custom instructions, linked repos, learnable rules). Before investing further in the custom skill or automating it in CI, we need to understand where each tool genuinely adds value.

## Current state

### CodeRabbit

- Integrated in HyperFleet repositories on the Red Hat Enterprise plan (no linked repository limit)
- Current configuration is minimal (see `hypershift-fork/.coderabbit.yaml` for an example)
- CodeRabbit automatically reads `CLAUDE.md` and `.cursorrules` files in each repo for coding standards — this is already active without explicit configuration
- PR author must have a CodeRabbit license assigned to their GitHub username for full reviews to trigger
- Features **not yet leveraged**:
  - Custom code guidelines via `knowledge_base.code_guidelines` (can point to `AGENTS.md`, `.cursor/rules/`)
  - Learnable rules that improve over time from reviewer feedback
  - Linked dependent repos for cross-repo impact analysis
  - Custom review instructions pointing to HyperFleet standards
  - Path-specific review instructions (e.g., stricter rules for `cmd/` vs `pkg/`)
  - `golangci-lint` and `gitleaks` integration

> **Note on learnable rules**: CodeRabbit's learnable rules improve when reviewers acknowledge its comments (resolve, dismiss, or reply). Responding to CodeRabbit comments should be treated as part of the PR review process, enforced by the team's code review practices — the same way we respond to human reviewer comments.
>
> **Caveat**: Learnable rules are currently **disabled** across all Red Hat CodeRabbit repos (internal and public) due to contractual requirements specifying no data retention (`knowledge_base.opt_out: true`). Data retention is under review by the PTLT team, but there is no timeline for when learnable rules might become available.

#### CodeRabbit CLI (local)

CodeRabbit also provides a CLI tool (`coderabbit review`, v0.4.1) for local reviews before pushing. It supports plain text, interactive TUI (`--interactive`), and structured output for agent workflows (`--agent`). Custom instructions can be passed via `-c` flag (e.g., `coderabbit review -c standards.md`).

However, the CLI has significant limitations compared to the GitHub bot:

| Limitation | Detail |
| --- | --- |
| No linked repos | CLI only sees the local repo — no cross-repo impact analysis |
| No learnable rules | Rules learned from reviewer feedback on GitHub do not carry over to the CLI |
| No JIRA integration | No ticket validation of any kind |
| No PR context | Cannot see existing PR comments, reviews, or CodeRabbit bot comments |
| No commit suggestions | Reports findings but cannot apply fixes |
| Code sent to cloud | Analysis happens on CodeRabbit servers (requires API key) |

For local developer workflows, the CLI is useful for quick pre-push reviews but lacks the depth of the GitHub bot or the review skill.

### Claude Code review skill

- Available as `/review-pr` and `/review-local` (to be merged by [PR #33](https://github.com/openshift-hyperfleet/hyperfleet-claude-plugins/pull/33)) in the `hyperfleet-code-review` plugin
- Runs interactively in developer terminals
- 10 mechanical check groups covering Go-specific and language-agnostic patterns
- Already deduplicates findings against CodeRabbit comments

## Capability mapping

### CodeRabbit capabilities

| Capability | Status |
| --- | --- |
| General code review (bugs, style, patterns) | Active |
| Sequence diagram generation for changes | Active |
| High-level PR summary | Active |
| Path-based file filtering (vendor, generated) | Active |
| `golangci-lint` integration | Configurable |
| `gitleaks` secret scanning | Configurable |
| Automatic `CLAUDE.md` / `.cursorrules` reading | Active |
| Custom code guidelines (point to standards files) | Not configured |
| Learnable rules from reviewer feedback | Disabled (contractual data retention restriction) |
| Linked repos for cross-repo analysis | Not configured |
| Custom review instructions | Not configured |

### Claude Code review skill capabilities

| Capability | Description |
| --- | --- |
| JIRA ticket validation | Reads ticket + all comments (up to 50), validates acceptance criteria including refinements discussed in threads |
| Architecture doc cross-referencing | Validates code changes against HyperFleet architecture docs, detects drift |
| Call-chain impact analysis | Traces callers/callees of modified functions, flags consumers not updated in the PR |
| Doc-Code cross-referencing | If PR modifies a design doc, checks code implements every claim (and vice versa) |
| HyperFleet standards enforcement | Checks against specific coding standards (commit format, error model, logging, etc.) |
| Intra-PR consistency | Detects when a PR uses different patterns for the same concern |
| 10 mechanical check groups | Error handling, concurrency, exhaustiveness, resource lifecycle, code quality, testing, naming, security, hygiene, performance |
| Interactive fix application | In self-review mode, can apply fixes directly using Edit/Write tools |
| CodeRabbit deduplication | Reads existing CodeRabbit comments and avoids duplicating findings |

### Overlap matrix

This matrix considers CodeRabbit's full potential when properly configured (linked repos, custom guidelines, JIRA integration), not just the current minimal configuration.

| Capability | CodeRabbit (configured) | Review Skill | Overlap? |
| --- | --- | --- | --- |
| General bug detection | Yes | Yes | High |
| Security scanning | Yes | Yes | High |
| Code style / naming | Yes | Yes | High |
| Error handling patterns | Yes | Yes (Go-specific) | Medium |
| Performance patterns | Limited | Yes (Go-specific) | Low |
| Concurrency safety (Go) | Limited | Yes | Low |
| JIRA ticket validation | Partial (links PR to ticket, no comment-thread reading) | Yes (reads ticket + 50 comments) | Low |
| Architecture doc validation | Yes (via linked repo + custom instructions) | Yes | High |
| Call-chain impact analysis | Partial (linked repos + full codebase context) | Yes (explicit caller/callee tracing) | Medium |
| Doc-Code cross-referencing | Partial (via linked repo + custom instructions) | Yes (bidirectional, rigorous) | Medium |
| Intra-PR consistency | Partial (general pattern detection) | Yes (standards-aware) | Medium |
| HyperFleet standards enforcement | Yes (automatically reads `CLAUDE.md`; cross-repo standards via `code_guidelines` + linked repos) | Yes | High |
| Interactive fix application | Partial (GitHub commit suggestions) | Yes (local Edit/Write) | Medium |
| Learnable rules over time | Yes | No | None |
| PR summary / walkthrough | Yes | No | None |

## Gap analysis

### What only CodeRabbit can do

- **Learnable rules**: Improves over time from reviewer dismissals/acceptances, building institutional knowledge automatically. Currently disabled due to contractual data retention restrictions (under review, no timeline)
- **PR walkthrough and summary**: Generates high-level summary and sequence diagrams for every PR without manual invocation
- **Always-on automation**: Runs automatically on every PR without additional infrastructure
- **Tool integrations**: Built-in `golangci-lint`, `gitleaks`, and other static analysis tool orchestration

### What CodeRabbit can do when properly configured

Several capabilities previously considered exclusive to the review skill can be partially or fully emulated by configuring CodeRabbit:

| Capability | How to emulate in CodeRabbit | Gap remaining |
| --- | --- | --- |
| Architecture doc validation | Link the `architecture` repo via `linked_repositories` + add custom instructions to validate against architecture docs | CodeRabbit reads the docs but does not enforce bidirectional validation rigorously — it may miss subtle drift |
| HyperFleet standards enforcement | CodeRabbit already reads `CLAUDE.md` automatically for repo-local standards; cross-repo standards via `code_guidelines` pointing to linked architecture repo | High coverage — repo-local standards work out of the box, cross-repo standards require linked repos configuration |
| Call-chain impact analysis | `linked_repositories` gives cross-repo context; CodeRabbit already analyzes full codebase | Does not do explicit caller/callee tracing, but detects many inconsistencies through context |
| Doc-Code cross-referencing | Custom instructions + linked architecture repo | Partial — CodeRabbit can compare but does not systematically verify every claim in a design doc against the implementation |
| Interactive fix application | GitHub "commit suggestion" feature in PR comments | Different UX (browser vs terminal), but solves the same problem — applying fixes |
| JIRA ticket validation | CodeRabbit has JIRA integration (links PRs to tickets) | **Significant gap**: does not read JIRA comment threads to validate acceptance criteria refinements discussed after ticket creation |
| Intra-PR consistency | General pattern detection across the diff | Partial — can be improved with custom instructions pointing to specific patterns to watch for |

### What only the review skill can do

After configuring CodeRabbit fully, the genuinely exclusive capability is:

- **JIRA comment-thread validation**: Reading all comments (up to 50) on a JIRA ticket to validate that acceptance criteria refinements — discussed in threads after the ticket was created — are implemented in the PR. No other tool reads JIRA ticket comments at this depth.

## Recommendation

### Three complementary layers

Rather than choosing one tool over the other, use each for what it does best:

**CodeRabbit = automated filter (always-on)**

Runs automatically on every PR with zero developer effort. Once properly configured, it handles:

- General code quality (bugs, security, naming, error handling)
- HyperFleet standards enforcement (automatically reads `CLAUDE.md`; cross-repo standards via `code_guidelines` + linked repos)
- Architecture doc awareness (via [`multi-repo analysis`](https://docs.coderabbit.ai/knowledge-base/multi-repo-analysis))
- PR summary and walkthrough
- Learnable rules that improve over time from reviewer feedback (pending data retention enablement — see [caveat above](#coderabbit))

Configuration required (see [CodeRabbit configuration overview](https://docs.coderabbit.ai/guides/configuration-overview)):

1. **Link the architecture repo** via [`multi-repo analysis`](https://docs.coderabbit.ai/knowledge-base/multi-repo-analysis) so CodeRabbit can read standards and architecture docs
2. **Add custom code guidelines** via [`knowledge_base.code_guidelines`](https://docs.coderabbit.ai/knowledge-base/code-guidelines) pointing to HyperFleet standards. Note: CodeRabbit already reads `CLAUDE.md` and `.cursorrules` files automatically for repo-local standards — `code_guidelines` adds explicit pointers and cross-repo standards via linked repositories
3. **Add [path-specific review instructions](https://docs.coderabbit.ai/guides/review-instructions#path-specific-instructions)** for areas requiring stricter review (e.g., `cmd/`, `config/`, `deploy/`) — the default is generic ("focus on major issues"), so tailoring instructions per path improves signal quality
4. **Add custom review instructions** directing CodeRabbit to validate changes against architecture docs and standards
5. **Enable JIRA integration** to [link PRs to tickets](https://docs.coderabbit.ai/integrations/jira) automatically
6. **Enable [learnable rules](https://docs.coderabbit.ai/knowledge-base/learnings)** so CodeRabbit improves from reviewer feedback — **blocked** until PTLT resolves the data retention restriction (see [caveat above](#coderabbit))
7. **Set up [central configuration](https://docs.coderabbit.ai/configuration/central-configuration)** using CodeRabbit's inheritance system — settings cascade from enterprise → org UI → org `.coderabbit.yaml` → repo `.coderabbit.yaml` (highest priority). Define org-wide defaults and let individual repos override as needed
8. **Enable `golangci-lint` and `gitleaks`** [integrations](https://docs.coderabbit.ai/tools/list)

> **Plan note — linked repositories**
>
> HyperFleet is on the Enterprise plan with **no linked repository limit**. Cross-repo analysis (step 1 above) can link the architecture repo and all cross-component repos (API, Sentinel, Adapter, Broker) to each other without constraints.

> **Configuration note — auto-review behavior**
>
> CodeRabbit does not have to be always-on. Via org-level or repo-level `.coderabbit.yaml`, automatic reviews can be disabled so CodeRabbit only reviews when explicitly requested (e.g., by adding a label or commenting on the PR). This strategy recommends always-on for the initial rollout to maximize learnable rule feedback, but teams can adjust per repo if review noise becomes a concern.

**`/review-pr` = on-demand microscope (human-invoked)**

A developer chooses when to run it and what to do with each finding. The value is in the interactive workflow:

- **Self-review mode**: review your own PR before requesting human review, choose to fix or skip each finding
- **Comment mode**: review someone else's PR, choose to post inline comments or skip
- **Depth on demand**: JIRA comment-thread validation, call-chain impact analysis, and doc-code cross-referencing run only when a human decides they are worth the time

The skill does not need CI automation because its value comes from human interaction — the developer decides what to act on. Automating it would strip the interactivity that makes it useful.

**PR risk scoring = automated triage (always-on)**

A lightweight Prow presubmit job that computes a deterministic risk score for every PR and applies a label (`risk/low`, `risk/medium`, `risk/high`). No LLM — pure shell script running in seconds.

Scoring signals:

| Signal | Condition | Points |
| --- | --- | --- |
| PR size | > 200 lines changed | +1 |
| PR size | > 500 lines changed | +2 |
| Sensitive paths | Changes in `cmd/`, `config/`, `deploy/`, `migrations/`, `auth/` | +2 |
| Test coverage | No `_test.go` files in diff | +2 |
| Test coverage | Tests present but don't cover new packages | +1 |

Risk thresholds:

| Score | Level | Label |
| --- | --- | --- |
| 0–1 | Low | `risk/low` |
| 2–3 | Medium | `risk/medium` |
| 4+ | High | `risk/high` |

The risk label enables workflow differentiation: low-risk PRs can follow a fast review path, high-risk PRs require stricter review (e.g., multiple approvers). Branch protection rules can use these labels to enforce review requirements.

> **Implementation:** Tracked in [HYPERFLEET-991](https://redhat.atlassian.net/browse/HYPERFLEET-991). Recommended to run in "observe mode" for 2-3 sprints first — compute and label without gating — to calibrate thresholds against real data before enforcing merge policies.

> **Measurement:** Use the existing [PR Cycle Time dashboard](https://metrics.dprod.io/dashboard.html?team=openshift-hyperfleet&dashboard=prcycletime) to track impact. Baseline (April 2026): median cycle time 14.3h, first review 6.5h, first approval 24.3h. After the observe period, compare these metrics to validate whether risk labels correlate with review speed and cycle time improvement.

## Trade-offs

### What we gain

- Once data retention is enabled, leverages CodeRabbit's learnable rules to build institutional review knowledge over time
- Single source of automated review feedback on PRs (less noise for reviewers)
- Developers get deep, interactive review on demand without waiting for CI

### What we lose / what gets harder

- Two tools to maintain (CodeRabbit configuration + review skill plugin)
- Developers must remember to invoke `/review-pr` — it does not run automatically
- Dependency on CodeRabbit as a third-party service for the automated layer
- If CodeRabbit is discontinued or pricing changes, the automated layer is lost

### Acceptable because

- CodeRabbit is already integrated and paid for; not leveraging it fully is waste
- The skill's maintenance cost is lower when it focuses on interactive depth rather than duplicating automated checks
- Developers already use Claude Code daily — invoking `/review-pr` is a natural extension of the workflow
- The deduplication built into the skill ensures no overlap in practice

## Alternatives considered

### Build everything custom, replace CodeRabbit

**What**: Expand the review skill to cover all review needs and remove CodeRabbit entirely.

**Concern**: High maintenance cost for capabilities CodeRabbit already provides well (general bug detection, security scanning, learnable rules). The team would need to maintain mechanical check groups that duplicate mature third-party functionality. CodeRabbit's always-on automation and learnable rules are difficult to replicate.

### Use only CodeRabbit, retire the review skill

**What**: Configure CodeRabbit extensively (see [configuration steps](#three-complementary-layers)) and stop investing in the custom skill.

**Consideration**: This may be the right answer, but we lack data. Configuring CodeRabbit first and measuring its effectiveness with HyperFleet standards and architecture docs would allow an informed decision. Retiring the skill prematurely could leave gaps we only discover in practice.

### Run both tools at full scope, evaluate later

**What**: Keep both tools running with full scope, evaluate after 2-3 sprints, then decide whether to keep, narrow, or retire the review skill based on data.

**Consideration**: The review skill already deduplicates against CodeRabbit comments, so reviewers would not see duplicate findings. Since `/review-pr` is human-invoked, the developer controls when to run it, which findings to act on, and whether to post a comment or not — the power stays with the human. In practice, complementary roles emerge naturally: the skill's deduplication skips what CodeRabbit already found, so the overlap resolves itself at runtime without needing to remove checks from the skill. This also preserves the skill's full value for `/review-local`, which runs before push when no CodeRabbit comments exist yet. The risk is that the evaluation period delays action and the team continues maintaining both tools in the interim.

### Automate the review skill in CI (original ticket scope)

**What**: Build a Prow job to run the review skill automatically on every PR, as described in HYPERFLEET-781.

**Consideration**: The original scope assumed the review skill provided unique value that justified CI automation. This analysis shows that most of that value can be achieved by properly configuring CodeRabbit — which requires no infrastructure investment. Additionally, automating the skill in CI would strip its interactive workflow (fix/comment/skip), which is where most of its value lies.
