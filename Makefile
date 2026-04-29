.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:[^#]*## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":[^#]*## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: install-hooks
install-hooks: ## Install pre-commit hooks
	pre-commit install
