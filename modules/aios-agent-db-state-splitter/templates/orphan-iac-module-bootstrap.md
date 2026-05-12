Skill: **Secondary pipeline** — turn **`orphans_bundle`** into a **new reusable Terraform module** (or thin wrapper), validate, and hand results back to the primary split workflow.

Keywords: orphan resources, new module, terraform test, scaffold, stackgen register, pull request, modularization memory.

## Intake

1. Read `secondary_workflow_payload` / `orphans_bundle` (required inputs to this workflow).
2. Classify orphans: `network_shared`, `iam_shared`, `unmapped_vendor_resource`, `legacy_json`, `data_only`, etc.

## Scaffold

1. Create `modules/<proposed_name>/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md` (minimal contract).
2. Prefer **import blocks** pulling orphan addresses into clean resource names.
3. Add `tests/` with `command = plan` hermetic tests (see `terraform-install-validate-test-sop` pattern from terraform-bot module).

## Validate

1. `tofu fmt`, `init`, `validate`, `plan`, optional `tfsec`/`checkov` soft-fail.

## Memory

1. Append to **`orphan_modularization_memory`** (note): taxonomy decision tree used, naming convention, why resources were grouped together, and what still requires human ownership.

## Handoff

1. Open PR or emit `notify` with module path + test evidence.
2. If StackGen registration is required, follow org’s `stackgen register` SOP (reuse terraform-bot registration skill when available).
