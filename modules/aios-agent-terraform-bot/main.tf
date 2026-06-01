terraform {
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner create + install commands (>= 0.1.23); spawn_contracts (>= 0.1.21).
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "terraform-bot"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "terraform-module-manager${local.suffix}"
  workflow_name = "terraform-module-update${local.suffix}"
  webhook_name  = "${local.module_prefix}-github-receiver${local.suffix}"

  sop_orchestration_name        = "${local.module_prefix}-orchestration-sop${local.suffix}"
  sop_install_validate_test     = "${local.module_prefix}-install-validate-test-sop${local.suffix}"
  sop_github_content_change     = "${local.module_prefix}-github-content-change-sop${local.suffix}"
  sop_module_compliance         = "${local.module_prefix}-module-compliance-sop${local.suffix}"
  sop_stackgen_registration     = "${local.module_prefix}-stackgen-registration-sop${local.suffix}"
  sop_discovery_modules_layout  = "${local.module_prefix}-discovery-modules-layout-sop${local.suffix}"
  discovery_modules_enabled     = length(var.discovery_modules_repository_full_names) > 0
  discovery_legacy_issue_labels = ["analyze-request"]
  ubuntu_integration_home       = "/home/integration"
  script_pack_version           = "20260531.37"
  tfbot_pack_dir                = "${local.ubuntu_integration_home}/.terraform-bot/pack/${local.script_pack_version}"
  discovery_modules_template_vars = {
    discovery_repositories_list = join(", ", [for r in var.discovery_modules_repository_full_names : "\"${r}\""])
    discovery_issue_label       = trimspace(var.discovery_modules_issue_label)
    discovery_legacy_labels     = join(", ", [for l in local.discovery_legacy_issue_labels : "\"${l}\""])
    sop_discovery_layout_name   = local.sop_discovery_modules_layout
    sop_install_validate_test   = local.sop_install_validate_test
    stackgen_upload_url         = trimspace(var.stackgen_upload_url)
    stackgen_upload_project_id  = trimspace(var.stackgen_upload_project_id)
    tfbot_pack_dir              = local.tfbot_pack_dir
  }
  discovery_modules_orchestration_addon = local.discovery_modules_enabled ? trimspace(templatefile("${path.module}/templates/discovery-modules-orchestration-addon.md.tftpl", local.discovery_modules_template_vars)) : ""
  discovery_modules_layout_sop_body     = local.discovery_modules_enabled ? trimspace(templatefile("${path.module}/templates/discovery-modules-layout-sop.md.tftpl", local.discovery_modules_template_vars)) : ""
  sop_module_quality                    = "${local.module_prefix}-module-quality-sop${local.suffix}"
  sop_workflow_script_pack              = "${local.module_prefix}-workflow-script-pack${local.suffix}"
  workflow_script_names = [
    "stage-runner.sh",
    "bootstrap-gh-git.sh",
    "mirror-note.sh",
    "clone-and-notes.sh",
    "resolve-module-paths.sh",
    "discovery-exists-check.sh",
    "validate-module.sh",
    "commit-and-pr.sh",
  ]
  workflow_scripts = {
    for name in local.workflow_script_names :
    name => trimspace(file("${path.module}/scripts/${name}"))
  }
  stage_runner_script = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  clone_pack_script   = trimspace(file("${path.module}/scripts/clone-pack.sh"))
  # Inline pack install from Ubuntu integration env (module ubuntu_integration.env_vars). No guild image changes.
  # Heredoc keeps single $ for shell vars in agent-facing strings (never $$ — bash treats $$ as PID; trace c72004698186).
  tfbot_pack_ensure_shell = trimspace(<<-SHELL
PD='${local.tfbot_pack_dir}'; mkdir -p "$PD"; if [ -x "$PD/clone-pack.sh" ] && [ -x "$PD/stage-runner.sh" ]; then :; elif [ -n "$TFBOT_CLONE_PACK_B64" ] && [ -n "$TFBOT_STAGE_RUNNER_B64" ]; then printf '%s' "$TFBOT_CLONE_PACK_B64" | base64 -d >"$PD/clone-pack.sh" && chmod +x "$PD/clone-pack.sh" && printf '%s' "$TFBOT_STAGE_RUNNER_B64" | base64 -d >"$PD/stage-runner.sh" && chmod +x "$PD/stage-runner.sh"; else echo tfbot_pack_error=missing_pack hint=recycle_ubuntu_sidecar_after_tofu_apply_TFBOT_env; exit 1; fi
SHELL
  )
  script_pack_runner_sha256 = sha256(local.stage_runner_script)
  script_pack_clone_sha256  = sha256(local.clone_pack_script)
  clone_execute_series_body = templatefile(
    "${path.module}/templates/clone-execute-series-embedded.sh.tftpl",
    {
      ubuntu_integration_home = local.ubuntu_integration_home
      script_pack_version     = local.script_pack_version
    },
  )
  validate_execute_series_body = templatefile(
    "${path.module}/templates/validate-execute-series-embedded.sh.tftpl",
    {
      ubuntu_integration_home     = local.ubuntu_integration_home
      script_pack_version         = local.script_pack_version
      script_pack_runner_b64      = base64encode(local.stage_runner_script)
      script_pack_runner_sha256   = local.script_pack_runner_sha256
      defer_pr_until_quality_pass = var.defer_pr_until_quality_pass ? "true" : "false"
    },
  )
  commit_pr_execute_series_body = templatefile(
    "${path.module}/templates/commit-pr-execute-series-embedded.sh.tftpl",
    {
      ubuntu_integration_home = local.ubuntu_integration_home
      script_pack_version     = local.script_pack_version
    },
  )
  discovery_scaffold_execute_series_body = templatefile(
    "${path.module}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl",
    {
      ubuntu_integration_home   = local.ubuntu_integration_home
      script_pack_version       = local.script_pack_version
      script_pack_runner_b64    = base64encode(local.stage_runner_script)
      script_pack_runner_sha256 = local.script_pack_runner_sha256
    },
  )
  discovery_scaffold_execute_series_b64       = base64encode(local.discovery_scaffold_execute_series_body)
  discovery_scaffold_execute_series_one_liner = "printf '%s' '${local.discovery_scaffold_execute_series_b64}' | base64 -d | /bin/bash"
  clone_execute_series_b64                    = base64encode(local.clone_execute_series_body)
  clone_execute_series_one_liner              = "printf '%s' '${local.clone_execute_series_b64}' | base64 -d | /bin/bash"
  validate_execute_series_b64                 = base64encode(local.validate_execute_series_body)
  validate_execute_series_one_liner           = "printf '%s' '${local.validate_execute_series_b64}' | base64 -d | /bin/bash"
  workflow_script_pack_body = trimspace(templatefile("${path.module}/templates/workflow-script-pack.md.tftpl", {
    ubuntu_tool_prefix      = local.ubuntu_tool_prefix
    ubuntu_integration_home = local.ubuntu_integration_home
    script_pack_version     = local.script_pack_version
    tfbot_pack_dir          = local.tfbot_pack_dir
  }))
  module_quality_sop_body = trimspace(templatefile("${path.module}/templates/module-quality-sop.md.tftpl", {
    module_quality_max_iterations = var.module_quality_max_iterations
    sop_install_validate_test     = local.sop_install_validate_test
  }))

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

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

  github_tool_prefix = local.resolved_github_integration_name
  ubuntu_tool_prefix = local.resolved_ubuntu_integration_name
  subagent_budget_defaults = {
    script_runner_max_llm_calls     = 8
    github_fetch_max_llm_calls      = 12
    github_comment_max_llm_calls    = 15
    github_notify_max_llm_calls     = 5
    validate_runner_max_llm_calls   = 12
    hcl_author_max_llm_calls        = 20
    script_runner_timeout_seconds   = 300
    github_fetch_timeout_seconds    = 90
    github_comment_timeout_seconds  = 90
    validate_runner_timeout_seconds = 600
    hcl_author_timeout_seconds      = 900
  }
  subagent_budgets = {
    for key, default in local.subagent_budget_defaults :
    key => coalesce(try(var.subagent_budgets[key], null), default)
  }
  create_pr_runner_max_llm_calls     = local.subagent_budgets.script_runner_max_llm_calls + local.subagent_budgets.github_comment_max_llm_calls
  discovery_scaffold_timeout_seconds = local.subagent_budgets.script_runner_timeout_seconds + 300
  orchestration_sop_template_vars = {
    module_prefix                      = local.module_prefix
    github_tool_prefix                 = local.github_tool_prefix
    ubuntu_tool_prefix                 = local.ubuntu_tool_prefix
    ubuntu_integration_home            = local.ubuntu_integration_home
    tfbot_pack_dir                     = local.tfbot_pack_dir
    ubuntu_integration_name            = local.ubuntu_integration_name
    github_integration_name            = local.github_integration_name
    discovery_modules_issue_label      = trimspace(var.discovery_modules_issue_label)
    sop_discovery_modules_layout       = local.sop_discovery_modules_layout
    subagent_budgets                   = local.subagent_budgets
    discovery_scaffold_timeout_seconds = local.discovery_scaffold_timeout_seconds
    create_pr_runner_max_llm_calls     = local.subagent_budgets.script_runner_max_llm_calls + local.subagent_budgets.github_comment_max_llm_calls
  }
  terraform_bot_orchestration_extensions_body = trimspace(templatefile("${path.module}/templates/terraform-bot-orchestration-extensions.md.tftpl", local.orchestration_sop_template_vars))
  terraform_bot_orchestration_sop_body = join("\n\n", compact([
    trimspace(templatefile("${path.module}/templates/terraform-bot-orchestration-sop.md.tftpl", local.orchestration_sop_template_vars)),
    local.terraform_bot_orchestration_extensions_body,
  ]))
  evidence_checklist_name = "${local.module_prefix}-module-update-evidence${local.suffix}"

  persona = templatefile("${path.module}/personas/terraform-module-manager.md.tftpl", {
    module_prefix                 = local.module_prefix
    github_integration_name       = local.resolved_github_integration_name
    ubuntu_integration_name       = local.resolved_ubuntu_integration_name
    github_tool_prefix            = local.github_tool_prefix
    ubuntu_tool_prefix            = local.ubuntu_tool_prefix
    discovery_modules_enabled     = local.discovery_modules_enabled
    sop_discovery_modules_layout  = local.sop_discovery_modules_layout
    discovery_repositories_list   = join(", ", var.discovery_modules_repository_full_names)
    discovery_modules_issue_label = trimspace(var.discovery_modules_issue_label)
    module_quality_max_iterations = var.module_quality_max_iterations
    subagent_budgets              = local.subagent_budgets
  })
}

# =============================================================================
# Owned integrations — provisioned when the consumer hasn't supplied an
# existing one to share. Both bound to `var.github_secret_id`.
# =============================================================================

module "github_integration" {
  count  = trimspace(var.existing_github_integration_name) == "" ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent. Bound to a shared tenant-level PAT secret."
}

# Ubuntu sandbox: PAT via secret_ref_ids → GIT_TOKEN/GH_TOKEN env; gh/git installed at boot.
module "ubuntu_integration" {
  count  = trimspace(var.existing_ubuntu_integration_name) == "" ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids = compact([
    var.github_secret_id,
    trimspace(var.stackgen_token_secret_id) != "" ? var.stackgen_token_secret_id : "",
  ])
  install_tools = ["tofu", "terraform", "gh", "git", "curl"]
  env_vars = {
    TFBOT_PACK_DIR            = local.tfbot_pack_dir
    TFBOT_SCRIPT_PACK_VERSION = local.script_pack_version
    TFBOT_CLONE_PACK_B64      = base64encode(local.clone_pack_script)
    TFBOT_STAGE_RUNNER_B64    = base64encode(local.stage_runner_script)
    TFBOT_CLONE_PACK_SHA256   = local.script_pack_clone_sha256
    TFBOT_STAGE_RUNNER_SHA256 = local.script_pack_runner_sha256
    TFBOT_ALLOW_DIRECT        = "1"
  }
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (OpenTofu/Terraform module work off the Ubuntu sandbox)."
  labels        = var.remote_runner_labels
}

# ============================================================================
# Terraform Module Bot Agent
# ============================================================================

resource "sg_agent" "terraform_module_manager" {
  name        = local.agent_name
  persona     = local.persona
  model_names = compact(var.model_names)

  remote_runners = var.remote_runner_attach_to_agent && length(module.remote_runner) > 0 ? toset([module.remote_runner[0].runner_name]) : null

  integrations = [
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
  ]
}

resource "sg_agent_budget" "terraform_module_manager" {
  agent_name = sg_agent.terraform_module_manager.name
  # The prior workflow run cost $10.74 and exhausted the previous $10 budget
  # before reaching `register-and-notify`. With the new orchestration SOP's
  # per-stage subagent caps the budget should comfortably fit, but $15/day
  # leaves headroom for retries and the StackGen registration step.
  limit_usd   = 15
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "terraform_module_manager_dangerous_ops" {
  agent_name = sg_agent.terraform_module_manager.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# ============================================================================
# Terraform Module Compliance SOP
# ============================================================================

resource "sg_runbook_sop" "terraform_module_compliance" {
  name        = local.sop_module_compliance
  approve     = true
  description = <<-EOT
    Executes a strict compliance and blast radius test loop for Terraform module updates.

    Steps:
    1) Clone the PR branch and its Terraform files using the GitHub integration.
    2) Run static analysis tools like `tfsec` or `checkov` in the Ubuntu CLI environment to identify hardcoded secrets, missing encryption, or open security groups.
    3) Run `terraform plan` and analyze the output to detect resource modifications or deletions. Evaluate these against organizational Rego policies (e.g., blast radius, dangerous ops).
    4) Query the StackGen Context Graph to identify downstream dependent services and verify this update won't introduce breaking changes.
    5) Auto-remediate issues by committing fixes back to the branch, or fail the test loop and report detailed findings.
  EOT
}

# ============================================================================
# StackGen Module Registration SOP
# ============================================================================

resource "sg_runbook_sop" "stackgen_module_registration" {
  name        = local.sop_stackgen_registration
  approve     = true
  description = <<-EOT
    Provides instructions for installing the StackGen CLI and registering a Terraform module into the StackGen module catalog.

    Steps:
    1) Verify if the `stackgen` CLI is installed in the Ubuntu CLI environment (`which stackgen`).
    2) If not installed, install it using Homebrew since it is available at `stackgenhq/homebrew-stackgen`:
       `brew tap stackgenhq/stackgen`
       `brew install stackgen`
       (If Homebrew is unavailable, fallback to: `curl -fsSL https://docs.stackgen.com/install.sh | bash`)
    3) Ensure the `STACKGEN_TOKEN` environment variable is available for authentication.
    4) Use the `stackgen` CLI to register the module in the module's directory.
    5) Capture the output and report the registered module version in the final GitHub PR comment.
  EOT
}

# ============================================================================
# Terraform/OpenTofu Install, Validate, and Unit Test SOP (Ubuntu CLI skill)
# ============================================================================
# This is the "skill" the Terraform Module Manager uses via the Ubuntu CLI
# integration to bootstrap a clean validation/test sandbox for any module under
# review. It installs Terraform or OpenTofu, runs syntactic and semantic
# validation, and authors / executes unit tests using the native `terraform
# test` (or `tofu test`) HCL test framework.

resource "sg_runbook_sop" "terraform_install_validate_test" {
  name        = local.sop_install_validate_test
  approve     = true
  description = <<-EOT
    Skill: Provision an Ubuntu CLI sandbox with Terraform or OpenTofu, validate the module under review, run static security analysis (tfsec / checkov / tflint), and author + run unit tests via the native HCL test framework (`terraform test` / `tofu test`).

    Keywords for skill discovery: terraform, opentofu, tofu, hcl, infrastructure-as-code, IaC, module validation, terraform plan, terraform validate, terraform fmt, terraform init, terraform test, tftest, mock_provider, unit test, static analysis, security scan, tfsec, checkov, tflint, terraform registry, registry.terraform.io, module wrapper, AWS, GCP, Azure, sagemaker, s3, ec2, vpc, iam, rds, eks.

    Use this skill whenever the Terraform Module Manager needs to syntactically and semantically validate a module, run static security analysis (tfsec/checkov), exercise it against representative inputs, or prove that a change is non-breaking before bumping the module version.

    Tool boundary (critical — this is what most failed runs get wrong):
    - All shell commands in this skill MUST be issued via the Ubuntu CLI integration tools (`${local.ubuntu_tool_prefix}_execute_command`, `${local.ubuntu_tool_prefix}_execute_series`, `${local.ubuntu_tool_prefix}_execute_parallel`).
    - The GitHub integration tools (`github-integration_execute_*`) only run `gh` / `curl` HTTP calls — they cannot execute `terraform`, `tofu`, `tfsec`, `checkov`, `git`, `find`, `cat`, `sed`, or any other Linux command. Calling `terraform validate` through `github-integration_execute_*` always fails.

    Prerequisites:
    - Ubuntu CLI integration available to the agent.
    - The module source (PR branch) checked out into the working directory via the GitHub integration.

    Steps:
    1) Detect or install the IaC binary in the Ubuntu CLI environment. Prefer OpenTofu first, then Terraform; never assume either is preinstalled:
       a) `which tofu` — if present, capture `tofu version`.
       b) Else `which terraform` — if present, capture `terraform version`.
       c) Else install OpenTofu non-interactively:
          `curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh && chmod +x /tmp/install-opentofu.sh && /tmp/install-opentofu.sh --install-method deb`
          Fallback (no apt/no root): download the static binary from `https://github.com/opentofu/opentofu/releases` matching the host arch into `$HOME/.local/bin` and add it to `PATH`.
       d) If OpenTofu cannot be installed, install Terraform via HashiCorp's apt repo:
          `curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg`
          `echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list`
          `sudo apt-get update && sudo apt-get install -y terraform`
          Fallback: fetch a versioned zip from `https://releases.hashicorp.com/terraform/` and unzip into `$HOME/.local/bin`.
       e) Export a shell alias so the rest of this skill can call `tf` regardless of which binary won: `alias tf=$(command -v tofu || command -v terraform)`.

    2) Validate the module (all commands via `ubuntu-cli_execute_*`):
       a) `tf fmt -recursive -check` — fail fast on style drift; if `-check` fails, capture the diff and run `tf fmt -recursive` to auto-fix when the workflow is in auto-remediate mode.
       b) `tf init -backend=false -input=false` — initialize providers/modules without touching remote state.
       c) `tf validate -no-color` — surface schema/type errors.
       d) If `tflint` is available run it; otherwise skip with a warning. Do not block on missing optional linters.

    2b) Run static security analysis (tfsec + checkov). This is the canonical home for the org-wide security scan — never re-implement it in a subagent:
       a) Install (or detect) `tfsec`:
          `which tfsec || curl -fsSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash`
       b) `tfsec --no-color --soft-fail --format json . > /tmp/tfsec.json` (use `--soft-fail` so the test loop sees findings without aborting; downstream stages decide severity).
       c) Install (or detect) `checkov`:
          `which checkov || pipx install checkov || (python3 -m venv /tmp/checkov-venv && /tmp/checkov-venv/bin/pip install checkov && export PATH="/tmp/checkov-venv/bin:$PATH")`
       d) `checkov -d . --quiet --soft-fail --output json --output-file-path /tmp/checkov.json`
       e) Summarize both reports into a single findings list keyed by `<rule_id>: <message> @ <file>:<line>`, persist via `note` under key `static_security_findings` so siblings / downstream stages reuse it instead of re-scanning.

    3) Author unit tests using the native HCL test framework (`terraform test` / `tofu test`):
       a) Look for an existing `tests/` directory or `*.tftest.hcl` files. If none exist, scaffold `tests/unit.tftest.hcl` with at least one `run` block per public variable contract.
       b) For each test, prefer `command = plan` blocks that assert on `output`/`resource` attributes so tests run hermetically without provisioning real cloud resources.
       c) When the module exposes provider configuration, inject mock providers via `mock_provider` blocks so unit tests stay offline and deterministic.
       d) Cover at minimum: (i) default inputs produce a valid plan, (ii) required variables are enforced, (iii) any conditional logic (count/for_each) toggled by inputs renders the expected resource shape.

    4) Execute the test suite:
       a) `tf test -verbose` from the module root.
       b) Capture stdout, stderr, and exit code. A non-zero exit code is a hard failure for the test loop.

    5) Report:
       a) Summarize installed binary + version, validation outcome, list of tests run, and pass/fail counts.
       b) Attach the raw `tf test` output (truncated to the last 200 lines) to the workflow context so downstream stages and the final GitHub PR comment can quote it.
       c) On failure, include the failing assertion(s) and a suggested next action (fix code vs. fix test vs. classify as breaking change).
  EOT
}

# ============================================================================
# GitHub Content Change SOP (Ubuntu CLI skill, gh CLI based)
# ============================================================================
# This is the "fast path" skill the Terraform Module Manager uses for any
# git-content mutation against a GitHub repo: clone the PR branch, create a
# working branch, commit edits, push, and open / update a Pull Request. It
# deliberately uses the `gh` CLI directly in the Ubuntu CLI sandbox instead of
# round-tripping every step through the GitHub Guild integration, which is
# noticeably slower for multi-file changes.

resource "sg_runbook_sop" "github_content_change" {
  name        = local.sop_github_content_change
  approve     = true
  description = <<-EOT
    Skill: Use the GitHub `gh` CLI from the Ubuntu CLI sandbox to clone a repository, read / scan repo files locally, author file changes on a working branch, push, and open or update a Pull Request — without paying the per-call latency of the high-level GitHub Guild integration.

    Keywords for skill discovery: github, gh cli, clone repo, pull request, pr create, pr comment, pr checkout, branch, commit, push, fetch repo, list files, read files, scan repository, source code, multi-file edit, terraform, hcl, IaC, content change, auto-remediate.

    Anti-pattern (the most common time-sink in past runs):
    - Do NOT read source files one at a time via `gh api /repos/<o>/<r>/contents/<path>` with `--jq '.content' | base64 -d`. That fans out N HTTP calls per file, hits auto-summarization on large responses, and forces re-fetches. Clone the repo ONCE with `git clone` via `${local.ubuntu_tool_prefix}_execute_command` and read locally with `cat` / `find` / `rg`.
    - Do NOT spawn a subagent just to fetch repo contents; clone, list, read.

    Use this skill whenever a workflow stage needs to:
    - Clone a repo or a specific PR branch.
    - Read / inspect / scan source files in a repo (always from a local clone, never per-file API).
    - Apply file edits / auto-remediations across one or more files.
    - Commit, push, and open a new Pull Request, or update an existing one with new commits / comments.

    Prerequisites:
    - Ubuntu CLI integration available to the agent, with `github_secret_id` bound via `secret_ref_ids` (see `terraform-bot-orchestration-sop` §0a). The sandbox surfaces `GIT_TOKEN` / `GH_TOKEN` at launch — never capture or persist tokens in notes.
    - `gh` is installed at container boot via `INSTALL_TOOLS` (this module sets `install_tools` to include `gh`). Subagents may still run `which gh` as a sanity check; only install manually if the binary is missing after boot.

    Steps:
    1) Bootstrap `gh` + git auth from the Ubuntu sandbox env (run once per subagent `execute_series`; never echo token values):
       a) `GIT_TOKEN="$${GIT_TOKEN:-$${GITHUB_TOKEN:-$${GH_TOKEN:-}}}}"` then `export GH_TOKEN="$$GIT_TOKEN" GITHUB_TOKEN="$$GIT_TOKEN"`.
       b) If `GIT_TOKEN` is empty: STOP and surface "no GitHub token in Ubuntu env" per orchestration-sop §8(a) — do NOT run `gh auth token` or fetch a token via the GitHub integration.
       c) `gh auth setup-git` — fail the series if setup-git errors (do NOT run `gh auth login`; `GH_TOKEN`/`GITHUB_TOKEN` authenticate `gh` from the environment).
       d) `git config --global user.name "stackgen-terraform-bot"` and `git config --global user.email "terraform-bot@stackgen.local"`.
       e) Fallback only if `which gh` fails: install via apt or tarball (same commands as before), then repeat (a)–(d).

    2) Clone or fetch the repo (one time, reuse the clone for all reads + writes in this workflow run):
       a) Set `WORK_ROOT=$HOME/.<workflow_run_id>` from the stagerunner `[Workflow execution]` header. Clone to `"$WORK_ROOT/repo"` via `git clone` (script-pack §2.1) or `gh repo clone <owner>/<repo> "$WORK_ROOT/repo"`.
       b) When the workflow is reacting to an existing PR, prefer `gh pr checkout <pr_number> --repo <owner>/<repo>` from inside the clone — it lands you on the contributor's branch directly.
       c) Configure a non-interactive git identity once per sandbox: `git config --global user.name "stackgen-terraform-bot"` and `git config --global user.email "terraform-bot@stackgen.local"`.
       d) Persist the clone path via `note` under key `repo_clone_path` so downstream stages reuse the same working tree instead of cloning again.

    2b) Read repo contents from the clone (never via `gh api /contents/...` for bulk reads):
       a) `find "$WORK_ROOT/repo" -name '*.tf' -not -path '*/.terraform/*'` to enumerate IaC files.
       b) `cat`, `rg`, `sed`, `head` files directly from the local clone via `${local.ubuntu_tool_prefix}_execute_command`.
       c) Use `${local.ubuntu_tool_prefix}_execute_parallel` to read multiple files in one round-trip when scanning module directories.

    3) Create / switch to a working branch (skip if already on the PR branch from step 2b):
       a) `git switch -c terraform-bot/<short-slug>-$(date +%Y%m%d%H%M%S)` for new work.
       b) `git switch <existing-branch>` when updating a branch that already exists.

    4) Apply edits in the working tree using the Ubuntu CLI (use file tools, `sed`, scaffolders, or the install/validate/test skill). Keep the diff focused — one logical change per commit.

    5) Commit and push:
       a) `git add -A`
       b) `git commit -m "<conventional commit message>"` — include the originating issue/PR number in the body when known.
       c) `git push -u origin HEAD` (the token from step 1c authenticates this push).

    6) Open or update the Pull Request:
       a) Prefer `stage-runner.sh commit-pr` (script-pack §2.3): it derives an IaC-quality **title** and **body** from the staged diff, `.stackgen/stackgen.yaml`, README lede, validation notes (`quality_check_*`, `module_quality_summary`), and the originating issue. Do **not** use `gh pr create --fill` or one-line bodies.
       b) Title pattern: `feat(<provider>): add <human-readable module purpose> module` for new discovery modules; `feat(<provider>): update …` for edits. Use the StackGen `description` or README summary — never raw snake_case directory names alone.
       c) Body must include: **Summary**, **Motivation** (`Closes owner/repo#N`), **What's included** (paths + file list), **Terraform resources**, **Validation** table, **Reviewer notes**. Write for module maintainers, not bots.
       d) If no PR exists for the branch: `gh pr create --base main --head "$(git branch --show-current)" --title "<title>" --body-file pr-body.md`.
       e) If a PR already exists: push commits; optionally `gh pr edit` to refresh title/body when scope changed materially.
       f) Capture the PR URL from `gh pr list --head <branch> --json url` or `gh pr view --json url` and note `pr_title` + `pr_url`.

    7) Cleanup:
       a) Leave the clone in place during the workflow run so subsequent stages can reuse it.
       b) Do not force-push to branches you did not create. Never push to `main`/`master` directly.

    Failure modes to handle explicitly:
    - `gh auth status` returns non-zero -> stop and surface "missing GitHub token" to the workflow; do not attempt anonymous clones for private repos.
    - `git push` rejected (non-fast-forward) -> fetch + rebase the working branch onto its upstream, re-run validation/tests, then push again.
    - `gh pr create` returns "a pull request already exists" -> switch to update mode (step 6b) using the existing PR number.
  EOT
}

# ============================================================================
# Terraform Bot Orchestration SOP (meta-skill: integration boundaries,
# subagent budgets, context hygiene)
# ============================================================================
# This is the "lead" runbook for the Terraform Module Manager. It is attached
# to every stage so the agent — and any subagent it spawns — knows which
# integration owns which command, how to scope tool budgets, and how to avoid
# the context-blowup loops observed in past runs (per-file `gh api` fetches,
# duplicate refetches after auto-summarization, subagents spawned without the
# Ubuntu CLI toolset).

resource "sg_runbook_sop" "discovery_modules_layout" {
  count       = local.discovery_modules_enabled ? 1 : 0
  name        = local.sop_discovery_modules_layout
  approve     = true
  description = local.discovery_modules_layout_sop_body
}

resource "sg_runbook_sop" "module_quality" {
  name        = local.sop_module_quality
  approve     = true
  description = local.module_quality_sop_body
}

resource "sg_runbook_sop" "workflow_script_pack" {
  name        = local.sop_workflow_script_pack
  approve     = true
  description = local.workflow_script_pack_body
}

resource "sg_runbook_sop" "terraform_bot_orchestration" {
  name    = local.sop_orchestration_name
  approve = true
  description = join("\n\n", compact([
    local.discovery_modules_orchestration_addon,
    local.terraform_bot_orchestration_sop_body,
  ]))
}

# =============================================================================
# Evidence checklist — proof-of-work for terraform-module-update
# =============================================================================

resource "sg_evidence_checklist" "terraform_module_update_evidence" {
  name        = local.evidence_checklist_name
  description = "Proof-of-work for GitHub-driven module update: trigger captured, clone ok, module implemented, validate/test PASS, PR opened or blocker documented."
  approve     = true
  required_items = [
    "trigger_payload_recorded",
    "repo_clone_materialized",
    "module_paths_or_blocker_documented",
    "validation_summary_recorded",
    "quality_checks_pass_or_blocked",
    "pr_url_or_blocker_documented",
  ]
  optional_items = [
    "pr_url_or_pr_deferred",
    "deployment_impact_summary",
    "registry_wrap_evidence",
    "stackgen_registration_evidence",
  ]
  scoring = {
    min_required         = 5
    confidence_threshold = 0.8
  }
  metadata = {
    playbook = "terraform-module-update"
  }
}

resource "sg_workflow" "terraform_module_update" {
  name        = local.workflow_name
  domain      = "infrastructure-as-code"
  description = <<-EOT
    GitHub issue/PR-driven Terraform module workflow (linear): `check-info-and-clone` → `check-info-blocked-gate` → `implement-module` → `validate-greenfield-skip-gate` → `validate-and-test` → `validate-infra-gate` → `validate-draft-pr-gate` → `validate-loop-gate` → `create-pr`.
    Cross-stage state uses planner `note` + stage closing message echo (orchestration SOP §3a–§3b); disk mirror at `$HOME/.<workflow_run_id>/notes.json` when the Ubuntu container is warm. Shell work uses ONE `execute_series` with embedded stage-runner (script-pack §3h). Copy `workflow_run_id` from stagerunner `[Workflow execution]` header.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations       = "40"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling"
  }

  evidence_checklist_ref = sg_evidence_checklist.terraform_module_update_evidence.name

  triggers = [
    { field = "event_type", values = ["issue.created", "pull_request.opened"], type = "active", source = "github" }
  ]

  runbook_refs = concat(
    [
      sg_runbook_sop.terraform_bot_orchestration.name,
      sg_runbook_sop.workflow_script_pack.name,
      sg_runbook_sop.terraform_module_compliance.name,
      sg_runbook_sop.terraform_install_validate_test.name,
      sg_runbook_sop.github_content_change.name,
      sg_runbook_sop.stackgen_module_registration.name,
      sg_runbook_sop.module_quality.name,
    ],
    local.discovery_modules_enabled ? [sg_runbook_sop.discovery_modules_layout[0].name] : [],
  )

  required_inputs = ["repository_url", "issue_or_pr_number"]
  optional_inputs = ["requested_change"]

  example_queries = [
    "A developer opened an issue on the terraform repo asking to fix the RDS module to support encryption by default",
    "Analyze issue #45 for the networking module and implement the requested subnet changes if compliant",
    "Issue #12: add a new aws-ecs-blue-green module — search the Terraform Registry for a suitable ECS module, wrap it with tests, and open a PR"
  ]

  stages = [
    {
      stage_id    = "check-info-and-clone"
      description = "Validate trigger payload, discovery label gate, fetch issue context, and clone the repo into the Ubuntu workdir"
      note        = "Step 1: check info + clone to `$WORK_ROOT/repo` when missing."
      required    = true
    },
    {
      stage_id    = "check-info-blocked-gate"
      description = "Skip to create-pr when clone/auth failed in check-info-and-clone"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "implement-module"
      description = "Interpret the requirement and create or update Terraform modules with correct directory layout and unit tests"
      note        = "Step 2: module structure, registry wrap / discovery scaffold / greenfield (Templates H/G/I), author tests."
      required    = true
    },
    {
      stage_id    = "validate-greenfield-skip-gate"
      description = "Skip validate-and-test when discovery greenfield already ran scaffold+validate in one embed"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "validate-and-test"
      description = "Run Terraform/OpenTofu fmt, init, validate, and test; remediate once if needed"
      note        = "Step 3: terraform validate commands + tftest; emit quality_check_* and module_quality_summary."
      required    = true
    },
    {
      stage_id    = "validate-infra-gate"
      description = "Skip quality rework loop when validate failed due to Ubuntu/integration infra, not module code"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "validate-draft-pr-gate"
      description = "Skip rework loop when a draft PR was opened for quality failures"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "validate-loop-gate"
      description = "Loop back to implement-module when validate did not reach PASS (bounded)"
      note        = "loop_stage only — no LLM."
      required    = false
    },
    {
      stage_id    = "create-pr"
      description = "Commit, push, open the pull request, comment on the issue, optional StackGen registration"
      note        = "Step 4: PR + user-visible GitHub comment."
      required    = true
    }
  ]

  stage_bindings = [
    {
      stage_id  = "check-info-and-clone"
      agent_ref = sg_agent.terraform_module_manager.name
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["terraform-module-update::check-info-and-clone"], []),
      )
      spawn_contracts = local.spawn_contracts_check_info_and_clone
      note            = <<-EOT
        TFBOT_STAGE_RUNNER_SHA256=${local.script_pack_runner_sha256}
        TFBOT_CLONE_PACK_SHA256=${local.script_pack_clone_sha256}
        script_pack_version=${local.script_pack_version}
        Budget contract: ≤ 2 subagents, ≤ $1.00, ≤ 3 minutes.

        **Step 1 — check info + clone (MANDATORY ORDER — trace `9d8958e4` failed when clone ran before notes)**
        0. Read `[Workflow execution]` → `workflow_run_id`; spawn contract resolves `WORK_ROOT={{work_root}}` to the absolute scratch path (Ubuntu home is often `/home/integration`, not `/root`).
        1. **FIRST — note trigger keys (no subagents yet):** parse webhook JSON from stage Input per orchestration §0b. `note()` each: `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_or_pr_number`, `event_type`, `issue_labels`, `pr_head_ref`, `pr_head_clone_url`. Missing repo or issue # → §8(a) blocked notify and STOP.
        2. Discovery label gate (when `discovery_repo=true`): evaluate `${local.sop_discovery_modules_layout}` §1. On `missing_label` → spawn ONE `create-pr-comment` (Template E, GitHub path only), STOP.
        3. Build `issue_details` JSON from parsed webhook fields (§0b step 3) when `issue.title` or `pull_request.title` is present — **do NOT** spawn `check-info-and-clone-fetch`. Fetch ONLY when title is absent after JSON parse.
        4. **Only after steps 1–3:** if `repo_clone_path` empty, spawn ONE `check-info-and-clone-clone`. **Subagent goal MUST match the spawn contract verbatim** — never `load_skill terraform-bot-workflow-script-pack` or `_embed_tfbot_run` (trace `9d8958e4`). Pass **context** lines: `repository_clone_url=…`, `repository_default_branch=…`, `issue_or_pr_number=…` so the clone runner uses spawn-context inline pack ensure + `${local.tfbot_pack_dir}/clone-pack.sh clone` (requires `TFBOT_*_B64` on Ubuntu integration env — recycle sidecar after apply). Runner: ONE execute_series — `working_dir=${local.ubuntu_integration_home}` or omit; **never** `working_dir=WORK_ROOT` before clone. **FORBIDDEN:** `TRIGGER_JSON='{"…"}'` in `commands[0].command`; `CLONE_ONE_LINER`; truncating commands.
        5. **Clone outcome:** BLOCKED when `clone_blocker=*` OR `repo_clone_path` empty. `tfbot_pack_error=` → **§8(g)** (`tofu apply` + recycle `terraform-bot-ubuntu`). `base64: invalid input` on pack ensure with TFBOT env present → `clone_blocker=wrong_shell_dollar_escape` (**$$** in execute_series — use single **$**; trace `c72004698186`). `base64: invalid input` with empty TFBOT env → missing_script_pack. **FORBIDDEN** ad-hoc `git clone` or HTTPS token clone fallback (PAT may be fine). `clone_blocker=placeholder_url` → **agent invented URL**. `clone_blocker=auth_or_network` → PAT/scope. If `gh_env_present=false` but `repo_clone_path` set (public clone), note `clone_auth_mode=anonymous` + `push_requires_token=true` and **continue**.
        6. `note` one `workflow_notes_snapshot` JSON (§3i) + `stage_summary:check-info-and-clone` + echo handoff keys (§3b).

        Forbidden: spawning clone before step 1 notes; placeholder clone URLs; `graph_query`; org-wide `gh repo list`; auth-verify-only subagents; `check-info-and-clone-fetch` when webhook has `issue.labels` + `issue.title`; `create-pr-notify` on clone failure in this stage; `load_skill` on clone runner; `working_dir=WORK_ROOT` or `working_dir=$HOME/.wf-*` on clone execute_series; raw PAT in goals; `{}` execute_series payloads; `/root/.wf-*` paths.
      EOT
    },
    {
      stage_id         = "check-info-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["check-info-and-clone"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)stage_summary:check-info-and-clone[=:\"\\s]+blocked:|stage_summary:implement-module[=:\"\\s]+blocked:|clone_blocker=(auth|auth_or_network|network|404|branch|placeholder_url|missing_clone_params|repo_not_found_or_auth|missing_script_pack|wrong_shell_dollar_escape)|chdir .+\\.wf-[^:]+: no such file or directory|base64: invalid input|omitted for brevity|unexpected EOF while looking for matching|syntax error|parse error near|Syntax error:.*unexpected|_embed_tfbot_run.*command not found|script_pack_error=|tfbot_pack_error=|scaffold_error=|missing_stage_runner|exit 127|command not found|clone-pack\\.sh: not found|Syntax error.*unexpected|ubuntu_shell_incompatible|example/example"
        skip_to   = "create-pr"
        reason    = "Clone/auth failed at intake — skip implement/validate; create-pr posts operator-facing blocker comment"
      }
    },
    {
      stage_id         = "implement-module"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["check-info-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.terraform_install_validate_test.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_install_validate_test],
        local.discovery_modules_enabled ? [local.sop_discovery_modules_layout] : [],
        try(var.workflow_skill_refs["terraform-module-update::implement-module"], []),
      )
      spawn_contracts = local.spawn_contracts_implement_module
      note            = <<-EOT
        Budget contract: ≤ 1 subagent for discovery greenfield, ≤ 3 subagents otherwise, ≤ $4.00, ≤ 10 minutes.

        **Step 2 — requirement + module layout + tests**
        **Stage entry (§3a):** `read_notes` + `[Workflow execution]` + prior stage message; recover from `check-info-and-clone` echo if empty. Honor `[SubagentFailure]` — fix root cause before retry.
        **Canonical clone path:** `repo_clone_path` MUST be `$WORK_ROOT/repo` (stage-runner §2.1). If notes say `repo_clone`, treat as legacy — downstream script-pack normalizes via symlink.
        **Blocked passthrough:** when `repo_clone_path` is empty or notes contain `clone_blocker` — emit `stage_summary:implement-module=blocked: upstream clone failed` without spawning Ubuntu runners; do not scaffold into an empty workdir.
        **Quality-loop rework:** when prior `validate-and-test` had `module_quality_summary: NEEDS_REVISION` (code FAIL, not BLOCKED) and `module_paths` is non-empty — spawn **Template J** (orchestration §5i/§7): one subagent, goal ≤800 chars (host replaces with spawn contract). Fix `module_quality_gaps` only using `test_summary_tail` from notes — do NOT re-scaffold or paste fix scripts into the spawn goal. `discovery_repo=true` → `implement-module-discovery-scaffold` only (never `implement-module-scaffold`). Inline validate via spawn-context Validate in the same execute_series — do NOT spawn `validate-and-test-runner` here.
        **Routing honesty:** `validate-greenfield-skip-gate` skips `validate-and-test` ONLY when inline validate was **PASS** (`discovery_greenfield_validated=true` AND `module_quality_summary: PASS`). On NEEDS_REVISION, `validate-and-test` still runs; a **draft** PR opens there when `fmt_exit=0` and `validate_exit=0` even if tests fail (fixture-only gaps).
        1. Resolve target module per orchestration §2a or script-pack §2.4: spawn ONE Ubuntu subagent — ONE execute_series with `resolve-paths` embedded (script-pack §0). Light layout discovery only — deep validate belongs in `validate-and-test`. Do NOT open PR here.
        2. Branch:
           - `not_found` + greenfield + `discovery_repo=true`: spawn **ONLY** `implement-module-discovery-scaffold` — ONE execute_series with spawn-context Discovery command (`TRIGGER_JSON_B64` + `${local.tfbot_pack_dir}/stage-runner.sh discovery-scaffold '{{work_root}}'` — same pack path as clone-pack; **never** `"$WORK_ROOT/.pack/stage-runner.sh"`). Pass real base64 for webhook JSON. Echo `discovery_greenfield_validated=true` plus `quality_check_*` / `module_quality_summary` from stdout. **FORBIDDEN:** inline `TRIGGER_JSON='{…}'`, `WORK_ROOT='$HOME/.wf-*'` with `$WORK_ROOT/.pack/...`, placeholder TRIGGER_JSON_B64, `DISCOVERY_SCAFFOLD_ONE_LINER`. Do **NOT** spawn `validate-and-test-runner`, `implement-module-scaffold`, or `implement-module-clone`.
           - `not_found` + greenfield + generic repo: Template H then G if registry fails.
           - `ambiguous` → `ask_clarifying_question` ONCE.
           - `exact`/`probable` → edit existing paths in ONE execute_series when shell edits suffice.
        3. Author `basic.tftest.hcl` at module root (discovery) or `tests/*.tftest.hcl` (generic) when missing — inside the same execute_series as scaffold/edits.
        4. `note` one `workflow_notes_snapshot` JSON (§3i) + `stage_summary:implement-module` + echo `module_paths` (single path when greenfield), confidence, registry keys.

        Approved subagents ONLY: `implement-module-discovery-scaffold`, `implement-module-registry-wrap`, `implement-module-scaffold` (non-discovery only).
        Forbidden: `implement-module-clone`, `validate-and-test-runner`, `create-pr-runner`, `create-pr-notify`, `create-pr-comment`, `create-pr-register`, `create-pr-evidence-submit`, `load_skill` when spawn context has `---BEGIN DISCOVERY_SCAFFOLD_EXECUTE_SERIES---`, `gh pr create`, split create_files + validate across tool calls, dual module dirs for one issue, spawning validate runners in this stage.
      EOT
    },
    {
      stage_id         = "validate-greenfield-skip-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["implement-module"]
      action_config = {
        condition = "output_matches_regex"
        match     = "discovery_greenfield_validated[^\\n]{0,48}true.*module_quality_summary[^\\n]{0,48}PASS"
        skip_to   = "validate-infra-gate"
        reason    = "Discovery greenfield inline validate already PASS — skip duplicate validate-and-test stage"
      }
    },
    {
      stage_id         = "validate-and-test"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["validate-greenfield-skip-gate"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.terraform_install_validate_test.name,
        sg_runbook_sop.module_quality.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_install_validate_test, local.sop_module_quality],
        local.discovery_modules_enabled ? [local.sop_discovery_modules_layout] : [],
        try(var.workflow_skill_refs["terraform-module-update::validate-and-test"], []),
      )
      spawn_contracts = local.spawn_contracts_validate_and_test
      note            = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $3.00, ≤ 8 minutes.

        **Step 3 — fmt / init / validate / test**
        **Architect role:** spawn exactly ONE `validate-and-test-runner`, then read stdout `key=value` markers (`fmt_exit=`, `module_quality_summary=`, `validate_markers_file=`, `test_summary_file=`, `test_summary_tail=` when `test_exit=1`) — copy `test_summary_tail` verbatim into `workflow_notes_snapshot`; do NOT re-summarize runner prose or spawn implement subagents.
        1. Require non-empty `module_paths` or documented blocker; if empty without blocker → STOP with notify.
        2. Spawn exactly ONE `validate-and-test-runner` with `max_llm_calls=${local.subagent_budgets.validate_runner_max_llm_calls}`, `task_type=terminal_calling`. Runner MUST use spawn-context Validate command: `${local.tfbot_pack_dir}/stage-runner.sh validate-and-pr` with `MODULE_PATH` (absolute), `REPO_FULL_NAME`, `ISSUE_OR_PR`, `BASE_BRANCH` from notes — **FORBIDDEN:** `VALIDATE_ONE_LINER`, inline `TRIGGER_JSON='{…}'`, `Syntax error: Unterminated quoted string` from pasting base64 one-liners. If `[stop_agent_error] max LLM calls` → re-spawn once with +10 (cap 60) and a smaller goal — never a second runner name.
        3. **Infra vs code (module-quality-sop §2b–§2c):** BLOCKED when the runner never executed real shell — synthesized PASS lines, forbidden keys (`quality_check_terraform`, `quality_check_module_layout`), or stdout missing `fmt_exit=` from stage-runner validate. Emit `quality_check_*: BLOCKED` and `module_quality_summary: BLOCKED` — do **NOT** set `module_quality_rework=true`. Retry the same runner at most once after §8(e) infra backoff; then BLOCKED.
        4. Map real exit codes to sentinels (module-quality-sop §2): `quality_check_fmt`, `quality_check_validate`, `quality_check_test`, then `module_quality_summary: PASS|NEEDS_REVISION`. On NEEDS_REVISION (code FAIL only), include `module_quality_rework=true` in `workflow_notes_snapshot`.
        5. **PR gate (default):** open PR only when `fmt_exit=0`, `init_exit=0`, `validate_exit=0` (`pr_eligible_fmt_validate=true`) — **never** when init or validate failed (`pr_deferred=init_failed` / `validate_failed`). **Draft** when `test_exit≠0` (fixture gaps OK). `defer_pr_until_quality_pass=false` waits for full `module_quality_summary=PASS` (tests too). Init/validate failures → rework loop + GitHub comment at `create-pr`, not a PR.
        6. `note` one `workflow_notes_snapshot` JSON (§3i) + `stage_summary:validate-and-test` + echo sentinel lines and `pr_url` / `working_branch` / `pr_draft` when validate runner opened a PR in-shell.
        7. When `pr_url` is set, `create-pr` comments only. When `pr_eligible_fmt_validate=true` but `pr_url` empty, copy `pr_deferred=` from stdout (`missing_repo_or_issue`, `push_auth`, `commit_failed`) — `create-pr` must run `create-pr-runner` (step 3b). Do not treat bare `pr_deferred=true` in notes as policy; use runner reason strings only.

        Forbidden: `implement-module-discovery-scaffold`, `implement-module-scaffold`, `implement-module-registry-wrap`, `create-pr-runner`, `create-pr-comment`, `create-pr-register`, `create-pr-evidence-submit`, `load_skill`, `VALIDATE_ONE_LINER`, inline `TRIGGER_JSON`, more than two validate runners per stage invocation, PASS without `fmt_exit=` in runner stdout, NEEDS_REVISION when infra BLOCKED, printf-only execute_series.
      EOT
    },
    {
      stage_id         = "validate-infra-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["validate-and-test"]
      action_config = {
        condition = "output_matches_regex"
        match     = "module_quality_summary[^\\n]{0,40}BLOCKED|quality_check_fmt[^\\n]{0,40}BLOCKED|quality_check_validate[^\\n]{0,40}BLOCKED|quality_check_test[^\\n]{0,40}BLOCKED|quality_check_terraform|quality_check_module_layout|workspace unavailable|Ubuntu MCP sidecar unavailable|terraform-bot-ubuntu integration pod|validation_error=missing_fmt_exit_marker"
        skip_to   = "create-pr"
        reason    = "Integration infra failure — skip quality rework loop; create-pr posts blocked summary on GitHub"
      }
    },
    {
      stage_id         = "validate-draft-pr-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["validate-infra-gate"]
      action_config = {
        condition = "output_matches_regex"
        match     = var.continue_quality_loop_after_draft_pr ? "pr_url=https://github\\.com/[^\\s]+" : "pr_url=https://github\\.com/[^\\s]+|pr_eligible_fmt_validate[^\\n]{0,40}true"
        skip_to   = "create-pr"
        reason    = "fmt+init+validate passed (or PR already open) — skip test-fixture rework loop; create-pr opens draft PR + issue comment"
      }
    },
    {
      stage_id         = "validate-loop-gate"
      action_type      = "loop_stage"
      stage_depends_on = ["validate-draft-pr-gate"]
      action_config = {
        loop_to        = "implement-module"
        max_iterations = var.module_quality_max_iterations
        exit_condition = "output_contains"
        exit_match     = "module_quality_summary[^\\n]{0,48}(PASS|BLOCKED)"
      }
    },
    {
      stage_id         = "create-pr"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["validate-loop-gate"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.stackgen_module_registration.name,
        sg_runbook_sop.github_content_change.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_stackgen_registration, local.sop_github_content_change],
        local.discovery_modules_enabled ? [local.sop_discovery_modules_layout] : [],
        try(var.workflow_skill_refs["terraform-module-update::create-pr"], []),
      )
      spawn_contracts = local.spawn_contracts_create_pr
      note            = <<-EOT
        Budget contract: ≤ 2 subagents, ≤ $2.00, ≤ 4 minutes.

        **Step 4 — notify (+ optional register; PR may already exist)**
        **Deliverable when `pr_url` is set:** ONE GitHub issue comment (Template E) linking the draft PR and `test_summary_tail` when present — that satisfies the workflow for human review. `create-pr-register`, full `module_quality_summary: PASS`, and `submit_evidence` are **optional** — do not block the comment.
        **Same branch on rework:** when the loop runs (`continue_quality_loop_after_draft_pr=true`) or validate-and-test re-runs `validate-and-pr`, `commit-pr` reuses `working_branch` and pushes to the existing PR head (no second PR).
        0. If predecessor JSON has `"action":"GO_BACK"` → **blocked** (`stage_summary:create-pr=blocked:loop_not_finished`). Do NOT rework here; loop gate must finish first.
        1. One `read_notes` at stage entry (§3a); parse predecessor loop-gate JSON. When `Reason` contains `max iterations reached`:
           - **Default (`draft_pr_on_max_iterations_exhausted=true`):** if `module_paths` non-empty **and** `pr_eligible_fmt_validate=true` (or `init_exit=0` + `validate_exit=0` in notes) → ONE `create-pr-runner`; if init/validate never passed → ONE `create-pr-notify` only (no PR). Empty `module_paths` → Template E only.
           - **Notify-only (`draft_pr_on_max_iterations_exhausted=false`):** spawn ONE `create-pr-notify` (Template E) with partial progress — **no** `create-pr-runner`.
        2. **Infra BLOCKED path** (`module_quality_summary: BLOCKED` or any `quality_check_*: BLOCKED`): spawn ONE `create-pr-notify` (Template E, GitHub-only, ≤5 LLM) explaining Ubuntu sidecar failure and what was scaffolded; do NOT spawn `create-pr-runner` or `create-pr-register`. Architect runs `submit_evidence` directly — never spawn `create-pr-evidence-submit`.
        2b. **Push auth BLOCKED path** (`module_quality_summary: PASS` but `push_requires_token=true`, `pr_blocker=auth`, or `clone_auth_mode=anonymous`): spawn ONE `create-pr-notify` (Template E) — module validated locally but PAT missing for push/PR; include `module_paths` and validation summary; operator binds Provider/github PAT to ubuntu `secret_ref_ids` and re-triggers.
        3. **Early draft PR path (default):** when `pr_url` is already in notes from `validate-and-test` → spawn **only** `create-pr-comment` / `create-pr-notify` (GitHub issue comment with PR link + validation summary). Skip `create-pr-runner`. Optional: `create-pr-register` when token present; skip register without blocking.
        3a. **Happy path (no `pr_url` yet)** requires `module_quality_summary: PASS`, all `quality_check_*: PASS`, non-empty `module_paths`, no `stage_summary:*` starting with `blocked:`, and `push_requires_token` not `true`.
        3b. **Draft test-fail path:** when `pr_eligible_fmt_validate=true` (fmt+init+validate passed), `module_quality_summary: NEEDS_REVISION` (tests/fixtures only), `pr_url` empty, `module_paths` non-empty — spawn ONE `create-pr-runner` then issue comment. **FORBIDDEN** when `init_exit≠0` or `validate_exit≠0` — use `create-pr-notify` with `module_quality_gaps` instead.
        4. Happy + no `pr_url`: spawn ONE `create-pr-runner` — ONE Ubuntu series (embedded COMMIT_PR block) then ONE GitHub series (issue comment). If runner returns `pr_blocker=auth`, fall back to §2b — do not retry commit-pr in a loop.
        5. Happy + discovery: optionally spawn `create-pr-register` when `STACKGEN_TOKEN` present; else `registration_skipped=missing_stackgen_token` in snapshot.
        6. **Evidence gate (§3f):** `submit_evidence` for checklist `${local.evidence_checklist_name}` before happy-path comment.
        7. `note` one `workflow_notes_snapshot` JSON (§3i) + `stage_summary:create-pr` with `pr_url` or blocker. Echo critical keys in final message.

        Approved names: `create-pr-runner`, `create-pr-register`, `create-pr-notify`, `create-pr-comment` (alias — prefer `create-pr-notify` for blocked/max-iter notify). Do not spawn separate `create-pr-open` + notify on happy path. FORBIDDEN: `create-pr-evidence-submit`, `load_skill` when spawn context has `---BEGIN *_EXECUTE_SERIES---`.
      EOT
    }
  ]
}


# ============================================================================
# Webhook Ingress for GitHub
# ============================================================================

resource "sg_webhook" "github_pr_issue" {
  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.terraform_module_update.name
  action      = "A new GitHub issue or PR was created in a Terraform module repository (including StackGen discovery-modules repos when configured). Triage the payload, determine whether the target module exists, scaffold discovery templates when missing, run validate/security/test, and initiate the module update workflow."
  enabled     = true
}
