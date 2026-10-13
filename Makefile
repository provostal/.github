.DEFAULT_GOAL := help

.PHONY: help workflows/lint

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_\/.-]+:.*?## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

workflows/lint: ## Lint the workflows with actionlint (brew install actionlint)
	actionlint
