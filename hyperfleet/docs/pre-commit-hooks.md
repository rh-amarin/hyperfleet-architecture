---
Status: Active
Owner: HyperFleet Platform Team
Last Updated: 2026-05-14
---

# Pre-Commit Hooks Setup Guide

> Setup, configuration, and usage guide for HyperFleet's centralized pre-commit hooks. Covers installation, project-specific configurations, and migration steps for adding hooks to existing repositories.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Available Hooks](#available-hooks)
4. [Standard Configuration](#standard-configuration)
5. [Migration Guide](#migration-guide)
6. [Troubleshooting](#troubleshooting)
7. [References](#references)

---

## Overview

HyperFleet uses a **centralized hook registry** at [`hyperfleet-hooks`](https://github.com/openshift-hyperfleet/hyperfleet-hooks) to enforce consistent commit message format and code quality across all repositories. Additionally, **LeakTK** provides secret scanning to prevent credentials and API keys from being committed. The [pre-commit](https://pre-commit.com/) framework automatically downloads, builds, and caches hook binaries — no manual installation of individual tools is required.

### How It Works

```text
hyperfleet-hooks repository (centralized)
├── .pre-commit-hooks.yaml    # Hook definitions
├── cmd/                      # commitlint Go binary
└── docs/                     # Hook documentation

         ▼ consumed by pre-commit framework ▼

Any HyperFleet repository (consumer)
├── .pre-commit-config.yaml   # Selects which hooks to use
└── Makefile                  # install-hooks target
```

When a developer runs `git commit`, the pre-commit framework intercepts the operation, runs the configured hooks, and blocks the commit if any hook fails. This provides immediate feedback before code reaches CI.

---

## Prerequisites

- [pre-commit](https://pre-commit.com/#install) installed:

  ```bash
  pip install pre-commit
  ```

- Go 1.25+ (for the `commitlint` hook and LeakTK secret scanning — both built automatically by pre-commit on first run)
- `btrfs-progs-devel` (Fedora/RHEL) for LeakTK compilation:

  ```bash
  sudo dnf install btrfs-progs-devel
  ```

- `make` targets (`lint`, `gofmt`, `go-vet`) in the consuming repo (for Go tooling hooks)

---

## Available Hooks

### HyperFleet Hooks

All hooks are defined in the [`hyperfleet-hooks`](https://github.com/openshift-hyperfleet/hyperfleet-hooks) repository:

| Hook ID | Stage | Language | Description |
|---------|-------|----------|-------------|
| `hyperfleet-commitlint` | `commit-msg` | `golang` | Validates commit messages against the [HyperFleet Commit Standard](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/commit-standard.md) |
| `hyperfleet-golangci-lint` | `pre-commit` | `system` | Runs `make lint` — delegates to the repo's bingo-managed golangci-lint |
| `hyperfleet-gofmt` | `pre-commit` | `system` | Runs `make gofmt` — checks Go file formatting |
| `hyperfleet-go-vet` | `pre-commit` | `system` | Runs `make go-vet` — finds suspicious constructs in Go code |

The Go tooling hooks use `language: system` and delegate to existing Make targets rather than reimplementing tool resolution. This leverages each repo's [bingo](https://github.com/bwplotka/bingo)-managed tool versions (see [dependency pinning standard](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/dependency-pinning.md)).

### Secret Scanning Hook

**LeakTK** provides secret scanning to prevent credentials, API keys, and other secrets from being committed:

| Hook ID | Stage | Language | Description |
|---------|-------|----------|-------------|
| `leaktk.git.pre-commit` | `pre-commit` | `golang` | LeakTK: Scans staged files for secrets using Gitleaks engine with Red Hat-specific patterns |

**Key features**:
- ✅ **Open-source** — no VPN requirement, works for all contributors
- ✅ **Developed by Red Hat InfoSec** — same team that created rh-pre-commit
- ✅ **Gitleaks-powered** — uses proven secret detection patterns
- ⏱️ **First-time compilation** — takes 3-5 minutes on first commit, then cached

See the [Secret Scanning Migration](#secret-scanning-migration-rh-pre-commit-leaktk) section for migration details.

---

## Standard Configuration

All HyperFleet repositories **SHOULD** use the same `.pre-commit-config.yaml`. The Go tooling hooks (`gofmt`, `golangci-lint`, `go-vet`) use `types: [go]` filtering, so they only trigger when Go files are staged — in non-Go repos they are simply skipped.

```yaml
# .pre-commit-config.yaml
# Installs both pre-commit and commit-msg hooks with a single `pre-commit install`
default_install_hook_types: [pre-commit, commit-msg]

repos:
  # Secret scanning
  - repo: https://github.com/leaktk/leaktk
    rev: v0.3.2  # Check https://github.com/leaktk/leaktk/releases for latest
    hooks:
      - id: leaktk.git.pre-commit

  # HyperFleet code quality hooks
  - repo: https://github.com/openshift-hyperfleet/hyperfleet-hooks
    rev: v0.1.1  # pin to a specific tag
    hooks:
      - id: hyperfleet-commitlint
        stages: [commit-msg]
      - id: hyperfleet-gofmt
      - id: hyperfleet-golangci-lint
      - id: hyperfleet-go-vet

  # File hygiene
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
```

The file hygiene hooks (`trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`) catch common issues — trailing whitespace, missing final newlines, and accidentally committed large binaries — before they reach PR review.

> **Note:** `default_install_hook_types: [pre-commit, commit-msg]` means a single `pre-commit install` command installs hooks for **both** the `pre-commit` and `commit-msg` stages. Without this setting, you would need to run `pre-commit install --hook-type commit-msg` separately to enable commit message validation.

> **Important:** On the **first commit** after running `make install-hooks`, LeakTK will compile from source (3-5 minutes). Subsequent commits use the cached binary and run instantly.

---

## Migration Guide

This section covers two migration scenarios:
1. **Adding Pre-commit Hooks** — adding hooks to an existing HyperFleet repository
2. **Secret Scanning Migration** — migrating from rh-pre-commit to LeakTK

---

### Adding Pre-commit Hooks to a Repository

Follow these steps to add pre-commit hooks to an existing HyperFleet repository.

### Step 1: Add `.pre-commit-config.yaml`

Copy the [Standard Configuration](#standard-configuration) into a `.pre-commit-config.yaml` file in the repo root.

### Step 2: Add `install-hooks` Makefile target

Add the target to your Makefile (see [Makefile Conventions — Optional Targets](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/makefile-conventions.md#optional-targets)):

```makefile
.PHONY: install-hooks
install-hooks: ## Install pre-commit hooks
	pre-commit install
```

### Step 3: Add Make aliases for Go tooling hooks (Go repos only)

The Go tooling hooks expect `make gofmt` and `make go-vet` targets. If your repo uses different names (e.g., `fmt` and `vet`), add aliases:

```makefile
.PHONY: gofmt
gofmt: fmt ## Alias for fmt

.PHONY: go-vet
go-vet: vet ## Alias for vet
```

### Step 4: Update documentation

Add `pre-commit` to the prerequisites section in your `README.md`:

```markdown
### Prerequisites

- Go 1.25 or later
- Docker or Podman
- Make
- pre-commit
```

Add the hook installation step to your getting started section or `CONTRIBUTING.md`:

```markdown
### Getting Started

# ... existing steps ...

# Install git hooks
make install-hooks
```

### Step 5: Install and verify

```bash
make install-hooks
```

Test with valid commits (both formats are accepted):

```bash
git commit --allow-empty -m "test: verify pre-commit hooks"
git commit --allow-empty -m "HYPERFLEET-XXX - test: verify pre-commit hooks"
```

Test with an invalid commit (should fail):

```bash
git commit --allow-empty -m "bad commit message"
```

### Step 6: Fix existing violations

Run hooks against the entire codebase to fix any pre-existing violations (trailing whitespace, missing EOF newlines, etc.). Without this step, the first contributor who touches an unrelated file with a trailing whitespace or missing newline gets a hook failure they didn't cause.

```bash
pre-commit run --all-files
```

Review auto-fixes, stage them, and commit as a **separate companion PR** so the cleanup doesn't muddy the diff of the hook configuration PR:

```bash
git add -p
git commit -m "HYPERFLEET-XXX - chore: fix pre-commit baseline violations"
```

### Step 7: Commit the hook configuration

```bash
git add .pre-commit-config.yaml Makefile README.md CONTRIBUTING.md
git commit -m "HYPERFLEET-XXX - chore: add pre-commit hooks"
```

---

### Secret Scanning Migration: rh-pre-commit → LeakTK

#### Why Migrate to LeakTK?

[**LeakTK**](https://github.com/leaktk/leaktk) is an open-source secret scanning toolkit developed by Red Hat's Information Security team — the same team that created rh-pre-commit.

**Key benefits over rh-pre-commit**:
- ✅ **No VPN requirement** — works for Red Hat associates and external contributors
- ✅ **Open-source** — MIT licensed, publicly accessible on GitHub
- ✅ **Can be committed to repos** — configuration lives in repository files
- ✅ **Enforces on all developers** — configuration in repo ensures everyone uses it
- ✅ **Same detection engine** — both use Gitleaks with Red Hat-specific patterns (verified by InfoSec team)

#### Comparison: rh-pre-commit vs LeakTK

Both tools perform secret scanning using Gitleaks as the underlying engine. Here are the key differences:

| Feature | rh-pre-commit | LeakTK |
|---------|--------------|---------|
| **Secret scanning** | ✅ Gitleaks engine | ✅ Gitleaks engine |
| **Red Hat patterns** | ✅ Customized patterns | ✅ Customized patterns |
| **VPN required** | ⚠️ Only during installation | ❌ Never |
| **Open-source** | ❌ Internal Red Hat tool | ✅ Public GitHub repository |
| **Installation** | ✅ Pre-built binary | ⚠️ Compiles from source (first time only) |


#### Migration Steps

**Step 1: Ensure system requirements**

Verify that all team members have Go 1.25+ and btrfs-progs-devel installed:

```bash
go version  # Should show 1.25.0 or later

# Fedora/RHEL
sudo dnf install btrfs-progs-devel

# Ubuntu/Debian
sudo apt install libbtrfs-dev
```

Or via Homebrew on macOS:

```bash
brew install btrfs-progs
```

**Step 2: Update `.pre-commit-config.yaml`**

Replace the rh-pre-commit configuration with LeakTK:

```yaml
# Before (rh-pre-commit)
repos:
  - repo: https://gitlab.cee.redhat.com/infosec-public/developer-workbench/tools
    rev: rh-pre-commit-2.3.2
    hooks:
      - id: rh-pre-commit

# After (LeakTK)
repos:
  - repo: https://github.com/leaktk/leaktk
    rev: v0.3.2  # Check https://github.com/leaktk/leaktk/releases for latest
    hooks:
      - id: leaktk.git.pre-commit
```

**Step 3: Notify team**

Inform all developers that:
1. System requirements must be met (Go 1.25+, btrfs-progs-devel)
2. They should reinstall hooks: `make install-hooks`
3. The **first commit** will take 3-5 minutes (one-time compilation)
4. Subsequent commits will run instantly (cached binary)

**Step 4: Commit the migration**

```bash
git add .pre-commit-config.yaml
git commit -m "HYPERFLEET-XXX - chore: migrate from rh-pre-commit to LeakTK"
```

#### What Changes After Migration

**During development**:
```bash
# First commit after migration (one-time)
git commit -m "feat: add feature"
# LeakTK compiles (3-5 minutes), then scans
# ✅ Commit succeeds if no secrets found

# All subsequent commits
git commit -m "feat: another feature"
# LeakTK uses cached binary (instant)
```

**Example output when a secret is detected**:
```text
leaktk.git.pre-commit
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1 secret(s) detected in staged files                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ config/database.yml:12                                                      │
│ Password = "admin123"  # Generic Password                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

The commit will be blocked until secrets are removed.

---


## Troubleshooting

### `pre-commit: command not found`

Install the pre-commit framework:

```bash
pip install pre-commit
```

Or via Homebrew on macOS:

```bash
brew install pre-commit
```

### `make: *** No rule to make target 'gofmt'`

Your Makefile needs the `gofmt` alias. Add it pointing to your existing formatting target:

```makefile
.PHONY: gofmt
gofmt: fmt ## Alias for fmt
```

### LeakTK compilation fails with "Go version too old"

LeakTK requires Go 1.25+:

```bash
# Check version
go version

# Update (Fedora/RHEL)
sudo dnf update golang

# Or download from https://go.dev/dl/
```

### LeakTK compilation fails with "btrfs/ioctl.h: No such file or directory"

Install the btrfs development headers:

```bash
sudo dnf install btrfs-progs-devel
```

### First commit takes 3-5 minutes

This is **expected behavior** on the first commit after installing LeakTK. The pre-commit framework is compiling LeakTK from source. Subsequent commits will use the cached binary and run instantly.

### Hook runs but uses wrong tool version

Pre-commit caches hook environments. Clear the cache and reinstall:

```bash
pre-commit clean
pre-commit install
```

### Skipping hooks temporarily

In rare cases (e.g., merge commits), you can skip hooks:

```bash
git commit --no-verify -m "HYPERFLEET-123 - chore: merge conflict resolution"
```

Use this sparingly — CI will still validate the commit message on the PR.

### Updating hook versions

To pull the latest hook definitions:

```bash
pre-commit autoupdate
```

This updates the `rev` field in `.pre-commit-config.yaml` to the latest tag.

---

## References

### Related Standards

- [Commit Standard](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/commit-standard.md) — commit message format enforced by `hyperfleet-commitlint`
- [Makefile Conventions](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/makefile-conventions.md) — `install-hooks`, `gofmt`, and `go-vet` optional targets
- [Dependency Pinning](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/dependency-pinning.md) — bingo-managed tool versions used by Go hooks
- [Linting Standard](https://github.com/openshift-hyperfleet/architecture/blob/main/hyperfleet/standards/linting.md) — golangci-lint configuration

### External Resources

- [pre-commit documentation](https://pre-commit.com/)
- [hyperfleet-hooks repository](https://github.com/openshift-hyperfleet/hyperfleet-hooks)
- [Sentinel pilot PR (hyperfleet-sentinel#102)](https://github.com/openshift-hyperfleet/hyperfleet-sentinel/pull/102) — reference implementation
- [LeakTK GitHub Repository](https://github.com/leaktk/leaktk)
- [Git Hooks Installation Guide](https://github.com/leaktk/leaktk/blob/main/docs/install_git_hooks.md)
- [PR #248 - pre-commit.com integration](https://github.com/leaktk/leaktk/pull/248) ✅ Merged 2026-05-13
