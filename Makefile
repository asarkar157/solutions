# Local verification and CI entrypoints. Full context: README.md
# ("Local verification", "Continuous integration").

.PHONY: help fmt fmt-check opa-fmt opa-fmt-check opa-check validate check clean

SHELL := /bin/bash

# Prefer OpenTofu (`tofu`). Override for HashiCorp Terraform: `make TF=terraform …`
TF ?= $(shell command -v tofu >/dev/null 2>&1 && echo tofu || echo terraform)

TF_ROOT_SCRIPT := $(CURDIR)/scripts/terraform-validate-all.sh

help:
	@echo "AIOS modules — common targets (see README: Local verification)"
	@echo ""
	@echo "  TF=$(TF)  (default: tofu if installed, else terraform — set TF= to override)"
	@echo ""
	@echo "  make fmt            Format all .tf via $(TF)"
	@echo "  make fmt-check      CI-style format check ($(TF) fmt -check)"
	@echo "  make opa-fmt        Format all Rego (.rego) files"
	@echo "  make opa-fmt-check  Fail if Rego formatting differs (CI)"
	@echo "  make opa-check      opa check --v1-compatible on each .rego file (standalone policies)"
	@echo "  make validate       $(TF) init -backend=false && validate per module/example"
	@echo "  make check          fmt-check, opa-fmt-check, opa-check, validate"
	@echo "  make clean          remove .terraform caches under modules/ and examples/"
	@echo ""
	@echo "validate needs network; see README if dev_overrides force a minimal CLI config (then set TF_TOKEN_releases_stackgen_com)."

fmt:
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

validate:
	@chmod +x "$(TF_ROOT_SCRIPT)" 2>/dev/null || true
	@"$(TF_ROOT_SCRIPT)"

check: fmt-check opa-fmt-check opa-check validate

clean:
	@find modules examples -type d -name .terraform -prune 2>/dev/null | while read -r d; do \
	  echo "rm -rf $$d"; rm -rf "$$d"; \
	done; true
