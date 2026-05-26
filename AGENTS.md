# HyperFleet Architecture Repository

Documentation-only repository. Single source of truth for all HyperFleet architectural documentation. No application code.

## Validation

| Script | Checks |
|--------|--------|
| `./hack/markdownlint.sh` | Markdown formatting |
| `./hack/yamllint.sh` | YAML formatting |
| `./hack/linkcheck.sh` | Internal links |

Many markdownlint rules are disabled — see `.markdownlint-cli2.yaml` for the active set.

## Source of Truth

| Topic | Location |
|-------|----------|
| System architecture overview | `hyperfleet/README.md` |
| Component design docs | `hyperfleet/components/` |
| Component doc requirements | `hyperfleet/components/CLAUDE.md` |
| Engineering standards | `hyperfleet/standards/` |
| Standards doc requirements | `hyperfleet/standards/CLAUDE.md` |
| Implementation guides | `hyperfleet/docs/` |
| Architecture Decision Records | `hyperfleet/adrs/` (see `hyperfleet/adrs/README.md` for template) |
| Glossary / terminology | `hyperfleet/docs/glossary.md` |
| Document templates | `hyperfleet/docs/templates/` |
| Deprecated / archived docs | `hyperfleet/deprecated/` |

## Document Rules

### Metadata Header

Every document starts with:

```markdown
---
Status: Active
Owner: Team Name
Last Updated: YYYY-MM-DD
---
```

Update "Last Updated" only for meaningful changes (design decisions, new sections, trade-offs modified) — not typos or formatting.

### Status Filtering

**IMPORTANT:** Unless explicitly asked otherwise, ignore any document with Status other than `Active` or located under a `deprecated/` directory.

### Required Sections by Document Type

**Component docs** (`hyperfleet/components/`): MUST include Trade-offs AND Alternatives Considered sections. Full template and required section list in `hyperfleet/components/CLAUDE.md`.

**Standards docs** (`hyperfleet/standards/`): MUST follow Overview, Standard, Examples, Enforcement, References pattern with RFC 2119 language. Full details in `hyperfleet/standards/CLAUDE.md`.

### Diagrams

Use Mermaid syntax for new diagrams. Avoid adding image files; some legacy images exist.

### Writing Quality

Quantify architectural claims. See `README.md` Writing Guidelines for examples.

### Glossary

**IMPORTANT:** Before introducing new terms, check `hyperfleet/docs/glossary.md`. Add new terms in the same change.

## Gotchas

- Markdownlint is very lenient — 32+ rules disabled in `.markdownlint-cli2.yaml`. Don't assume formatting checks are comprehensive.
- Legacy PNG images exist in the repo despite Mermaid-first policy. Don't flag or delete them.
- Trade-offs, Alternatives Considered, and metadata header requirements are prompt-only — no mechanical validator exists yet. Easy to miss.

## Boundaries

### DO NOT

1. **Create code files** — documentation only, no exceptions
2. **Skip Trade-offs or Alternatives Considered** in component docs
3. **Create docs without metadata header** (`Status`, `Owner`, `Last Updated`)
4. **Use vague language** — quantify impact, be specific
5. **Put documents in wrong directories** — check Source of Truth table above
6. **Surface deprecated documents** unless explicitly asked

### DO

1. Read existing docs in target directory before creating new ones
2. Check glossary before introducing new terms
3. Use `hyperfleet/components/sentinel/sentinel.md` as reference example for component docs
4. Validate changes with `./hack/markdownlint.sh` and `./hack/yamllint.sh`
