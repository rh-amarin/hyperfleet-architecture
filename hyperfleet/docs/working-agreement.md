---
Status: Draft
Owner: HyperFleet Team
Last Updated: 2026-04-14
---

# HyperFleet Working Agreement

## Purpose

This document defines how the HyperFleet team works together. It captures our processes for delivering work from ticket to merge, reviewing code, maintaining architecture documentation, and making technical decisions.

This is a **living document**. Our processes will evolve as we learn and grow. We will formalize processes as needed when we have production customers. Until then, we stay lightweight and adapt.

> **Supersedes**: [MVP Working Agreement](../deprecated/mvp/mvp-working-agreement.md) (Historical)

---

## Definition of Ready

Before picking up a ticket, confirm:

- [ ] Acceptance criteria are written and clear
- [ ] Dependencies are identified (ticket has no blockers)
- [ ] Open questions are answered
- [ ] Work is sized to complete within a sprint
- [ ] Required JIRA fields set (see [Ticket Hygiene Standard](../standards/ticket-hygiene.md))

If a ticket is not ready, update it before starting work. If acceptance criteria appear out of date, raise it with the **epic owner** — they are responsible for keeping acceptance criteria current across their epic.

---

## Ticket-to-Merge Flow

### 1. Pick Up Work

- Work is tracked in Jira (project: HYPERFLEET)
- Each ticket has **acceptance criteria** that define done
- If acceptance criteria are unclear or missing, update them before starting work (see [Definition of Ready](#definition-of-ready))
- If the ticket is estimated at **5 or more story points**, add a collaborator and discuss the approach before starting work — this helps catch misinterpretations early
- Assign yourself and move the ticket to **In Progress**

### 2. Branch and Develop

- Fork the organisation repo and branch from `main` using the naming convention: `HYPERFLEET-XXX-brief-description`
- Follow the [commit standard](../../hyperfleet/standards/commit-standard.md): `HYPERFLEET-XXX - <type>: <subject>`
- Run linting and tests locally before pushing (`make test-all`, see [CONTRIBUTING.md](../../CONTRIBUTING.md#testing--linting))
- Run an AI review locally using `/review-pr` from [hyperfleet-claude-plugins](https://github.com/openshift-hyperfleet/hyperfleet-claude-plugins) to check against team standards before posting for human review

### 3. Open a PR

- Add a clear description: what changed, why, how to test the PR, and who to loop in
- Resolve all CodeRabbit comments before requesting human review — fix valid suggestions and respond to rejected ones with a reason
- Post the PR link in [#hcm-hyperfleet-team](https://redhat.enterprise.slack.com/archives/hcm-hyperfleet-team) and tag `@hyperfleet-code-review` for visibility
- See [CONTRIBUTING.md](../../CONTRIBUTING.md#submitting-changes) for the full submission process

### 4. Review and Merge

- Multiple commits per PR are fine, but each commit message should be meaningful
- Allow **24 hours** for peer review (accounts for time zone differences)
- If a PR has no review activity after 24 hours, bump the Slack thread with a reminder
- For urgent changes, use judgement but document rationale clearly
- For major architectural changes, wait for at least one Technical Leader review
- Merge once approved with no objections

### 5. Close the Ticket

- Verify acceptance criteria are met (or trade-offs are documented)
- Update the architecture repo if needed (see [Architecture Doc Maintenance](#architecture-doc-maintenance))
- Link the PR in the Jira ticket
- Move to **Done**

---

## Code Review

### Expectations

- **Review for correctness**: Bugs, edge cases, error handling
- **Review for consistency**: Patterns align across the codebase and with [engineering standards](../standards/)
- **Review for clarity**: Code is understandable to someone who didn't write it
- **Review for learning**: Share knowledge, suggest patterns, ask questions

### Reviewer Guidelines

- Everyone is welcome to add comments to a review — every question is valid
- Be constructive and specific
- Distinguish between blocking issues and suggestions (prefix with `nit:` for non-blocking)
- If you approve with suggestions, trust the author to address them
- Don't block PRs on style preferences already covered by linting

### Author Guidelines

- Keep PRs focused and reviewable (smaller is better)
- Respond to all review comments, even if just acknowledging
- If you disagree with feedback, discuss it — don't ignore it

---

## Architecture Doc Maintenance

### When to Update

Update the architecture repo when closing a ticket if the work:

- Changes system architecture or component design
- Adds, removes, or modifies components or services
- Changes APIs, events, or contracts
- Introduces new patterns or approaches
- Affects deployment, operations, or configuration

**Rule of thumb**: If your work changes how the system works, update the architecture repo. The [hyperfleet-architecture plugin](https://github.com/openshift-hyperfleet/hyperfleet-claude-plugins/tree/main/hyperfleet-architecture) can help identify what needs updating.

### What to Document

| Change Type | Where to Document |
|---|---|
| Component design changes | `hyperfleet/components/` |
| New standards or conventions | `hyperfleet/standards/` |
| Implementation guides, runbooks | `hyperfleet/docs/` |
| Architecture decisions | `hyperfleet/adrs/` |

### How to Keep in Sync

1. Before closing a ticket, ask: "Does the architecture repo still reflect reality?" — the `/is-ticket-implemented` command can help verify this
2. Make documentation updates in the same PR when the change is in the same repo. Use a follow-up PR only for cross-repo changes
3. Link the architecture repo PR in the Jira ticket

---

## Decision-Making

### Principles

- **Decide locally**: If it affects only your work, you decide
- **Consult when helpful**: Seek input when you'd benefit from another perspective
- **Escalate cross-cutting changes**: Bring architectural or cross-team impacts to the group
- **Document trade-offs**: Record significant decisions so future engineers understand the "why"

### When to Document a Decision

Document decisions with architectural impact, cross-team scope, or significant trade-offs using an [Architecture Decision Record](../adrs/README.md). See the ADR README's [When to Write an ADR](../adrs/README.md#when-to-write-an-adr) section for the full criteria.

### Handling Trade-offs Against Acceptance Criteria

When you need to deviate from acceptance criteria:

1. **Document the trade-off** — what was originally expected, what you delivered, why, and the impact
2. **Update the ticket** — modify acceptance criteria or add a comment explaining the change
3. **Tag stakeholders** if the trade-off is significant

---

## Communication

### Channel Map

| Channel | Purpose | Response Expectation |
|---------|---------|---------------------|
| #hcm-hyperfleet-team (Slack) | PR links, team updates, quick questions | Same business day |
| Jira comments | Ticket-specific decisions, trade-offs, blockers | End of next business day |
| Architecture repo PRs | Design decisions, standards changes | 24 hours |
| Direct Slack DM | Sensitive or personal topics only | Best effort |

### Principles

- **Async-first**: Use Jira, Slack, and the architecture repo for decisions
- **Sync when helpful**: Jump on a call when async becomes inefficient
- **Document outcomes**: Record decisions from sync discussions in Jira or the architecture repo

### Working Across Time Zones

- Update Jira tickets before end of day so the other region has context
- Document blockers clearly — tag people who can unblock you
- Don't block on reviews — keep PRs flowing asynchronously
- Use overlap hours for discussions that need real-time back-and-forth

### Asking for Help

- Ask early, don't struggle alone
- Ask in team channels (helps everyone learn)
- Include context: what you're trying to do, what you've tried, what you need

---

## Meeting Norms

### Daily Standup (Slack)

- Async standup thread in Slack, all time zones
- Every engineer is required to post an update

### Crossover Calls

- 2 calls in NASA-friendly time zones, 3 in APAC-friendly time zones
- Every crossover call bridges European time zone
- Purpose: internal office hours — bring questions, seek clarity, give updates, share knowledge, brown bag sessions
- **Not mandatory, but encouraged**

### Office Hours

- Once a week, alternating between APAC-friendly and NASA-friendly weeks
- Main touch point for coordination with partner teams
- **Encouraged** — this is where cross-team alignment happens

### Sprint Ceremonies

- **Backlog refinement**: Once per sprint. Mandatory for team leads only. Outcomes communicated via Slack and crossover calls
- **Sprint demo**: Once per sprint, with NASA-friendly and APAC-friendly sessions
- **Retrospectives**: Held at each team lead's discretion to reflect on what's working and what isn't

### Focus Time

- Engineers are encouraged to block-book focus time in their own calendars
- Meetings are welcome when they are valuable — the goal is not to avoid meetings, but to protect uninterrupted time for deep work

---

## Definition of Done

A ticket is done when all three are complete:

| Area | Criteria |
|---|---|
| **Code** | Meets acceptance criteria (or documented trade-offs). Follows [engineering standards](../standards/). Passes CI (build, lint, security scans). |
| **Tests** | Unit tests for core logic. Integration tests where components interact. E2E tests for critical flows where applicable. All tests passing in CI. |
| **Documentation** | Code comments for complex logic. Usage/operational documentation. Architecture repo updated if the work changes system behavior. |

---

## Quality Expectations

### Production-Ready Means

- Works reliably, not just in ideal conditions
- Handles errors with graceful degradation and clear messages
- Observable: logs, metrics, traces for debugging
- Secure: no vulnerabilities, secrets managed properly
- Maintainable: clear code, documented trade-offs

### Testing Expectations

- Test what matters: critical paths and edge cases
- Test at the right level: unit for logic, integration for interactions, E2E for flows
- No flaky tests in CI
- Fast feedback loop for developers

---

## WIP Limits

- **3 items in progress** and **3 items in review** per engineer
- This is a guideline for now — we may enforce it in Jira if needed

---

## Conflict Resolution

When technical or interpersonal disagreements arise:

1. **Discuss directly** between the people involved
2. **Bring it to a crossover call** if unresolved — use the team for perspective
3. **Escalate to tech lead / engineering manager** if it still cannot be resolved

Ground rules:

- Focus on the idea, not the person
- Disagreement is healthy — it leads to better decisions
- Once a decision is made, align and move forward

---

## Psychological Safety

- It is safe to say "I don't know"
- Mistakes are learning opportunities, not blame events
- Challenging a technical approach is expected, regardless of who proposed it
- Ask questions freely — no question is too basic
- Give feedback with respect, receive feedback with openness

---

## Continuous Improvement

- Retrospectives surface improvements (see [Sprint Ceremonies](#sprint-ceremonies))
- This working agreement is updated based on what we learn
- Anyone can propose changes — open a PR
- **We review this agreement quarterly and when onboarding new team members**

**This document exists to support the team, not constrain it. If something isn't working, change it.**
