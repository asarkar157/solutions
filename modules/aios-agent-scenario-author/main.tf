terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # 0.1.17 — adopt-on-conflict for sg_policy_bundle, already-approved
      # sg_workflow, sg_guild_model_provider / sg_guild_model; integration env
      # map; floor that includes evidence-checklist + remediation patterns.
      version = ">= 0.1.17, < 0.2.0"
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
  sop_triage_name        = "${local.module_prefix}-triage-sop${local.suffix}"
  sop_scaffold_name      = "${local.module_prefix}-scaffold-sop${local.suffix}"
  sop_pr_and_notify_name = "${local.module_prefix}-pr-and-notify-sop${local.suffix}"

  # Module-identity-prefixed integration names. These ARE the MCP tool
  # prefixes the LLM sees at runtime; every reference in the persona / SOPs
  # is templated via `${github_tool_prefix}` / `${ubuntu_tool_prefix}` below.
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

  # Resolve to either the module-owned integration or the consumer-supplied
  # existing one. `coalesce` returns the first non-empty value.
  resolved_github_integration_name = coalesce(
    trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : null,
    try(module.github_integration[0].integration_name, null),
    local.github_integration_name,
  )
  resolved_ubuntu_integration_name = coalesce(
    trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : null,
    try(module.ubuntu_integration[0].integration_name, null),
    local.ubuntu_integration_name,
  )

  template_vars = {
    module_prefix           = local.module_prefix
    github_tool_prefix      = local.resolved_github_integration_name
    ubuntu_tool_prefix      = local.resolved_ubuntu_integration_name
    github_integration_name = local.resolved_github_integration_name
    ubuntu_integration_name = local.resolved_ubuntu_integration_name
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

# =============================================================================
# Owned integrations — provisioned when the consumer hasn't supplied an
# existing one to share. Both are bound to the SAME `var.github_secret_id` so
# the Ubuntu sandbox sees `GH_TOKEN` (or the image-equivalent) pre-set and the
# GitHub API sandbox can authenticate `gh api` calls.
# =============================================================================

module "github_integration" {
  count  = trimspace(var.existing_github_integration_name) == "" ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (issue fetch, gh api). Bound to a shared tenant-level PAT secret."
}

module "ubuntu_integration" {
  count  = trimspace(var.existing_ubuntu_integration_name) == "" ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = [var.github_secret_id]
  install_tools    = ["tofu", "gh", "git", "curl"]
}

# =============================================================================
# Scenario Author — agent
# =============================================================================
# Triaged by a GitHub webhook on `repository_full_name`. Reads `scenario-request`
# issues, decides whether an existing scenario fits, and either replies with a
# pointer or scaffolds a new scenario PR. The agent never writes outside
# `examples/scenarios/<slug>/`, `scripts/demo.sh`, and the
# `docs/se-playbook.md` "Prospect-question → scenario" table (the orchestration
# SOP encodes that as a hard rule).

resource "sg_agent" "scenario_author" {
  name        = local.agent_name
  persona     = local.rendered_personas["scenario-author.md"]
  model_names = compact(var.model_names)

  integrations = [
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
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
# names (e.g. `scenario-author-ubuntu_execute_command`) flow into the SOP body
# automatically when `name_suffix` is used.
# =============================================================================

resource "sg_runbook_sop" "scenario_author_orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-author-orchestration.md"])
}

resource "sg_runbook_sop" "scenario_triage" {
  name        = local.sop_triage_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-triage.md"])
}

resource "sg_runbook_sop" "scenario_scaffold" {
  name        = local.sop_scaffold_name
  approve     = true
  description = trimspace(local.rendered_templates["scenario-scaffold.md"])
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
  description = "Triages `scenario-request` GitHub issues filed against the configured solutions-style repo (default `appcd-dev/solutions`). Decides whether an existing demo scenario already fits or scaffolds a brand-new one under examples/scenarios/<slug>/, validates with tofu fmt + tofu validate, opens a PR, and comments back on the issue. Powers the SE feedback loop documented in docs/se-feedback.md and docs/se-playbook.md."
  approve     = true

  triggers = [
    { field = "event_type", values = var.trigger_event_types, type = "active", source = "github" }
  ]

  runbook_refs = [
    sg_runbook_sop.scenario_author_orchestration.name,
    sg_runbook_sop.scenario_triage.name,
    sg_runbook_sop.scenario_scaffold.name,
    sg_runbook_sop.scenario_pr_and_notify.name,
  ]

  required_inputs = ["repository_full_name", "issue_or_pr_number"]
  optional_inputs = ["issue_labels"]

  example_queries = [
    "A solutions engineer just filed a `scenario-request` issue on appcd-dev/solutions asking for an idle-EC2-only demo — triage it",
    "Issue #123 [scenario] grafana-only incident triage demo — see if an existing scenario fits, else scaffold a PR",
    "Issue #45 missing the scenario-request label — politely tell the SE how to re-file"
  ]

  stages = [
    {
      stage_id    = "analyze-issue"
      description = "Extract trigger payload, fetch the issue body, and run the repo + label gate. Because the Ubuntu sandbox already has the GitHub PAT pre-bound, no `gh auth token` capture step is needed."
      note        = "Single-subagent stage. Spawn `analyze-issue-fetch-issue` (orchestration SOP Template A). Evaluate the §0c gate. If the gate fails, spawn `analyze-issue-comment-gate-fail` (Template F) and stop the workflow at this stage."
      required    = true
    },
    {
      stage_id    = "triage"
      description = "Clone the repo, scan existing scenarios, and decide whether one already matches the issue (scenario-triage-sop)."
      note        = "Single-subagent stage. Spawn `triage-clone` (orchestration SOP Template B + scenario-triage-sop). Persist `existing_match` (or null) and `scenario_slug` + structured fields parsed from the issue body."
      required    = true
    },
    {
      stage_id    = "scaffold-validate-pr"
      description = "When no existing match: write the 5 scenario files, register in scripts/demo.sh, tofu fmt + validate, branch + commit + push + open PR."
      note        = "Two-subagent stage at most. Skip entirely when `existing_match` is non-null OR `gate_result != \"pass\"`. Otherwise spawn `scaffold-write-and-validate` (Template C + scenario-scaffold-sop) THEN `scaffold-pr` (Template D + scenario-pr-and-notify-sop §1-4). Hard cap at 2 subagents."
      required    = true
    },
    {
      stage_id    = "notify-issue-comment"
      description = "Always-runs final stage. Branches on captured notes to post exactly one issue comment: gate-fail, existing-match, happy-PR, draft-PR, or blocked."
      note        = "Single-subagent stage. Spawn `notify-issue-comment` (orchestration SOP Template E + scenario-pr-and-notify-sop §5). This stage MUST run regardless of upstream blockers so the SE always sees a reply."
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

        3. Spawn EXACTLY one subagent named `analyze-issue-fetch-issue` per orchestration-sop Template A. It calls `${local.resolved_github_integration_name}_execute_command` with `gh api /repos/<repository_full_name>/issues/<n>` and the `--jq` filter from Template A → note `issue_details`. NO token capture step — the Ubuntu sandbox already has the PAT pre-bound via `secret_ref_ids`.

        4. Evaluate the §0c gate using the notes:
             a) `gate_result = "wrong_repo"` if `repository_full_name` ≠ `${var.repository_full_name}`.
             b) `gate_result = "missing_label"` if `${var.scenario_request_label}` is not in `issue_labels`.
             c) Otherwise `gate_result = "pass"`.

        5. If `gate_result` is NOT `pass`: spawn EXACTLY one subagent `analyze-issue-comment-gate-fail` (Template F) which posts the canned gate-fail comment. After it returns, note `stage_summary:analyze-issue="gate ${var.scenario_request_label} -> <gate_result>; commented and stopping"` and STOP the workflow (downstream stages will short-circuit via `read_notes` of `gate_result`).

        6. If `gate_result == "pass"`: note `stage_summary:analyze-issue="gate pass; issue=<n>, slug-candidate=<from-title>, queued for triage"`.

        Forbidden:
        - Cloning the repo (that's `triage-clone`'s job).
        - Searching the org with `gh repo list` or `gh search issues`.
        - Spawning more than the two named subagents above.
        - Capturing or echoing the PAT — the sandbox auto-injects it.
      EOT
    },
    {
      stage_id         = "triage"
      agent_ref        = sg_agent.scenario_author.name
      stage_depends_on = ["analyze-issue"]
      runbook_refs = [
        sg_runbook_sop.scenario_author_orchestration.name,
        sg_runbook_sop.scenario_triage.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_triage_name],
        try(var.workflow_skill_refs["scenario-request-triage::triage"], []),
      )
      note = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $1.50, ≤ 4 minutes.

        Short-circuit: if `gate_result != "pass"`, this stage MUST be a no-op. `read_notes` for `gate_result` first and bail with `stage_summary:triage="skipped: gate ${var.scenario_request_label} -> <gate_result>"`.

        Plan (happy path):

        1. `read_notes` for `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_details`, `repo_clone_path`, `existing_scenarios`, `existing_match`.

        2. If `repo_clone_path` is empty, spawn ONE subagent `triage-clone` per orchestration-sop Template B + scenario-triage-sop steps 1-7. Its `goal` MUST inline the full scenario-triage-sop body (subagents cannot see learned skills). The Ubuntu sandbox already has the GitHub PAT in env (`GIT_TOKEN` / `GH_TOKEN`) — the subagent calls `${local.resolved_ubuntu_integration_name}_execute_series` and `git clone https://github.com/<repository_full_name>.git` Just Works. On clone 404, follow §6(c) (post blocked notification via the final stage) and STOP.

        3. After the subagent returns, read `existing_match`. If non-null, the next stage will short-circuit — note `stage_summary:triage="existing match: <existing_match.name>; routing to notify"` and yield.

        4. If `existing_match` is null, confirm the structured notes the next stage needs: `scenario_slug`, `requested_modules`, `requested_integrations`, `talk_track`, `pitch_quote`. If any is empty AND its absence would block scaffolding, prefer `ask_clarifying_question` ONCE over spawning more subagents.

        5. note `stage_summary:triage` with: clone path, scenario_slug (or null), match-or-not, modules requested, integrations requested.

        Forbidden:
        - Spawning a second `triage-*` subagent. Re-cloning the repo. `gh api /repos/.../contents/...` for bulk reads (use the clone).
        - Posting comments here. The `notify-issue-comment` stage owns all comments.
      EOT
    },
    {
      stage_id         = "scaffold-validate-pr"
      agent_ref        = sg_agent.scenario_author.name
      stage_depends_on = ["triage"]
      runbook_refs = [
        sg_runbook_sop.scenario_author_orchestration.name,
        sg_runbook_sop.scenario_scaffold.name,
        sg_runbook_sop.scenario_pr_and_notify.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_scaffold_name, local.sop_pr_and_notify_name],
        try(var.workflow_skill_refs["scenario-request-triage::scaffold-validate-pr"], []),
      )
      note = <<-EOT
        Budget contract: ≤ 2 subagents, ≤ $4.00, ≤ 8 minutes. Reserve ≥ $0.75 for `notify-issue-comment`.

        Short-circuit: this stage is a no-op when ANY of these hold (check `read_notes` first):
          - `gate_result != "pass"`
          - `existing_match` is non-null
          - `scaffold_blocker` is set (e.g. `"conflict"`)
          - `clone_blocker` is set

        In any short-circuit case: note `stage_summary:scaffold-validate-pr="skipped: <reason>"` and yield.

        Plan (happy path):

        1. `read_notes` for `repo_clone_path`, `scenario_slug`, `pitch_quote`, `gap_rationale`, `requested_modules`, `requested_integrations`, `talk_track`, `demo_length`, `issue_details`, `repository_full_name`, `repository_default_branch`, `issue_or_pr_number`, `validation_summary`, `pr_url`.

        2. If `validation_summary` is empty AND `scaffold_summary` is empty: spawn `scaffold-write-and-validate` (orchestration-sop Template C). Its `goal` MUST inline `scenario-scaffold-sop` steps 1-9 verbatim plus the current values of all the notes from step 1. Persist `scaffold_summary`, `validation_summary`.

        3. If `pr_url` is empty AND `working_branch` is empty AND scaffold step succeeded (either `validation_summary` starts with `ok:` OR `failed:`): spawn `scaffold-pr` (orchestration-sop Template D). Its `goal` MUST inline `scenario-pr-and-notify-sop` steps 1-4 verbatim plus current notes. Persist `working_branch`, `pr_url`. If `validation_summary` starts with `failed:`, the subagent MUST add `--draft` to `gh pr create` and prepend `[draft]` to the title.

        4. note `stage_summary:scaffold-validate-pr` with: scenario_slug, branch, PR URL (or blocker), validation outcome, files created (from `scaffold_summary`).

        Approved subagent names: `scaffold-write-and-validate`, `scaffold-pr`. NO other names. NEVER spawn a second scaffold subagent on validation failure — the SOP encodes a single retry inside the first subagent.

        Forbidden:
        - Writing files outside `examples/scenarios/<scenario_slug>/` or appending to `scripts/demo.sh`. ANY edit to `modules/`, `docs/`, `examples/complete/`, root files, CI config, or pre-commit hooks is a hard violation; the subagent MUST `git reset` such changes and re-stage only the scenario.
        - Force-pushing or pushing to `<repository_default_branch>`.
        - `tofu plan` / `tofu apply` / `tofu destroy` — validation is `fmt + init -backend=false + validate` only.
      EOT
    },
    {
      stage_id         = "notify-issue-comment"
      agent_ref        = sg_agent.scenario_author.name
      stage_depends_on = ["scaffold-validate-pr"]
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

        1. `read_notes` for `repository_full_name`, `issue_or_pr_number`, `gate_result`, `existing_match`, `pr_url`, `working_branch`, `scenario_slug`, `validation_summary`, `scaffold_summary`, and ALL `stage_summary:*` keys.

        2. Skip the comment entirely IF AND ONLY IF `gate_result != "pass"` (the gate-fail comment was already posted in `analyze-issue`). In that case, note `stage_summary:notify-issue-comment="skipped: gate-fail comment already posted"` and yield.

        3. Otherwise, spawn EXACTLY one subagent `notify-issue-comment` per orchestration-sop Template E + scenario-pr-and-notify-sop §5. The subagent picks ONE body based on captured notes (first match wins, evaluate in order):
             a) `existing_match` non-null → "Existing scenario match" comment.
             b) Any `stage_summary:*` value contains `budget` (case-insensitive) AND `pr_url` is empty → "Budget exhausted" comment with retry guidance + the day's spend.
             c) Any `stage_summary:*` starts with `blocked:` → "Workflow blocked" comment.
             d) `pr_url` non-empty AND `validation_summary` starts with `ok:` → "Scaffolded a PR" comment.
             e) `pr_url` non-empty AND `validation_summary` starts with `failed:` → "Draft PR (validation failed)" comment.
             f) Else (no PR, no match, no clear blocker — only happens when the agent yielded mid-stage with no notes) → "Triaged, no action taken" comment that also asks the SE to re-open the issue.

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
