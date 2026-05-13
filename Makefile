# Local verification and CI entrypoints. Full context: README.md
# ("Local verification", "Continuous integration").

.PHONY: help fmt fix-fmt fmt-check opa-fmt opa-fmt-check opa-check validate validate-db-state-split-templates verify-persona-length check clean

SHELL := /bin/bash

# Prefer OpenTofu (`tofu`). Override for HashiCorp Terraform: `make TF=terraform …`
TF ?= $(shell command -v tofu >/dev/null 2>&1 && echo tofu || echo terraform)

TF_ROOT_SCRIPT := $(CURDIR)/scripts/terraform-validate-all.sh

help:
	@echo "AIOS modules — common targets (see README: Local verification)"
	@echo ""
	@echo "  TF=$(TF)  (default: tofu if installed, else terraform — set TF= to override)"
	@echo ""
	@echo "  make fmt | fix-fmt  Format all .tf ($(TF) fmt -recursive; fixes fmt-check failures)"
	@echo "  make fmt-check      CI-style format check ($(TF) fmt -check -recursive)"
	@echo "  make opa-fmt        Format all Rego (.rego) files"
	@echo "  make opa-fmt-check  Fail if Rego formatting differs (CI)"
	@echo "  make opa-check      opa check --v1-compatible on each .rego file (standalone policies)"
	@echo "  make validate       $(TF) init -backend=false && validate per module/example + db-state-split tftpl smoke"
	@echo "  make verify-persona-length  Fail if (a) any modules/*/personas/**/*.md exceeds 15000 bytes (Guild's hard cap), or (b) any aios-agent-* module is missing _persona_guard.tf"
	@echo "  make check          fmt-check, opa-fmt-check, opa-check, verify-persona-length, validate"
	@echo "  make clean          remove .terraform caches under modules/ and examples/"
	@echo ""
	@echo "validate needs network; see README if dev_overrides force a minimal CLI config (then set TF_TOKEN_releases_stackgen_com)."

fmt fix-fmt:
	$(TF) fmt -recursive

fmt-check:
	$(TF) fmt -check -recursive

opa-fmt:
	@count=$$(find . -name '*.rego' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' '); \
	if [[ "$$count" -eq 0 ]]; then echo "No .rego files."; exit 0; fi; \
	find . -name '*.rego' -not -path './.git/*' -exec opa fmt -w {} +

opa-fmt-check:
	@count=$$(find . -name '*.rego' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' '); \
	if [[ "$$count" -eq 0 ]]; then echo "No .rego files."; exit 0; fi; \
	need=$$(find . -name '*.rego' -not -path './.git/*' -print0 | xargs -0 opa fmt -l 2>/dev/null || true); \
	if [[ -n "$$need" ]]; then echo "Rego needs formatting:"; echo "$$need"; exit 1; fi

opa-check:
	@chmod +x "$(CURDIR)/scripts/opa-check-all.sh" 2>/dev/null || true
	@"$(CURDIR)/scripts/opa-check-all.sh"

validate: validate-db-state-split-templates
	@chmod +x "$(TF_ROOT_SCRIPT)" 2>/dev/null || true
	@"$(TF_ROOT_SCRIPT)"

validate-db-state-split-templates:
	@chmod +x "$(CURDIR)/scripts/verify-db-state-split-templates.sh" 2>/dev/null || true
	@"$(CURDIR)/scripts/verify-db-state-split-templates.sh"

# verify-persona-length enforces two hard rules in one pass:
#   1. Guild's 15000-byte agent persona cap on every modules/*/personas/**/*.md.
#   2. Every aios-agent-* module that wires `persona = file(...)` ships a
#      sibling _persona_guard.tf with the canonical `terraform_data` precondition.
# See scripts/verify-persona-length.sh for rationale (the cap is enforced
# server-side; catching it pre-merge avoids tainted resources and cascading
# apply failures, and the per-module guard turns Guild's runtime 500 into a
# plan-time failure for module consumers).
verify-persona-length:
	@chmod +x "$(CURDIR)/scripts/verify-persona-length.sh" 2>/dev/null || true
	@"$(CURDIR)/scripts/verify-persona-length.sh"

check: fmt-check opa-fmt-check opa-check verify-persona-length validate

clean:
	@find modules examples -type d -name .terraform -prune 2>/dev/null | while read -r d; do \
	  echo "rm -rf $$d"; rm -rf "$$d"; \
	done; true
