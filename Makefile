# Local verification and CI entrypoints. Full context: README.md
# ("Local verification", "Continuous integration").

.PHONY: help fmt fix-fmt fmt-check opa-fmt opa-fmt-check opa-check validate validate-db-state-split-templates verify-persona-length verify-workflow-stage-bindings check clean demo demo-list demo-doctor demo-reset

SHELL := /bin/bash

# Prefer OpenTofu (`tofu`). Override for HashiCorp Terraform: `make TF=terraform …`
TF ?= $(shell command -v tofu >/dev/null 2>&1 && echo tofu || echo terraform)

TF_ROOT_SCRIPT := $(CURDIR)/scripts/terraform-validate-all.sh

help:
	@echo "AIOS modules — common targets (see README: Local verification)"
	@echo ""
	@echo "  TF=$(TF)  (default: tofu if installed, else terraform — set TF= to override)"
	@echo ""
	@echo "  SE-facing targets (pre-sales demos, see docs/se-playbook.md):"
	@echo "    make demo-list                Available scenarios with their prospect pitch"
	@echo "    make demo-doctor [SCENARIO=…] Check tools + env vars before applying"
	@echo "    make demo SCENARIO=<name>     tofu init && apply examples/scenarios/<name>"
	@echo "    make demo-reset SCENARIO=…    tofu destroy then re-apply (between demos)"
	@echo ""
	@echo "  Build / CI targets:"
	@echo "    make fmt | fix-fmt  Format all .tf ($(TF) fmt -recursive; fixes fmt-check failures)"
	@echo "    make fmt-check      CI-style format check ($(TF) fmt -check -recursive)"
	@echo "    make opa-fmt        Format all Rego (.rego) files"
	@echo "    make opa-fmt-check  Fail if Rego formatting differs (CI)"
	@echo "    make opa-check      opa check --v1-compatible on each .rego file (standalone policies)"
	@echo "    make validate       $(TF) init -backend=false && validate per module/example + db-state-split tftpl smoke"
	@echo "    make verify-persona-length  Fail if (a) any modules/*/personas/**/*.md exceeds 15000 bytes (Guild's hard cap), or (b) any aios-agent-* module is missing _persona_guard.tf"
	@echo "    make verify-workflow-stage-bindings  Fail if sg_workflow stage_bindings would trip WORKFLOW_HAS_UNBOUND_STAGE (webhook/schedule readiness)"
	@echo "    make check          fmt-check, opa-fmt-check, opa-check, verify-persona-length, verify-workflow-stage-bindings, validate"
	@echo "    make clean          remove .terraform caches under modules/ and examples/"
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

validate: validate-db-state-split-templates validate-terraform-bot-workflow-scripts
	@chmod +x "$(TF_ROOT_SCRIPT)" 2>/dev/null || true
	@"$(TF_ROOT_SCRIPT)"

validate-db-state-split-templates:
	@chmod +x "$(CURDIR)/scripts/verify-db-state-split-templates.sh" 2>/dev/null || true
	@"$(CURDIR)/scripts/verify-db-state-split-templates.sh"

validate-terraform-bot-workflow-scripts:
	@chmod +x "$(CURDIR)/scripts/verify-terraform-bot-workflow-scripts.sh" 2>/dev/null || true
	@"$(CURDIR)/scripts/verify-terraform-bot-workflow-scripts.sh"

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

verify-workflow-stage-bindings:
	@chmod +x "$(CURDIR)/scripts/verify-workflow-stage-bindings.py" 2>/dev/null || true
	@python3 "$(CURDIR)/scripts/verify-workflow-stage-bindings.py"

check: fmt-check opa-fmt-check opa-check verify-persona-length verify-workflow-stage-bindings validate

clean:
	@find modules examples -type d -name .terraform -prune 2>/dev/null | while read -r d; do \
	  echo "rm -rf $$d"; rm -rf "$$d"; \
	done; true

# -----------------------------------------------------------------------------
# Solutions-engineer demo targets (see docs/se-playbook.md)
# -----------------------------------------------------------------------------
# These targets wrap scripts/demo.sh so SEs can launch / reset prospect demos
# with one command. Set credentials as environment variables (the script maps
# STACKGEN_URL etc. to TF_VAR_*); see the header of scripts/demo.sh for the
# full list.

DEMO_SCRIPT := $(CURDIR)/scripts/demo.sh

demo-list:
	@chmod +x "$(DEMO_SCRIPT)" 2>/dev/null || true
	@"$(DEMO_SCRIPT)" list

demo-doctor:
	@chmod +x "$(DEMO_SCRIPT)" 2>/dev/null || true
	@"$(DEMO_SCRIPT)" doctor $(SCENARIO)

demo:
	@chmod +x "$(DEMO_SCRIPT)" 2>/dev/null || true
	@if [ -z "$(SCENARIO)" ]; then \
	  echo "error: SCENARIO is required (try: make demo-list)"; exit 2; \
	fi
	@"$(DEMO_SCRIPT)" apply "$(SCENARIO)"

demo-reset:
	@chmod +x "$(DEMO_SCRIPT)" 2>/dev/null || true
	@if [ -z "$(SCENARIO)" ]; then \
	  echo "error: SCENARIO is required (try: make demo-list)"; exit 2; \
	fi
	@"$(DEMO_SCRIPT)" reset "$(SCENARIO)"
