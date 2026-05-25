---
Status: Active
Owner: HyperFleet Team
Last Updated: 2026-05-25
---

# GitHub-Jira Integration

## Table of Contents

- [Overview](#overview)
- [What the Integration Surfaces](#what-the-integration-surfaces)
- [How Linking Works](#how-linking-works)
  - [Linking Rules](#linking-rules)
  - [Examples](#examples)
- [Using the Development Panel](#using-the-development-panel)
- [Monitoring Review Items via Jira](#monitoring-review-items-via-jira)
  - [JQL Queries](#jql-queries)
- [Limitations](#limitations)
- [Relationship to Other Processes](#relationship-to-other-processes)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

The HyperFleet Jira project is integrated with the `openshift-hyperfleet` GitHub organization via the **GitHub for Jira** plugin (formerly known as the DVCS connector). This integration automatically surfaces GitHub development activity — branches, commits, and pull requests — directly inside Jira work items.

This document describes what the integration provides, how it works, and how the team should use it to track PR review status without leaving Jira.

---

## What the Integration Surfaces

Once a GitHub branch, commit, or pull request references a Jira ticket key, Jira displays that information in the **Development Panel** on the work item. The panel shows:

| Item              | What You See                                              |
| ----------------- | --------------------------------------------------------- |
| **Branches**      | Branch name linked to GitHub, creation status             |
| **Commits**       | Commit messages linked to GitHub, author                  |
| **Pull Requests** | PR title, status (open, merged, declined), link to GitHub |

This gives anyone viewing a Jira ticket — engineers, leads, product — a real-time view of development progress without opening GitHub.

---

## How Linking Works

The integration matches Jira ticket keys (e.g., `HYPERFLEET-1015`) found in GitHub activity to the corresponding Jira work item. No manual linking is required.

### Linking Rules

Do **at least one** of the following:

1. **Include the ticket key in the PR title** — e.g., `HYPERFLEET-1015 - docs: add GitHub-Jira integration guide`
2. **Include the ticket key in the branch name** — e.g., `HYPERFLEET-1015-github-jira-integration-docs`

Both conventions are already standardized by HyperFleet standards:

- The [commit standard](../standards/commit-standard.md) mandates `HYPERFLEET-XXX - <type>: <subject>` in commit messages
- The [working agreement](working-agreement.md#2-branch-and-develop) mandates `HYPERFLEET-XXX-brief-description` as the branch naming convention

If you follow the existing standards, the integration works automatically with no extra effort.

### Examples

| Convention     | Example                                                     | Auto-linked? |
| -------------- | ----------------------------------------------------------- | :----------: |
| Branch name    | `HYPERFLEET-1015-github-jira-integration-docs`              |     Yes      |
| PR title       | `HYPERFLEET-1015 - docs: add GitHub-Jira integration guide` |     Yes      |
| Commit message | `HYPERFLEET-1015 - docs: add integration doc`               |     Yes      |

---

## Using the Development Panel

When you open a Jira work item that has linked GitHub activity, the **Development** section appears in the detail view. It shows:

- Number of linked branches, commits, and pull requests
- Current PR status (open / merged / declined)
- Direct links to each item on GitHub

Use this panel to:

- **Check if work has started** — a branch exists for the ticket
- **Track PR progress** — see if a PR is open, under review, or merged
- **Verify completion** — confirm the PR was merged before moving the ticket to Done

---

## Monitoring Review Items via Jira

### JQL Queries

Use these JQL queries in Jira to find tickets based on their development status:

#### Tickets with an open PR (awaiting review or merge)

```jql
project = HYPERFLEET AND development[pullrequests].open > 0
```

#### Tickets with at least one PR (any status)

```jql
project = HYPERFLEET AND development[pullrequests].all > 0
```

#### In-progress tickets with no PR yet

```jql
project = HYPERFLEET AND status = "In Progress" AND development[pullrequests].all = 0
```

#### Tickets with merged PRs (candidates for Done)

```jql
project = HYPERFLEET AND development[pullrequests].all > 0 AND development[pullrequests].open = 0
```

You can save these as Jira filters or add them to your board for quick access.

---

## Limitations

| Limitation                   | Detail                                                                                                                                                                                          |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **No GitHub issue sync**     | The integration does not sync GitHub Issues to Jira. For issue-level sync, a separate tool (e.g., Sync2Jira) would be required                                                                  |
| **No auto-transitions**      | Merging a PR does not automatically move the Jira ticket to Done. Engineers must update ticket status manually as described in the [working agreement](working-agreement.md#5-close-the-ticket) |
| **User matching**            | The integration matches users by email. If your GitHub email does not match your Red Hat Jira email, commits and PRs may not be attributed to you                                               |
| **Development panel fields** | Development panel data uses a special JQL syntax (`development[pullrequests]`) and cannot be queried as standard custom fields                                                                  |

---

## Relationship to Other Processes

This integration complements — but does not replace — existing team processes:

| Process                | Where Documented                                                                | How This Integration Helps                                                                                |
| ---------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| PR visibility in Slack | [Working Agreement — Open a PR](working-agreement.md#3-open-a-pr)               | Jira provides an alternative view; Slack remains the primary notification channel                         |
| Code review workflow   | [Working Agreement — Review and Merge](working-agreement.md#4-review-and-merge) | Development panel shows PR status at a glance from the ticket                                             |
| Ticket closure         | [Working Agreement — Close the Ticket](working-agreement.md#5-close-the-ticket) | Development panel confirms PR was merged before marking Done                                              |
| Automated PR review    | [Automated PR Review Strategy](automated-pr-review-strategy.md)                 | Separate concern — CodeRabbit and `/review-pr` handle review quality; this integration handles visibility |

---

## Troubleshooting

### PR not appearing in the Development Panel

1. Verify the ticket key is in the PR title or branch name (e.g., `HYPERFLEET-1015`)
2. Wait a few minutes — sync is not instant
3. Check that the `openshift-hyperfleet` organization is connected to the HYPERFLEET Jira project

### Commits not linked to your Jira user

Ensure your GitHub commit email matches your Red Hat Jira account email. Check your GitHub email settings at `Settings > Emails`.

### Integration issues

If the integration stops working (PRs not syncing, Development panel empty), contact the Jira admin team via the [JSM Portal](https://redhat.atlassian.net/servicedesk/customer/portal/67) with a Generic Request.

---

## References

- [Integrate Jira with GitHub — Atlassian Support](https://support.atlassian.com/jira-cloud-administration/docs/integrate-with-github/)
- [Reference work items in your development spaces — Atlassian Support](https://support.atlassian.com/jira-software-cloud/docs/reference-issues-in-your-development-work/)
- [Red Hat internal: GitHub integration with Red Hat Jira](https://redhat.atlassian.net/wiki/spaces/OMEGA/pages/303587673) (Confluence, requires Red Hat SSO)
- [HyperFleet Working Agreement](working-agreement.md)
- [HyperFleet Commit Standard](../standards/commit-standard.md)
