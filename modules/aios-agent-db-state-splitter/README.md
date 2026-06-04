# aios-agent-db-state-splitter

Guild agent plus **skills** (`sg_runbook_sop`) and **two workflows** for splitting a **monolithic Terraform/OpenTofu state** that may span **AWS, Azure, and GCP** into **logical resource groups** (tags, module paths, `grouping_policy_json`), optional **per-group TF roots / backends**, **multiple StackGen AppStacks** (via **StackGen MCP** when configured), **reverse-engineered IaC**, **registry + StackGen type mapping**, **orphan** handling through a **secondary** workflow, and **convergence loops** on resource counts and plans (including StackGen **Plan** action runs).

## Requirements

- **StackGen provider** `>= 0.1.25` (this module; includes `sg_remote_runner` install commands via nested `aios-remote-runner`, `sg_agent.auto_approve_tools`, `sg_agent.remote_runners`, and adopt-on-conflict for bundles/models/workflows).
- `module.foundation.model_names` and `module.policies.policy_ids.dangerous_ops` (typical stack).
- **`modules/aios-integration-github`**, **`modules/aios-integration-ubuntu`**, and **`modules/aios-integration-aws`** (or any equivalent `sg_guild_integration` of `type = "aws"`) are all **required**. Pass their `integration_name` outputs as `integration_names.github`, `integration_names.ubuntu_cli`, and `integration_names.aws`.
- **StackGen MCP Guild integration is required** (same pattern as `aios-agent-repo-to-iac`) — pass `stackgen_mcp_integration_name`. This enables AppStack tools (`create_appstack`, `bulk_add_resources_to_appstack`, `bulk_connect_resources_in_appstack`, `create_appstack_action_run`, env profiles, snapshots, etc.; see **`stackgen-appstack-mcp-playbook-sop`**). **`db-state-split-architect`** uses **`sg_agent.auto_approve_tools`** with **`tool = "<integration_name>_*"`** (for example **`stackgen-mcp_*`**) for Consumer MCP tools, plus intervention policy **`db-state-split-stackgen-mcp-auto-approve`** (`policies/stackgen-mcp-auto-approve.rego`). Lookup tools (`web_search`, `note`, `read_notes`) stay in **`hitl.always_allowed`**. The `materialize-stackgen-appstacks` stage and the `db-monorepo-state-split-evidence` checklist both assume StackGen MCP is attached — there is no longer a TF-only mode.

## Operator prerequisites (outside Terraform)

- **`monolith_state_uri` / `iac_repository_url`** are workflow inputs when you start **`db-monorepo-state-split-convergence`** in Guild — not variables on this module. The **Ubuntu CLI** (or **remote runner**) environment must be able to **fetch** state and **clone** the repo (git tokens, cloud SDK auth, VPC egress to S3/GCS, etc.). The `gh api` GitHub integration is for **metadata only** — actual `git clone` happens inside the Ubuntu container and needs **env-mounted git credentials** (see "Git connectivity" below).
- **AWS connectivity for `tofu plan`.** Passing `integration_names.aws` attaches the AWS Guild integration (`aws_cli_*` MCP tools), but `tofu plan -generate-config-out=` and `tofu plan` use the **`hashicorp/aws`** provider inside the **Ubuntu** container — they need AWS credentials in that container's environment, not as MCP tools. Wire a read-only AWS secret onto the Ubuntu integration's `secret_ref_ids`:

  ```hcl
  resource "sg_secret" "ubuntu_aws_readonly" {
    name        = "ubuntu-cli-aws-readonly"
    description = "Read-only AWS credentials for tofu plan / state download inside the Ubuntu MCP."
    category    = "CloudProvider"
    subcategory = "aws"

    metadata = {
      AWS_ACCESS_KEY_ID     = var.aws_readonly_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_readonly_secret_access_key
      AWS_REGION            = var.aws_region
      AWS_DEFAULT_REGION    = var.aws_region
    }
  }
  ```

  Then either (a) define the Ubuntu `sg_guild_integration` directly in your root with `secret_ref_ids = [sg_secret.ubuntu_aws_readonly.id]`, or (b) extend `modules/aios-integration-ubuntu` with an `extra_secret_ref_ids` variable. The AWS managed policy `ReadOnlyAccess` is sufficient for everything the workflow does; narrower policies must include `s3:GetObject` on the state bucket plus read on every resource type present in the monolith state.
- **Git connectivity for `git clone iac_repository_url`.** Same pattern as AWS — the GitHub Guild integration only powers `gh api` MCP tools, but **`git clone` / `git fetch` / `git push`** run inside the **Ubuntu** container and need credentials in that container's **env**. Wire a read-only git secret onto the Ubuntu integration's `secret_ref_ids`:

  ```hcl
  resource "sg_secret" "ubuntu_git" {
    name        = "ubuntu-cli-git-token"
    description = "Git access token (HTTPS) for cloning IaC repos inside the Ubuntu MCP."
    category    = "Provider"
    subcategory = "github" # or "gitlab", "bitbucket", "generic-git"

    metadata = {
      # HTTPS token auth (preferred — works with GitHub, GitLab, Bitbucket, Azure DevOps).
      # The SOPs instruct the agent to clone with:
      #   git clone https://x-access-token:${GIT_TOKEN}@${GIT_HOST}/<org>/<repo>.git
      # so any token-bearing variable name works as long as the agent is told which one.
      GIT_TOKEN    = var.git_readonly_token
      GIT_HOST     = "github.com"             # repo host (no scheme)
      GIT_USERNAME = "x-access-token"         # GitHub/GitLab token-as-password convention
      # Optional fine-grained PAT scopes (GitHub): `repo:read`, `metadata:read`. For read-only
      # state-split work you do NOT need `repo:write` or `workflow` — least privilege.
    }
  }
  ```

  For SSH-key auth instead of HTTPS tokens, mount `GIT_SSH_PRIVATE_KEY` (PEM body) and `GIT_SSH_KNOWN_HOSTS` and the agent will write them to `~/.ssh/` with `chmod 600` before cloning. For multi-host setups (mixed GitHub + GitLab + internal git), repeat the secret with per-host metadata (e.g. `GIT_TOKEN_GITHUB`, `GIT_HOST_GITHUB`, `GIT_TOKEN_GITLAB`, `GIT_HOST_GITLAB`) — the SOPs match on the host parsed from `iac_repository_url`.

  Wire the secret in the same two ways as the AWS one: (a) define the Ubuntu `sg_guild_integration` in your root with `secret_ref_ids = [sg_secret.ubuntu_git.id, sg_secret.ubuntu_aws_readonly.id]`, or (b) extend `modules/aios-integration-ubuntu` with an `extra_secret_ref_ids` variable that fans both in. If the repo also needs to be written back to (PR creation for `orphan-iac-module-authoring`), the token must have `repo:write` (or equivalent) — but the **primary** split workflow only needs read.
- **Remote runners (on-prem).** Set `create_remote_runner = true` and register the runner via module outputs **`remote_runner_cli_start_command_with_secrets`** (preferred when secrets are bound) or **`remote_runner_cli_start_command`**. After the runner is **online**, set `remote_runner_attach_to_agent = true`.

  **Mothership secret sync (recommended):** pass **`runner_git_token`** (and optionally **`runner_aws_access_key_id`** / **`runner_aws_secret_access_key`**) or pre-existing **`runner_git_env_secret_id`** / **`runner_aws_env_secret_id`** vault UUIDs whose metadata uses flat env keys (`GIT_TOKEN`, `GIT_HOST`, `AWS_ACCESS_KEY_ID`, …). Terraform also provisions **`sg_secret.runner_script_pack_env`** and binds it on the runner generic sync slot so aiden-runner receives **`DBSPLIT_SCRIPT_PACK_*`** (allocate/runner script b64 + sha256 + version) — required for **ingest-and-split**. After `tofu apply` when **`script_pack_version`** changes, restart aiden-runner (or wait for secrets sync) before re-running workflows. Use **`repo:write`** on the git token when the registry stage must open IaC PRs. SCM-shaped integration secrets (`token` only) are for **`gh api` MCP** — do not bind those to the runner typed `github` slot.

  **Local mount (Mode 1):** set `remote_runner_secret_sync_enabled = false` and inject the same env vars via K8s Secret / `docker -e` — see [aiden-runner README](https://github.com/appcd-dev/stackgen-guild/blob/main/cmd/aiden-runner/README.md). For ingest without mothership sync, export either individual **`DBSPLIT_SCRIPT_PACK_*`** keys or **`DBSPLIT_SCRIPT_PACK_ENV_JSON`** (same JSON object stored in vault generic secret `value`). Also set **`GIT_TOKEN`** when ingest needs git. Mount host tfstate at `/tmp/splits` for `file://` monolith URIs. Run `scripts/preflight.sh` before triggering the workflow.

## Security & privacy

- Terraform state can contain **secrets**. SOPs instruct agents to **`note`** summaries and paths, not raw attribute maps. **`/tmp`** on shared runners may be visible across jobs — use tight directory permissions and cleanup when policy allows (see **db-state-split-orchestration-sop**).

## Continuous integration

- Repo **CI** runs **`scripts/terraform-validate-all.sh`** (includes this module) and **`scripts/verify-db-state-split-templates.sh`**, which renders **`db-state-split-orchestration.md.tftpl`** with dummy locals to catch **template syntax** errors early.

## Usage

```hcl
module "db_state_splitter" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-db-state-splitter?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
    aws        = module.aws_integration.integration_name
  }

  # Required: Guild integration name for the StackGen Consumer MCP (e.g. "stackgen-mcp").
  stackgen_mcp_integration_name = sg_guild_integration.stackgen_mcp.name

  # On-prem runner: create + install commands in outputs; attach when runner is online.
  # create_remote_runner            = true
  # remote_runner_name              = "org-tofu-runner"
  # remote_runner_attach_to_agent   = true
  # runner_git_token                = var.git_readonly_token  # repo:write for IaC PRs
  # runner_aws_access_key_id        = var.aws_readonly_access_key_id
  # runner_aws_secret_access_key    = var.aws_readonly_secret_access_key

  # Optional: GitHub ingress to primary workflow (default false to avoid duplicate webhooks).
  # enable_github_webhook = true
}
```

## Workflows

| Name | Purpose |
|------|---------|
| `db-monorepo-state-split-convergence` | Multi-cloud logical grouping, count gate, reverse IaC, **StackGen AppStack materialization**, orphan handoff, TF + StackGen plan convergence |
| `orphan-iac-module-authoring` | Scaffold modules from `orphans_bundle`, validate, persist `orphan_modularization_memory` |

Primary workflow **required input**: `monolith_state_uri` (cron/webhook alias: `tfstate_file`).  
**Optional:** `iac_repository_url` (alias `iac_repo_url`) — omit for state-only analysis; per-group TF scaffolds land under `$HOME/.<workflow_run_id>`.  
Notable **optional inputs**: `grouping_policy_json`, `grouping_strategy` (`policy_first` \| `connectivity` \| `connectivity_capped`), `max_resources_per_appstack` (e.g. `80`), `stackgen_project_name` (human-readable StackGen project name for MCP — e.g. `guild-demo`), `cloud_discovery_id` (opaque correlation id for operators — **not** wired to MCP discovery import on the default user MCP).

### Workflow shape (lean v2 — 7 stages, script-heavy)

```
ingest-and-split
 → ingest-blocked-gate                    (conditional_skip — no GO_BACK loop gates)
 → registry-and-import-codegen            (script: scaffold + prepare-parallel-artifacts + IaC PR via cp sync)
   ├→ shell-converge-matrix               (script: hydrate-and-plan-matrix over sample groups)
   ├→ materialize-appstacks-coordinator   (4× appstack-materialize-runner-batch-<NN> in one parallel fan-out)
   └→ orphans-secondary-pipeline          (optional orphan workflow kickoff)
                                          → final-gate-and-memory
```

Registry stage writes **`batch_payloads.json`** and **`sample_group_ids.json`** so parallel coordinators never spawn payload-extraction probe agents. HCL hydration and plan zero-diff run deterministically in **`shell-converge-matrix`** (not per-group LLM children). See [`docs/execution-post-mortem-7b78ad9d.md`](docs/execution-post-mortem-7b78ad9d.md) for the production trace that motivated this refactor.

## AppStack membership integrity

Earlier production runs created the right number of AppStacks but populated each with the wrong set of resources (e.g. type-bucketed "all IAM" stack instead of the connectivity group). This is now enforced as a **hard gate**:

- **`stackgen-appstack-mcp-playbook-sop` step 3.5 — Membership verification gate.** After `bulk_add_resources_to_appstack` for a `group_id`, the agent must call `get_appstack_resources(appstack_id)` and write **`stackgen_appstack_membership:<group_id>`** with `expected_identifiers`, `actual_identifiers`, `missing`, `unexpected`, `cross_group_bleed`, `ok`. The agent reconciles (re-add missing, delete non-bleed unexpected) until `ok=true` before any `bulk_connect_resources_in_appstack` or Plan call.
- **Roll-up** — the materialization stage finishes only after writing **`stackgen_appstack_membership_report`** with `summary.groups_failed == 0`.
- **Convergence Loop B-membership** — the plan convergence stage refuses to call `create_appstack_action_run` for any AppStack whose membership is not `ok=true`.
- **Evidence** — `db-monorepo-state-split-evidence` (the workflow's `evidence_checklist_ref`) requires `stackgen_appstack_membership_report_attached` and `appstack_membership_verified_per_group`. Cross-group bleed events land in optional item `cross_group_bleed_resolution_log`.
- **Closed-set rule.** The agent never adds resources to an AppStack that are not in that group's `resource_addresses`, and never re-buckets by Terraform resource type at MCP time.

## Reliability (what the prompts optimize for)

Guild traces on long runs showed **skill-search noise**, **`/workspace` read-only** sandboxes, **~300s Ubuntu timeouts** on monolithic shell commands, and **many redundant `get_appstacks` / `get_appstack_resources`** calls. Trace `019e20308ea374c8bbc134d5c0ef0860` (4h 10m, $7.03, status=error) surfaced additional failure modes that this module now defends against:

| Observed failure | Defense |
|------------------|---------|
| `ask_clarifying_question` blocking 5 min for prior-stage state the operator can't supply | Persona + orchestration SOP define **when `ask_clarifying_question` is appropriate** (new info: missing creds, ambiguous `grouping_strategy`, real `cross_group_bleed`) and **when it isn't** (re-asking for `repo_clone_path` / `monolith_state_local_path` / `logical_group_manifest`); missing prior-stage state goes through **cold-start fast-fail** (`notify` once with `cold_start_no_upstream` and return) instead. |
| `read_notes` returning 0 keys at every stage entry (stage-scoped notes store) | **Disk-mirror at `$HOME/.<workflow_run_id>/notes.json`** — every `note` is `jq`-merged into the disk mirror; every stage entry reads notes **then** falls back to the disk mirror. Critical handoff values also echoed in each stage's final assistant message. |
| Architect retrying the same subagent payload under thrash names (`-v2`, `-scripts`, `-scripts-full`, `recovery-probe`, …) when a subgoal didn't converge | **Subagent-spawn discipline** in the persona: stable `<stage_id>-runner` names tied to the subgoal, `task_type` matched to the work, spawn goal ≤ 1000 chars (script paths only); when a subgoal doesn't converge, **re-plan** the decomposition (split into smaller children, change tools or `task_type`) rather than re-running the same payload. |
| `multi-shard-plan-convergence` + `final-gate-and-memory` emitting "all SKIPPED" markdown reports on cold-start | **No-vacuous-gate** hard rule: empty notes + empty disk-mirror + missing `$HOME/.<workflow_run_id>/` → single `notify({error:'cold_start_no_upstream'})` + return; final-gate has an explicit **evidence gate** requiring `submit_evidence` for every required item. |
| Architect ran shell tools directly (7× `execute_command`, 2× `load_skill`, premature `submit_evidence`) instead of one `ingest-monolith-runner` | **Script pack** (`stage-runner.sh`) + **coordinator-only architect** — Ubuntu work only inside runner subagents via one embedded `execute_series`; `submit_evidence` only at `final-gate-and-memory`. |
| Thrash subagent `discover-db-anchors-script-prep` | **Forbidden names** list in discover stage + orchestration SOP; only `discover-db-anchors-runner` or re-plan `…-build-seeds` / `…-build-inventory`. |
| Cron payload uses `tfstate_file` not `monolith_state_uri` | **`tfstate_file` input alias** + ingest **Step 0 normalization**; `ingest-blocked-gate` skips downstream when URI still missing |
| Sub-agent used `/bin/sh` and failed on `set -o pipefail` | Script pack mandates **`bash -s` heredoc** with `_embed_dbsplit_run` (never `/bin/sh`) |
| `$WORK_ROOT` not expanded in `execute_series` (trace `09ff14b8ad27`) | Spawn contract passes literal **`{{work_root}}`** — never `$WORK_ROOT` in tool JSON |
| Ingest failed but registry still ran | **`ingest-blocked-gate`** matches blocked/reconcile/script_pack sentinels — skips registry + parallel layer |
| False GO_BACK from loop gates poisoned fan-in (trace `7b78ad9d`) | **Removed** `split-loop-gate` / `split-ingest-blocked-gate` — single `ingest-blocked-gate` without `"action":"GO_BACK"` match |
| `rsync` missing in Ubuntu sidecar blocked IaC PR | Script pack uses **`cp -a` only** (`sync-groups-to-repo`); Ubuntu image also ships `rsync` as belt-and-suspenders |
| Architect probe thrash (51 subagents, max-iter failures) | Coordinator **hard caps** (max 1–2 `create_agent` per stage); script-driven `hydrate-and-plan-matrix` + pre-built `batch_payloads.json` |
| `tofu` missing → plan loop forever | **`blocked:ubuntu_infra_tofu_missing`** in script output — final-gate reads notes (no plan loop gates) |

The persona and runbooks continue to steer the agent toward: **`/tmp` preflight**, **trusting prepended `[Runbook Context]` / `### Runbook:` text** (Guild injects runbook summaries per stage — avoid redundant **`search_skill`**), **`[Skills]` vs `load_skill`** (skip redundant loads when the runbook block already inlined the same name), **per-subgoal subagent delegation** (one stable `<stage_id>-runner` per stage, parallel children for fan-out, no retry-thrash), **`stackgen_appstack_list_cache`**, **one shard per plan step** (or remote-runner fan-out), **MCP list caching** during AppStack materialization, and **redacted `note` discipline** for state secrets.

Remaining iteration limits, DAG deduplication, the per-stage notes-store scoping (an upstream Guild platform concern), and cascade fallbacks are **Guild platform** concerns — the disk-mirror is the in-module workaround until that platform behavior is unified across stages.

## Outputs

See `outputs.tf` — agent name, workflow names, `stackgen_mcp_auto_approve_policy_id`, optional webhook id/token.
