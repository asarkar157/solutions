Skill: Scaffold a brand-new demo scenario under `examples/scenarios/<scenario_slug>/` that matches the conventions of the existing scenarios, register it with `scripts/demo.sh`, append a row to the `docs/se-playbook.md` "Prospect-question → scenario" table, and validate it with `tofu fmt` + `tofu validate`. This is the only place this agent is allowed to write files into the repo.

Keywords for skill discovery: scaffold, examples/scenarios, demo scenario, main.tf, variables.tf, outputs.tf, terraform.tfvars.example, README.md, tofu fmt, tofu validate, scripts/demo.sh, scenario_pitch, se-playbook.

Prerequisites (all populated by `scenario-triage-sop`):
- `repo_clone_path`, `scenario_slug`, `pitch_quote`, `gap_rationale`, `requested_modules`, `valid_modules`, `unknown_modules`, `module_signatures`, `requested_integrations`, `talk_track`, `demo_length`, `issue_details`, `gh_token`, `available_integrations`.

Tool boundary: this entire skill runs inside the `scaffold-write-and-validate` Ubuntu CLI subagent (orchestration SOP Template C). All commands use `ubuntu-cli_execute_command|series|parallel`.

========================================================================
0) Bootstrap — ensure tofu / git are on PATH
========================================================================

The triage stage's `triage-clone` subagent installs `gh`, `git`, and `tofu` (Template B step 0). When this scaffold subagent runs in the SAME sandbox they should already exist, but the sandbox is not guaranteed to persist across subagent boundaries.

a) `export PATH="$HOME/.local/bin:$PATH"`.
b) `which tofu || which terraform` — at least one must be present. If both are missing, re-run Template B step 0c inline (OpenTofu installer with the standalone fallback). Persist `iac_binary=tofu` or `iac_binary=terraform`.
c) `which git` — must succeed. If missing, persist `bootstrap_blocker="git_missing"` and STOP (orchestration §6(f)).
d) `cd <repo_clone_path>` (always — never run scaffold commands from outside the clone).

========================================================================
1) Bootstrap the working directory
========================================================================

a) `cd <repo_clone_path>` (step 0d).
b) `mkdir -p examples/scenarios/<scenario_slug>` — if the directory already exists, STOP and note `scaffold_blocker="conflict"`. The planner converts this to §6(e).
c) Resolve module relative paths from inside `examples/scenarios/<scenario_slug>/` → `../../../modules/<aios-*>`. Use this prefix everywhere in `main.tf`.
d) If `valid_modules` is empty (every entry in `requested_modules` was unknown), persist `scaffold_blocker="all_modules_unknown"` and STOP. Without a real module to wire, scaffolding a demo is impossible — the final issue comment surfaces `unknown_modules` so the SE knows to fix the names.

========================================================================
2) Write `examples/scenarios/<scenario_slug>/main.tf`
========================================================================

Structure (mirror `examples/scenarios/aws-sre-demo/main.tf` exactly):

```hcl
# =============================================================================
# Scenario: <scenario_slug>
# =============================================================================
# Pitch: <one-line summary of pitch_quote — keep it under ~80 chars>
# Generated from issue #<issue_or_pr_number> via the scenario-author bot.
# Talk track lives in ./README.md.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

module "foundation" {
  source = "../../../modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../../modules/aios-policies"

  create_policies = {
    azure_tool_governance  = false
    google_tool_governance = false
    langfuse_observability = false
  }
}

# Integrations — one block per integration in requested_integrations.
# Required integrations are unconditional. Optional ones are gated on a
# non-empty token/role-ARN variable using `count`.
<INTEGRATION_BLOCKS>

# Agents — one block per entry in requested_modules.
# Wire `model_names = module.foundation.model_names` and the subset of
# `policy_ids` each module documents in its variables.tf.
<AGENT_BLOCKS>
```

Rules for `<INTEGRATION_BLOCKS>` (use `available_integrations` AS the universe of valid integration names — skip anything in `requested_integrations` that is not in `available_integrations`):

- For each `name → required` entry in `requested_integrations` (where `name` is in `available_integrations`): emit a `module "<name>_integration"` block sourced from `../../../modules/aios-integration-<name>`. Determine the integration's required variables by grepping `modules/aios-integration-<name>/variables.tf` once for `^variable\s+"[^"]+"` and matching against the canonical credential names below:
    | integration | likely required vars |
    |-------------|-----------------------|
    | aws         | `aws_role_arn`, `aws_region` |
    | azure       | `azure_subscription_id`, `azure_tenant_id`, `azure_client_id`, `azure_client_secret` |
    | gcp         | `gcp_service_account_key` (or `gcp_credentials_json`) |
    | github      | `github_token` |
    | slack       | `slack_bot_token`, optional `slack_signing_secret`, `slack_webhook_url` |
    | grafana     | `grafana_server`, `grafana_token` |
    | linear      | `linear_api_key` |
    | clickhouse  | `clickhouse_url`, `clickhouse_user`, `clickhouse_password` |
    | ubuntu      | (none) |
    | cursor      | `cursor_api_key` |
  When the actual `variables.tf` declares a variable not in the table above, pass it through as `<name> = var.<name>` and declare the matching root variable in step 3 with `default = ""`. Always prefer reading from the file over relying on the table — the table is a safety net for missing declarations.
- For each `name → optional` entry: emit the same block but with `count = trimspace(var.<primary-credential>) != "" ? 1 : 0` so demos run even when the SE has not supplied that credential. `<primary-credential>` is the first required variable from the table (e.g. `aws_role_arn`, `slack_bot_token`, `github_token`).
- For each `name → skipped` entry: emit NOTHING (a one-line `# <name> integration: skipped (prospect doesn't have it)` comment is OK).
- The `examples/scenarios/aws-sre-demo/main.tf` file is the canonical example — match its style for `count` / `source` / argument names.

Rules for `<AGENT_BLOCKS>` (drive emission from `module_signatures[m]` — NEVER guess shapes):

For each module `<m>` in `valid_modules`:

a) Emit `module "<local_name>" {` where `<local_name>` is `<m>` with the leading `aios-agent-` stripped and dashes converted to underscores (e.g. `aios-agent-cost-optimizer` → `cost_optimizer`).
b) `source = "../../../modules/<m>"`.
c) Always pass `model_names = module.foundation.model_names`.
d) `policy_ids` emission depends on `module_signatures[<m>].policy_type`:
    - `policy_type == "object"`: emit a literal `policy_ids = { <key> = module.policies.policy_ids.<key>, ... }` containing EXACTLY the keys in `module_signatures[<m>].policy_keys`. If a key is not in `module.policies.policy_ids` (i.e. it's not produced by `aios-policies`), emit it as a TODO comment AND `null` placeholder, and add it to the PR body's "Reviewer checklist".
    - `policy_type == "map"`: emit `policy_ids = module.policies.policy_ids` (pass the whole map).
    - `policy_type == "none"`: omit the line entirely.
e) Integration variable emission depends on `module_signatures[<m>].integration_var`:
    - `"integration_name"` (singular string): pick the FIRST integration `name → required` entry from `requested_integrations` whose `name` is in `available_integrations` AND in `module_signatures[<m>].integration_keys` (or — when `integration_keys` is empty — the FIRST required entry that intuitively matches the module's name, e.g. `aws-sre` → `aws`). Emit `integration_name = module.<name>_integration.integration_name`. If the integration was optional (count-gated), wrap the WHOLE agent module in `count = length(module.<name>_integration) > 0 ? 1 : 0`.
    - `"integration_names"` (plural object): emit an object literal containing one entry per key in `module_signatures[<m>].integration_keys`. For each key, pick the matching integration from `requested_integrations`. If the integration is required and `count`-gated, use `module.<key>_integration.integration_name`; if `count`-gated AND optional, use `try(module.<key>_integration[0].integration_name, "")` so the module still type-checks. If a required key has no matching integration in `requested_integrations`, emit a TODO comment + `""` placeholder and add it to the PR body's "Reviewer checklist".
    - `"none"`: omit the integration line entirely.
f) For every name in `module_signatures[<m>].extra_required` (other required vars the bot does not know how to wire), emit `# TODO: required var "<name>" — fill in before applying` on a comment line and leave the value unset (causing `tofu validate` to flag the missing required input — that's intentional, the human reviewer needs to see it). Also add each such name to the PR body's "Reviewer checklist".
g) Close the block with `}`.

Unknown modules: anything in `unknown_modules` is skipped entirely from `<AGENT_BLOCKS>`. Do NOT emit a placeholder `module ""` block — `tofu validate` would fail on the empty name. Surface the names in the PR body's "Reviewer checklist" (Step 6, "Unknown modules") so a human can fix them.

========================================================================
3) Write `examples/scenarios/<scenario_slug>/variables.tf`
========================================================================

Declare every variable referenced from `main.tf`. Mirror the variable names + descriptions used in `examples/scenarios/aws-sre-demo/variables.tf` for the common ones (`stackgen_url`, `stackgen_token`, `stackgen_project_id`, `openai_api_key`, `anthropic_api_key`, `gemini_api_key`). Add per-integration variables (e.g. `aws_role_arn`, `aws_region`, `slack_bot_token`, `github_token`, `grafana_server`, `grafana_token`) only for integrations that appear in `requested_integrations`.

Required defaults:
- `stackgen_url`, `stackgen_token`, `openai_api_key` → no default (caller must supply).
- `stackgen_project_id`, `aws_region`, `anthropic_api_key`, `gemini_api_key`, optional integration tokens → default `""`.
- Mark every secret-ish variable `sensitive = true` (tokens, API keys, role ARNs).

========================================================================
4) Write `examples/scenarios/<scenario_slug>/outputs.tf`
========================================================================

Output structure (mirror existing scenarios):

```hcl
output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT
    1. Open Guild at ${var.stackgen_url}
    2. Find the agents created below in the agent registry.
    3. Run the demo per ./README.md "Talk track".
  EOT
}

output "agent_names" {
  description = "Agents created by this scenario."
  value = {
    <one entry per agent module, e.g. cost_optimizer = try(module.cost_optimizer.agent_names.cost_optimizer, null)>
  }
}

output "scenario_summary" {
  description = "One-line scenario summary for SE call notes."
  value       = "<scenario_slug>: <first 80 chars of pitch_quote>"
}
```

========================================================================
5) Write `examples/scenarios/<scenario_slug>/terraform.tfvars.example`
========================================================================

One line per variable declared in step 3, with `# <description>` comments and placeholder values. Required variables get a placeholder like `"REPLACE_ME"`; optional variables get `""`.

========================================================================
6) Write `examples/scenarios/<scenario_slug>/README.md`
========================================================================

Sections (mirror existing scenarios; the bot will be reviewed against this layout):

```md
# Scenario: <scenario_slug>

Generated from issue #<issue_or_pr_number> by the scenario-author bot. Reviewed
by the scenario owner listed in `CONTRIBUTORS-SE.md`.

## Pitch

> <pitch_quote — the prospect's words, verbatim if possible>

## What this scenario wires

<bullet list of modules wired, with one-line purpose per module>

## Run

```bash
make demo SCENARIO=<scenario_slug>
# or directly:
cd examples/scenarios/<scenario_slug>
cp terraform.tfvars.example terraform.tfvars   # edit with your creds
tofu init && tofu apply
```

## Talk track (~<demo_length>)

<numbered list, one per entry in talk_track>

## Reset between demos

```bash
make demo-reset SCENARIO=<scenario_slug>
```

## Adjusting / extending

Edit `main.tf` to swap modules or change integration wiring. See
`docs/se-playbook.md` for the prospect-question → scenario map.
```

========================================================================
7) Register the scenario in `scripts/demo.sh`
========================================================================

Open `<repo_clone_path>/scripts/demo.sh`. Locate the `scenario_pitch()` shell function. Append exactly one new case clause inside it (preserving alphabetical order of `<scenario_slug>` against the existing entries):

```sh
    <scenario_slug>)
      printf '%s\n' '<first 80 chars of pitch_quote>'
      ;;
```

a) Splice with `sed -i.bak '/<anchor>/i\    ...'` or python with a literal-string splice. NEVER rewrite the whole file.
b) **Validate the splice did not corrupt the script**: `bash -n <repo_clone_path>/scripts/demo.sh`.
    - Non-zero exit → the splice produced invalid shell syntax. Revert by `mv <repo_clone_path>/scripts/demo.sh.bak <repo_clone_path>/scripts/demo.sh` and retry the splice ONCE with a different anchor (e.g. just before the closing `esac` of `scenario_pitch()`).
    - Second `bash -n` failure → revert again, note `scaffold_blocker="demo_sh_corrupted"`, and continue WITHOUT staging `scripts/demo.sh`. The PR will mention this in the reviewer checklist so a human appends the entry manually.
c) Confirm the registry pickup: `<repo_clone_path>/scripts/demo.sh list | rg '<scenario_slug>'` should print the new line. If it does not but `bash -n` was happy, the case clause is in the wrong function — revert and retry the splice once with a different anchor. After success, `rm <repo_clone_path>/scripts/demo.sh.bak`.

========================================================================
7b) Register the scenario in `docs/se-playbook.md`
========================================================================

Open `<repo_clone_path>/docs/se-playbook.md`. Locate the "Prospect-question → scenario" table (it has the header row `| The prospect said… | Run | Why it lands |`). Append exactly one new row at the END of the table (before the next markdown heading, NOT in the middle of the alphabetized rows — the existing rows are story-ordered, not alphabetical):

```md
| "<first ~80 chars of pitch_quote, in quotes>" | **`<scenario_slug>`** | <one-liner: which modules wire + which integrations + ideal length>. |
```

a) Use `awk` or `sed` to insert the line. Match the anchor by finding the LAST line of the existing table (the row before the blank line that follows the table). Example with `sed`:
   `LAST_TABLE_LINE=$(awk '/^\|.*\|.*\|.*\|$/ {n=NR} END{print n}' docs/se-playbook.md)`
   `sed -i.bak "${LAST_TABLE_LINE}a | \"<pitch>\" | \*\*\`<slug>\`\*\* | <why>. |" docs/se-playbook.md`
   `rm docs/se-playbook.md.bak`.
b) **Validate the splice did not break the markdown**: count rows before/after with `rg -c '^\|.*\|.*\|.*\|$' docs/se-playbook.md`. The "after" count must be exactly "before + 1".
    - If the count is wrong, revert with `mv docs/se-playbook.md.bak docs/se-playbook.md` (or `git checkout HEAD -- docs/se-playbook.md`) and retry ONCE. On second failure, note `scaffold_blocker="playbook_corrupted"` and continue WITHOUT staging `docs/se-playbook.md` — the PR body's reviewer checklist must mention this.

Why a row update is needed: the issue template's Acceptance checklist requires "Mentioned in `docs/se-playbook.md` 'Prospect-question → scenario' table". Pre-bot, humans had to do this in a follow-up PR; the bot eliminates that round-trip.

========================================================================
8) Validate
========================================================================

Use the IaC binary discovered in step 0b (`iac_binary` note: `tofu` or `terraform`). Alias for readability: `IAC=$(command -v tofu || command -v terraform)`.

a) `cd <repo_clone_path>/examples/scenarios/<scenario_slug>`
b) `"$IAC" fmt -recursive .` (always — silences formatting nits in the PR).
c) `"$IAC" init -backend=false -input=false` — should succeed offline because every module source is local (`../../../modules/...`).
d) `"$IAC" validate -no-color` — capture the full output.
    - On success: persist `validation_summary="ok: fmt + init + validate clean"` (also include the IaC binary name so the PR reviewer knows which one).
    - On failure: ONE retry attempt is allowed. Re-read the error, apply the single most obvious fix (typo in a module variable, missing required var, mis-spelled output reference, integration block referenced from `<AGENT_BLOCKS>` but not emitted because it was `skipped`). Re-run `"$IAC" fmt` + `"$IAC" validate`. If the second run still fails, persist `validation_summary="failed: <first ~400 chars of error>"` and continue — do NOT loop.
e) Repeat step 8 from `<repo_clone_path>` root (not from inside the scenario dir) using `"$IAC" fmt -recursive scripts` is NOT necessary — scripts are Bash, not HCL. Only fmt the new scenario directory.

Forbidden: `tofu plan` / `terraform plan` (this scenario points at a real Guild tenant and would mutate it), `tofu apply` / `terraform apply` (same), `tofu destroy` / `terraform destroy`, any IaC command that writes state.

========================================================================
9) Persist scaffolding evidence
========================================================================

note `scaffold_summary` with:
- `scenario_slug`
- `files_created`: list of repo-relative paths the bot wrote / appended to (must include the 5 scenario files + `scripts/demo.sh` + `docs/se-playbook.md`, MINUS any of those for which a `scaffold_blocker:*` was recorded).
- `modules_wired`: the entries from `valid_modules` that ended up in `<AGENT_BLOCKS>`.
- `integrations_branched`: `required` vs `optional` vs `skipped` per integration.
- `unknown_modules_skipped`: the list from `unknown_modules` (for the PR's reviewer checklist).
- `validation_outcome`: short copy of `validation_summary`.
- `iac_binary`: `tofu` or `terraform`.

Also re-note `validation_summary` if you have not already. Keep `scaffold_summary` and `validation_summary` under ~1500 chars each so they fit in the PR body without truncation.

The `scaffold-pr` subagent reads both notes plus `unknown_modules` + any `scaffold_blocker:*` to compose the PR body's "Reviewer checklist" section.
