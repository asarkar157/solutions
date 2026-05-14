terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # 0.1.17 — adopt-on-conflict for sg_policy_bundle, already-approved
      # sg_workflow, sg_guild_model_provider / sg_guild_model; integration env
      # map; floor that includes evidence-checklist + remediation patterns.
      version = ">= 0.1.18, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "scenario-author"

  # Normalize name_suffix: empty → "" (no suffix), non-empty → "-<suffix>"
  # so every named resource ends up valid kebab-case.
  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name             = "${local.module_prefix}${local.suffix}"
  workflow_name          = "${local.module_prefix}-request-triage${local.suffix}"
  webhook_name           = "${local.module_prefix}-github-receiver${local.suffix}"
  sop_orchestration_name = "${local.module_prefix}-orchestration-sop${local.suffix}"
  sop_cursor_author_name = "${local.module_prefix}-cursor-author-sop${local.suffix}"
  sop_pr_and_notify_name = "${local.module_prefix}-pr-and-notify-sop${local.suffix}"

  # Module-identity-prefixed integration names. These ARE the MCP tool
  # prefixes the LLM sees at runtime; every reference in the persona / SOPs
  # is templated via `${github_tool_prefix}` / `${cursor_tool_prefix}` below.
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  cursor_integration_name = "${local.module_prefix}-cursor${local.suffix}"

  # Resolve to either the module-owned integration or the consumer-supplied
  # existing one. `coalesce` returns the first non-empty value.
  resolved_github_integration_name = coalesce(
    trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : null,
    try(module.github_integration[0].integration_name, null),
    local.github_integration_name,
  )
  resolved_cursor_integration_name = coalesce(
    trimspace(var.existing_cursor_integration_name) != "" ? var.existing_cursor_integration_name : null,
    try(module.cursor_integration[0].integration_name, null),
    local.cursor_integration_name,
  )

  template_vars = {
    module_prefix           = local.module_prefix
    github_tool_prefix      = local.resolved_github_integration_name
    cursor_tool_prefix      = local.resolved_cursor_integration_name
    github_integration_name = local.resolved_github_integration_name
    cursor_integration_name = local.resolved_cursor_integration_name
    repository_full_name    = var.repository_full_name
    scenario_request_label  = var.scenario_request_label
  }

  rendered_personas = {
    for filename in fileset("${path.module}/personas", "*.md.tftpl") :
    replace(filename, ".tftpl", "") => templatefile("${path.module}/personas/${filename}", local.template_vars)
  }

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    replace(filename, ".tftpl", "") => templatefile("${path.module}/templates/${filename}", local.template_vars)
  }
}

# Mutually-exclusive cursor input gate: either provision internally with
# `cursor_api_key` OR attach to a pre-existing integration via
# `existing_cursor_integration_name`. Caught at plan time so the user gets a
# clear error instead of a confusing "integration not found" later.
resource "terraform_data" "validate_cursor_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.cursor_api_key) != "" || trimspace(var.existing_cursor_integration_name) != ""
      error_message = "aios-agent-scenario-author requires exactly one of `cursor_api_key` (self-contained) or `existing_cursor_integration_name` (shared) to be set."
    }
    precondition {
      condition     = !(trimspace(var.cursor_api_key) != "" && trimspace(var.existing_cursor_integration_name) != "")
      error_message = "aios-agent-scenario-author cannot accept both `cursor_api_key` and `existing_cursor_integration_name`; pass exactly one."
    }
  }
}

# Mutually-exclusive github input gate: either provision internally with
# `github_secret_id` (and let this module spin up `scenario-author-github`)
# OR attach to a pre-existing integration via `existing_github_integration_name`
# (typical when the tenant already runs the OAuth-backed `github-integration`
# shared with `aios-agent-software-engineering`). Caught at plan time so the
# user gets a clear error instead of a confusing "integration not found" later.
resource "terraform_data" "validate_github_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.github_secret_id) != "" || trimspace(var.existing_github_integration_name) != ""
      error_message = "aios-agent-scenario-author requires exactly one of `github_secret_id` (self-contained) or `existing_github_integration_name` (shared) to be set."
    }
    precondition {
      condition     = !(trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) != "")
      error_message = "aios-agent-scenario-author cannot accept both `github_secret_id` and `existing_github_integration_name`; pass exactly one."
    }
  }
}

# =============================================================================
# Owned integrations — provisioned when the consumer hasn't supplied an
# existing one to share.
#
# - GitHub integration: bound to `var.github_secret_id` so `gh api` calls from
#   the planner's `analyze-issue` and `notify-issue-comment` stages
#   authenticate without threading a token through subagent goals.
# - Cursor integration: wraps the Cursor Cloud Agents MCP. The Cursor agent
#   spawned in `cursor-author` uses Cursor's own GitHub App
#   (`OpenAsCursorGithubApp = true`) to clone, commit, and open the PR — it
#   does NOT receive the tenant's GitHub PAT.
# =============================================================================

module "github_integration" {
  count  = trimspace(var.existing_github_integration_name) == "" && trimspace(var.github_secret_id) != "" ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (issue fetch, gh issue comment). Bound to a shared tenant-level PAT secret."
}

module "cursor_integration" {
  count  = trimspace(var.existing_cursor_integration_name) == "" ? 1 : 0
  source = "../aios-integration-cursor"

  integration_name = local.cursor_integration_name
  cursor_api_key   = var.cursor_api_key
}

# =============================================================================
# Scenario Author — agent
# =============================================================================
# Triaged by a GitHub webhook on `repository_full_name`. Reads `scenario-request`
# issues, decides whether an existing scenario fits, and either replies with a
# pointer or hands the entire repo-clone + scaffold + commit + PR job to a
# Cursor Cloud Agent (`cursor_agents_run_task`). The PR is auto-created by
# Cursor via its GitHub App; the planner only posts the final summary comment
# back on the originating issue.

resource "sg_agent" "scenario_author" {
  name        = local.agent_name
  persona     = local.rendered_personas["scenario-author.md"]
  model_names = compact(var.model_names)

  integrations = [
    local.resolved_github_integration_name,
    local.resolved_cursor_integration_name,
  ]
}

resource "sg_agent_budget" "scenario_author" {
  agent_name  = sg_agent.scenario_author.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "scenario_author_dangerous_ops" {
  agent_name = sg_agent.scenario_author.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# =============================================================================
# Runbook SOPs — loaded from ./templates/*.md.tftpl so module-prefixed tool
# names (e.g. `scenario-author-cursor_cursor_agents_run_task`) flow into the
# SOP body automatically when `name_suffix` is used.
# =============================================================================

resource "sg_runbook_sop" "scenario_author_orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-author-orchestration.md"])
}

resource "sg_runbook_sop" "scenario_cursor_author" {
  name        = local.sop_cursor_author_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-cursor-author.md"])
}

resource "sg_runbook_sop" "scenario_pr_and_notify" {
  name        = local.sop_pr_and_notify_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-pr-and-notify.md"])
}

# =============================================================================
# Workflow — scenario-request-triage
# =============================================================================

resource "sg_workflow" "scenario_request_triage" {
  name        = local.workflow_name
  domain      = "developer-experience"
  description = "Triages `scenario-request` GitHub issues filed against the configured solutions-style repo (default `appcd-dev/solutions`). Hands the clone/triage/scaffold/PR work to a Cursor Cloud Agent (no Ubuntu sandbox shell scripting), then comments back on the issue with the PR URL or the existing-scenario match. Powers the SE feedback loop documented in docs/se-feedback.md and docs/se-playbook.md."
  approve     = true

  triggers = [
    { field = "event_type", values = var.trigger_event_types, type = "active", source = "github" }
  ]

  runbook_refs = [
    sg_runbook_sop.scenario_author_orchestration.name,
    sg_runbook_sop.scenario_cursor_author.name,
    sg_runbook_sop.scenario_pr_and_notify.name,
  ]

  required_inputs = ["repository_full_name", "issue_or_pr_number"]
  optional_inputs = ["issue_labels"]

  example_queries = [
    "A solutions engineer just filed a `scenario-request` issue on appcd-dev/solutions asking for an idle-EC2-only demo — triage it",
    "Issue #123 [scenario] grafana-only incident triage demo — see if an existing scenario fits, else scaffold a PR via Cursor",
    "Issue #45 missing the scenario-request label — politely tell the SE how to re-file"
  ]

  stages = [
    {
      stage_id    = "analyze-issue"
      description = "Extract the trigger payload, fetch the issue body via `gh api`, and run the repo + label gate. Posts the gate-fail comment inline on rejection."
      note        = "Single-subagent stage. Spawn `analyze-issue-fetch-issue` (orchestration SOP Template A). Evaluate the §0c gate. If the gate fails, spawn `analyze-issue-comment-gate-fail` (Template F) and stop the workflow at this stage."
      required    = true
    },
    {
      stage_id    = "cursor-author"
      description = "Hand the entire scaffold job (clone, triage, write 5 files + demo.sh + se-playbook row, validate with tofu, branch, commit, PR with auto-created body) to a Cursor Cloud Agent via `cursor_agents_run_task`. Returns a verdict: `match`, `pr`, `draft_pr`, or `blocked`."
      note        = "Single-subagent stage. Spawn `cursor-author-run-task` (orchestration SOP Template C). The subagent assembles the prompt from `scenario-author-cursor-author-sop`, calls `${local.resolved_cursor_integration_name}_cursor_agents_run_task`, and persists `cursor_verdict`, `cursor_pr_url`, `cursor_match_name`, `cursor_summary`, `cursor_artifacts` from the response."
      required    = true
    },
    {
      stage_id    = "notify-issue-comment"
      description = "Always-runs final stage. Branches on captured notes to post exactly one issue comment via `gh issue comment`: gate-fail, existing-match, scaffolded-PR, draft-PR, or blocked."
      note        = "Single-subagent stage. Spawn `notify-issue-comment` (orchestration SOP Template E + scenario-pr-and-notify-sop). This stage MUST run regardless of upstream blockers so the SE always sees a reply."
      required    = true
    }
  ]

  stage_bindings = [
    {
      stage_id  = "analyze-issue"
      agent_ref = sg_agent.scenario_author.name
      runbook_refs = [
        sg_runbook_sop.scenario_author_orchestration.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["scenario-request-triage::analyze-issue"], []),
      )
      note = <<-EOT
        Budget contract: ≤ 2 subagents, ≤ $0.75, ≤ 120s.

        Plan (do this exactly — the gate is what protects the bot from random org-wide noise):

        1. Extract these fields from `trigger_event.payload` and write them to notes BEFORE spawning any subagent:
             - `repository_full_name`        ← `repository.full_name`
             - `repository_clone_url`        ← `repository.clone_url`
             - `repository_default_branch`   ← `repository.default_branch`
             - `issue_or_pr_number`          ← `issue.number`
             - `event_type`                  ← `trigger_event.type`
             - `issue_labels`                ← `[for l in issue.labels : l.name]`
             - `issue_author`                ← `issue.user.login`
           If `repository_full_name` or `issue_or_pr_number` is empty, branch to §6(a) of `scenario-author-orchestration-sop` and STOP.

        2. `read_notes` for `issue_details`. If populated (re-entry case), skip to step 4.

        3. Spawn EXACTLY one subagent named `analyze-issue-fetch-issue` per orchestration-sop Template A. It calls `${local.resolved_github_integration_name}_execute_command` with `gh api /repos/<repository_full_name>/issues/<n>` and the `--jq` filter from Template A → note `issue_details`. NO token capture step — the GitHub integration container is pre-bound to the PAT secret.

        4. Evaluate the §0c gate using the notes:
             a) `gate_result = "wrong_repo"` if `repository_full_name` ≠ `${var.repository_full_name}`.
             b) `gate_result = "missing_label"` if `${var.scenario_request_label}` is not in `issue_labels`.
             c) Otherwise `gate_result = "pass"`.

        5. If `gate_result` is NOT `pass`: spawn EXACTLY one subagent `analyze-issue-comment-gate-fail` (Template F) which posts the canned gate-fail comment via `gh issue comment` on the GitHub integration. After it returns, note `stage_summary:analyze-issue="gate ${var.scenario_request_label} -> <gate_result>; commented and stopping"` and STOP the workflow (downstream stages will short-circuit via `read_notes` of `gate_result`).

        6. If `gate_result == "pass"`: note `stage_summary:analyze-issue="gate pass; issue=<n>, queued for cursor-author"`.

        Forbidden:
        - Cloning the repo (Cursor will do that in `cursor-author`).
        - Searching the org with `gh repo list` or `gh search issues`.
        - Spawning more than the two named subagents above.
        - Capturing or echoing the PAT — the GitHub integration auto-injects it.
      EOT
    },
    {
      stage_id         = "cursor-author"
      agent_ref        = sg_agent.scenario_author.name
      stage_depends_on = ["analyze-issue"]
      runbook_refs = [
        sg_runbook_sop.scenario_author_orchestration.name,
        sg_runbook_sop.scenario_cursor_author.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_cursor_author_name],
        try(var.workflow_skill_refs["scenario-request-triage::cursor-author"], []),
      )
      note = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $2.00, ≤ 12 minutes (Cursor's `run_task` polls until the cloud agent reports FINISHED / FAILED / CANCELED — it can take 5-10 minutes for a non-trivial scaffold). Reserve ≥ $0.50 for `notify-issue-comment`.

        Short-circuit: this stage is a no-op when `gate_result != "pass"` (`read_notes` first). In that case, note `stage_summary:cursor-author="skipped: gate ${var.scenario_request_label} -> <gate_result>"` and yield.

        Plan (happy path):

        1. `read_notes` for `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_details`, `issue_or_pr_number`, `cursor_verdict`, `cursor_pr_url`.

        2. If `cursor_verdict` is already populated (re-entry), skip to step 4.

        3. Spawn EXACTLY one subagent `cursor-author-run-task` (orchestration-sop Template C). Its `goal` MUST inline:
             - The verbatim body of `${local.sop_cursor_author_name}` (subagents cannot see learned skills).
             - The current values of `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_or_pr_number`, `issue_details`.
             - Explicit instructions to call `${local.resolved_cursor_integration_name}_cursor_agents_run_task` exactly once with the assembled prompt + repository URL + ref `<repository_default_branch>`.
             - Explicit instructions to parse the cursor response and persist:
                  * `cursor_verdict` ∈ {`match`, `pr`, `draft_pr`, `blocked`}
                  * `cursor_pr_url`        (when `verdict ∈ {pr, draft_pr}`)
                  * `cursor_match_name`    (when `verdict == match`)
                  * `cursor_summary`       (always — one paragraph from the Cursor conversation summary)
                  * `cursor_artifacts`     (optional — the raw artifacts list)
                  * If FAILED/CANCELED and the summary matches Cursor **account** billing / quota signals (orchestration §6(c)), also `note key="cursor_platform_cap" value="true"` so `notify-issue-comment` posts the Cursor-platform template instead of mis-labeling Guild `agent_budget`.

        4. note `stage_summary:cursor-author` with: verdict, PR URL or match name, validation outcome (extracted from `cursor_summary`), and the Cursor agent ID for traceability.

        Approved subagent names: `cursor-author-run-task`. NO other names. Do NOT spawn a second `run_task` to "retry" — Cursor's own retry loop runs internally; if the cloud agent reports FAILED, treat it as `verdict=blocked` and route to `notify-issue-comment`.

        Forbidden:
        - Spawning Ubuntu CLI subagents (this module no longer wires one).
        - Capturing or threading the GitHub PAT into the Cursor prompt — Cursor uses its own GitHub App (`OpenAsCursorGithubApp = true`).
        - Setting `fireAndForget = true` on the cursor task — the planner needs the verdict to pick the right comment template in `notify-issue-comment`.
        - Posting comments here. The `notify-issue-comment` stage owns all comments.
      EOT
    },
    {
      stage_id         = "notify-issue-comment"
      agent_ref        = sg_agent.scenario_author.name
      stage_depends_on = ["cursor-author"]
      runbook_refs = [
        sg_runbook_sop.scenario_author_orchestration.name,
        sg_runbook_sop.scenario_pr_and_notify.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_pr_and_notify_name],
        try(var.workflow_skill_refs["scenario-request-triage::notify-issue-comment"], []),
      )
      note = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $0.50, ≤ 60s. THIS STAGE MUST RUN — it is how the SE sees the bot's output, including blocked-status outputs from upstream stages.

        Plan:

        1. `read_notes` for `repository_full_name`, `issue_or_pr_number`, `gate_result`, `cursor_verdict`, `cursor_pr_url`, `cursor_match_name`, `cursor_summary`, `cursor_platform_cap` (if present), and ALL `stage_summary:*` keys.

        2. Skip the comment entirely IF AND ONLY IF `gate_result != "pass"` (the gate-fail comment was already posted in `analyze-issue`). In that case, note `stage_summary:notify-issue-comment="skipped: gate-fail comment already posted"` and yield.

        3. Otherwise, spawn EXACTLY one subagent `notify-issue-comment` per orchestration-sop Template E + scenario-pr-and-notify-sop. The subagent picks ONE body based on captured notes (first match wins, evaluate in order — **must** match scenario-pr-and-notify-sop §1 so Cursor billing errors are never mis-classified as Guild `agent_budget`):
             a) `read_notes` shows `cursor_platform_cap == "true"` OR (`cursor_verdict == "blocked"` AND (`cursor_summary` OR any `stage_summary:*` contains case-insensitive `insufficient account budget`, `cursor platform`, `billing`, `payment required`, or `quota exceeded`) AND `cursor_pr_url` is empty) → "## Cursor platform temporarily unavailable" (Cursor SaaS limits — retry / Cursor dashboard / manual scaffold per that SOP).
             b) `cursor_verdict == "match"` → "Existing scenario match" comment quoting `cursor_match_name` and the run command.
             c) ANY `stage_summary:*` contains the exact substring `guild_spend_cap_reached` AND `cursor_pr_url` is empty → "## Guild planner budget exhausted" (StackGen `agent_budget` / `sg_agent_budget`).
             d) `cursor_verdict == "blocked"` OR any `stage_summary:*` starts with `blocked:` → "Workflow blocked" comment quoting the blocker text (use `cursor_summary` when the verdict is `blocked`) **only if** (a) did not apply.
             e) `cursor_verdict == "pr"` AND `cursor_pr_url` non-empty → "Scaffolded a PR" comment quoting the PR URL + summary.
             f) `cursor_verdict == "draft_pr"` AND `cursor_pr_url` non-empty → "Draft PR (validation failed)" comment quoting the PR URL + summary.
             g) Else (no PR, no match, no clear blocker — only happens when the cursor agent yielded mid-stage with no notes) → "Triaged, no action taken" comment that also asks the SE to re-open the issue.

        4. note `stage_summary:notify-issue-comment` with: chosen comment kind + the issue URL.
      EOT
    }
  ]
}

# =============================================================================
# Webhook ingress — GitHub `issue.created` events
# =============================================================================
# `enable_webhook = false` lets operators stage the workflow + agent without
# wiring an ingress (handy for staging tenants or dry-runs from the Guild UI).

resource "sg_webhook" "github_scenario_request" {
  count = var.enable_webhook ? 1 : 0

  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.scenario_request_triage.name
  action      = "A GitHub issue was filed on the configured solutions-style repository (default `appcd-dev/solutions`). Inspect the payload (repository_full_name, issue.number, issue.labels) and route to the scenario-request-triage workflow. The workflow's analyze-issue stage enforces the repo + label gate; do not pre-filter here."
  enabled     = true
}
