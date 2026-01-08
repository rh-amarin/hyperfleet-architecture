# HyperFleet Makefile Conventions

This guide provides a standardized set of Makefile targets and conventions applicable to all HyperFleet repositories.

---

## Table of Contents

1. [Overview](#overview)
2. [Goals](#goals)
3. [Standard Targets](#standard-targets)
4. [Repository Type Variations](#repository-type-variations)
5. [Flag Conventions](#flag-conventions)
6. [References](#references)

---

## Overview

This document defines standard Makefile targets and conventions for all HyperFleet repositories. Following these conventions reduces cognitive load when switching between repos, enables consistent CI/CD pipelines, and improves developer onboarding.

### Scope

This standard applies to:
- All HyperFleet service repositories
- All adapter repositories (adapter-pullsecret, adapter-dns, etc.)
- Infrastructure and tooling repositories

### Problem Statement

Currently, different HyperFleet repositories use different target names for similar operations:
- Some use `make compile`, others use `make build` or `make binary`
- Binary output locations vary (some use `bin/`, others use project root)
- CI pipelines have inconsistent invocations across repos
- Engineers must read each Makefile to understand available commands

This inconsistency creates unnecessary friction and slows down development.

---

## Goals

1. **Reduce cognitive load** - Same commands work across all repos
2. **Enable automation** - CI/CD pipelines can use standard targets
3. **Improve onboarding** - New developers learn once, apply everywhere
4. **Increase reliability** - Consistent behavior reduces errors
5. **Support tooling** - Claude plugin and scripts can assume standard targets

---

## Standard Targets

### Required Targets

All HyperFleet repositories **MUST** implement these targets:

| Target | Description | Expected Behavior | Example Output |
|--------|-------------|-------------------|----------------|
| `help` | Display available targets | Print formatted list of targets with descriptions | Help text to stdout |
| `build` | Build all binaries | Compile source code to executable binaries | Outputs to `bin/` directory |
| `test` | Run unit tests | Execute all unit tests with coverage | Coverage report + pass/fail |
| `lint` | Run linters | Execute configured linters (golangci-lint, yamllint, etc.) | Linting violations or success |
| `clean` | Remove build artifacts | Delete all generated files (binaries, coverage, build cache) | Empty `bin/`, `build/` directories |

### Example invocation

```bash
make help           # See all available targets
make build          # Compile binaries
make test           # Run tests
make lint           # Run linters
make clean          # Clean up
```

### Optional Targets

Repositories **MAY** implement these targets if applicable:

| Target | Description | When to Use | Example |
|--------|-------------|-------------|---------|
| `generate` | Generate code from specifications | If repo uses code generation (OpenAPI, Protocol Buffers, etc.) | Generate Go models from OpenAPI specs |
| `test-all` | Run all tests and checks | Comprehensive pre-commit validation | Runs test + lint + test-integration + helm-test |
| `test-integration` | Run integration tests | If repo has integration tests requiring external dependencies | Tests against real GCP/K8s |
| `helm-test` | Run all Helm validation | If repo contains Helm charts | Runs helm-lint + helm-template |
| `image` | Build container image | If repo produces a container image | `make image IMAGE_TAG=v1.0.0` |
| `image-push` | Push container image to registry | If repo publishes to container registry | `make image-push` |
| `helm-lint` | Lint Helm charts | If repo contains Helm charts | Validate chart syntax |
| `helm-template` | Template Helm charts | If repo contains Helm charts | Render templates locally |
| `deploy` | Deploy to environment | If repo has deployment logic | Deploy to dev/staging |
| `run` | Run the application locally | For services that can run standalone | Start local server |

### Example invocation

```bash
make generate                   # Generate code from specs
make test-all                   # Run all tests and checks (recommended before commit)
make test-integration           # Run integration tests
make helm-test                  # Run all Helm validation (lint + template)
make image IMAGE_TAG=v1.0.0    # Build container image
make image-push                 # Push to registry
```

### Target Naming Rules

- Use **lowercase** with hyphens for multi-word targets (e.g., `test-integration`, not `integrationTest`)
- Use **verbs** for action targets (e.g., `build`, `test`, `clean`)
- Keep names **short** but descriptive (max 20 characters)
- Avoid abbreviations (use `test-integration`, not `int-test`)

---

### Binary Output Location

**Rule:** All compiled binaries **MUST** be output to the `bin/` directory.

```makefile
# Good - output to bin/ directory
# Example: go build -o bin/pull-secret ./cmd/pull-secret
build:
	go build -o bin/app-name ./cmd/app-name

# Bad - DO NOT output to project root
build:
	go build -o app-name ./cmd/app-name
```

### Temporary Files

| File Type | Location | Description |
|-----------|----------|-------------|
| Binaries | `bin/` | All compiled executables |
| Build artifacts | `build/` | Temporary build files, cache |
| Test coverage | `coverage.txt`, `coverage.html` | Coverage reports |
| Container images | N/A (tagged only) | Not stored locally after build |

**Important:** All temporary files should be in `.gitignore`:

```gitignore
# Build outputs
bin/
build/

# Test coverage
coverage.txt
coverage.html
coverage.out
*.coverprofile
```

---

## Repository Type Variations

Not all HyperFleet repositories build binaries. Helm-chart and deployment repositories have different build patterns but should still follow consistent conventions. This section documents equivalent targets for different repository types.

### Repository Types

| Type | Description | Examples |
|------|-------------|----------|
| **Service** | Repositories that compile Go binaries | adapter-pullsecret, sentinel |
| **Helm-chart** | Repositories containing only Helm charts for deployment | adapter-landing-zone |
| **Infrastructure** | Repositories with infrastructure-as-code (Terraform, scripts) | hyperfleet-infrastructure |
| **Documentation** | Repositories containing only documentation (Makefile not required) | hyperfleet-architecture |

### Target Equivalents for Helm-chart Repositories

Helm-chart repositories do not build binaries, so the standard required targets have different equivalents:

| Standard Target | Helm-chart Equivalent | Notes |
|-----------------|----------------------|-------|
| `build` | N/A | No binaries to build; not applicable for Helm-chart repositories |
| `test` | `helm-test` | Runs `helm-lint` + `helm-template` validation |
| `lint` | `helm-lint` | Validates chart syntax and best practices |
| `clean` | `helm-uninstall` or N/A | Removes installed releases; may be omitted if not applicable |
| `help` | `help` | Still required; lists available targets |

### Repository Type Indicator

To help tooling identify repository types, repositories **SHOULD** include a `.hyperfleet.yaml` file in the root directory. This file is preferred over GitHub Topics because it works offline, is version-controlled, and supports structured metadata:

```yaml
# .hyperfleet.yaml - Repository metadata for HyperFleet tooling
version: v1
repository:
  types: [helm-chart]  # List of repository types (see Repository Types table above)
  name: adapter-landing-zone
  description: Helm charts for adapter deployment landing zone
```

### Supported repository types

| Type | Value | Required Targets |
|------|-------|------------------|
| Service | `service` | `help`, `build`, `test`, `lint`, `clean` |
| Helm-chart | `helm-chart` | `help`, `helm-lint`, `helm-template`, `helm-test` |
| Infrastructure | `infrastructure` | `help`, `lint`, `clean` |
| Documentation | `documentation` | Makefile not required |

### Audit Tool Behavior

The standards-audit tool recognizes repository type variations:

1. **With `.hyperfleet.yaml`**: The tool reads the repository types and validates against the appropriate target sets
2. **Without `.hyperfleet.yaml`**: The tool defaults to `service` type and expects standard targets
3. **Auto-detection fallback**: If no `.hyperfleet.yaml` exists, the tool may infer type from:
   - Presence of `charts/` directory → `helm-chart`
   - Presence of `go.mod` → `service`
   - Presence of `terraform/` directory → `infrastructure`
   - Only `.md` files → `documentation`

> **Note:** Targets are additive. The repository types define the **minimum required targets**. A repository with multiple types must include the required targets for each type.

### Example: Service repository with Helm charts

A repository that builds binaries and also contains Helm charts would declare both types:

```yaml
# .hyperfleet.yaml
version: v1
repository:
  types: [service, helm-chart]  # Must satisfy required targets for both types
  name: my-adapter
  description: Adapter service with deployment charts
```

```makefile
# Required targets from 'service' type
help:           ## Show this help
build:          ## Build the binary
test:           ## Run tests
lint:           ## Run linters
clean:          ## Clean build artifacts

# Required targets from 'helm-chart' type
helm-lint:      ## Lint Helm charts
helm-template:  ## Render Helm templates
helm-test:      ## Run Helm tests
```

### Example audit output for Helm-chart repository

```plaintext
Repository: adapter-landing-zone
Types: [helm-chart] (from .hyperfleet.yaml)

Required Targets:
  ✓ help
  ✓ helm-lint
  ✓ helm-template
  ✓ helm-test

Optional Targets:
  ○ helm-uninstall (not found)
  ○ deploy (not found)

Status: COMPLIANT
```

---

## Flag Conventions

### Standard Variables

All Makefiles **SHOULD** support these environment variables:

| Variable | Default | Description | Example Usage |
|----------|---------|-------------|---------------|
| `VERBOSE` | `0` | Enable verbose output (1=enabled, 0=disabled) | `make build VERBOSE=1` |
| `IMAGE_TAG` | `latest` | Container image tag | `make image IMAGE_TAG=v1.0.0` |
| `IMAGE_REGISTRY` | (repo-specific) | Container registry URL | `make image IMAGE_REGISTRY=quay.io/hyperfleet` |
| `GOOS` | (host OS) | Target operating system for build | `make build GOOS=linux` |
| `GOARCH` | (host arch) | Target architecture for build | `make build GOARCH=amd64` |
| `CGO_ENABLED` | `0` | Enable/disable CGO | `make build CGO_ENABLED=1` |

### Boolean Flag Convention

Use `1` for true, `0` for false:

```makefile
VERBOSE ?= 0

ifeq ($(VERBOSE),1)
    GO_FLAGS += -v
    Q =
else
    Q = @
endif

build:
	$(Q)echo "Building..."
	$(Q)go build $(GO_FLAGS) -o bin/app-name ./cmd/app-name
```

### Variable Definition Pattern

Always use `?=` for variables that can be overridden:

```makefile
# Good - allows override
IMAGE_TAG ?= latest
VERBOSE ?= 0

# Bad - cannot override
IMAGE_TAG = latest
```

---

## References

### External Resources

- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- [Makefile Best Practices](https://tech.davis-hansson.com/p/make/)
- [Self-Documented Makefiles](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html)

