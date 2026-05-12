terraform {
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
    }
  }
}

# ============================================================================
# Terraform Module Bot Agent
# ============================================================================

resource "sg_agent" "terraform_module_manager" {
  name        = "terraform-module-manager"
  persona     = file("${path.module}/personas/terraform-module-manager.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]

  integrations = compact([
    var.integration_names.github,
    var.integration_names.ubuntu_cli
  ])
}

resource "sg_agent_budget" "terraform_module_manager" {
  agent_name  = sg_agent.terraform_module_manager.name
  limit_usd   = 10
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
  name        = "terraform-module-compliance-sop"
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
  name        = "stackgen-module-registration-sop"
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
  name        = "terraform-install-validate-test-sop"
  description = <<-EOT
    Skill: Provision an Ubuntu CLI sandbox with Terraform or OpenTofu, validate the module under review, run static security analysis (tfsec / checkov / tflint), and author + run unit tests via the native HCL test framework (`terraform test` / `tofu test`).

    Keywords for skill discovery: terraform, opentofu, tofu, hcl, infrastructure-as-code, IaC, module validation, terraform plan, terraform validate, terraform fmt, terraform init, terraform test, tftest, mock_provider, unit test, static analysis, security scan, tfsec, checkov, tflint, AWS, GCP, Azure, sagemaker, s3, ec2, vpc, iam, rds, eks.

    Use this skill whenever the Terraform Module Manager needs to syntactically and semantically validate a module, run static security analysis (tfsec/checkov), exercise it against representative inputs, or prove that a change is non-breaking before bumping the module version.

    Tool boundary (critical — this is what most failed runs get wrong):
    - All shell commands in this skill MUST be issued via the Ubuntu CLI integration tools (`ubuntu-cli_execute_command`, `ubuntu-cli_execute_series`, `ubuntu-cli_execute_parallel`).
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
  name        = "github-content-change-sop"
  description = <<-EOT
    Skill: Use the GitHub `gh` CLI from the Ubuntu CLI sandbox to clone a repository, read / scan repo files locally, author file changes on a working branch, push, and open or update a Pull Request — without paying the per-call latency of the high-level GitHub Guild integration.

    Keywords for skill discovery: github, gh cli, clone repo, pull request, pr create, pr comment, pr checkout, branch, commit, push, fetch repo, list files, read files, scan repository, source code, multi-file edit, terraform, hcl, IaC, content change, auto-remediate.

    Anti-pattern (the most common time-sink in past runs):
    - Do NOT read source files one at a time via `gh api /repos/<o>/<r>/contents/<path>` with `--jq '.content' | base64 -d`. That fans out N HTTP calls per file, hits auto-summarization on large responses, and forces re-fetches. Clone the repo ONCE with `git clone` via `ubuntu-cli_execute_command` and read locally with `cat` / `find` / `rg`.
    - Do NOT spawn a subagent just to fetch repo contents; clone, list, read.

    Use this skill whenever a workflow stage needs to:
    - Clone a repo or a specific PR branch.
    - Read / inspect / scan source files in a repo (always from a local clone, never per-file API).
    - Apply file edits / auto-remediations across one or more files.
    - Commit, push, and open a new Pull Request, or update an existing one with new commits / comments.

    Prerequisites:
    - Ubuntu CLI integration available to the agent.
    - A GitHub token reachable to the sandbox. Prefer the GitHub Guild integration's PAT; if exported, surface it as `GH_TOKEN` (or `GITHUB_TOKEN`) before invoking `gh`. Never echo the token to logs.

    Steps:
    1) Ensure the `gh` CLI is available:
       a) `which gh` — if present, run `gh --version` and continue.
       b) Else install non-interactively on Debian/Ubuntu:
          `type -p curl >/dev/null || sudo apt-get install -y curl`
          `curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg`
          `sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg`
          `echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list`
          `sudo apt-get update && sudo apt-get install -y gh`
          Fallback (no apt/no root): download the tarball from `https://github.com/cli/cli/releases/latest`, untar into `$HOME/.local/bin`, and add it to `PATH`.
       c) Authenticate: `gh auth status` — if not authenticated, export `GH_TOKEN="$GITHUB_TOKEN"` and run `gh auth setup-git` so subsequent `git push` calls reuse the token. Do not run `gh auth login` interactively.

    2) Clone or fetch the repo (one time, reuse the clone for all reads + writes in this workflow run):
       a) For a fresh clone use `gh repo clone <owner>/<repo> /tmp/work/<repo>` (faster than the integration; sets the remote correctly).
       b) When the workflow is reacting to an existing PR, prefer `gh pr checkout <pr_number> --repo <owner>/<repo>` from inside the clone — it lands you on the contributor's branch directly.
       c) Configure a non-interactive git identity once per sandbox: `git config user.name "stackgen-terraform-bot"` and `git config user.email "terraform-bot@stackgen.local"`.
       d) Persist the clone path via `note` under key `repo_clone_path` so downstream stages (validate / test / register) reuse the same working tree instead of cloning again.

    2b) Read repo contents from the clone (never via `gh api /contents/...` for bulk reads):
       a) `find /tmp/work/<repo> -name '*.tf' -not -path '*/.terraform/*'` to enumerate IaC files.
       b) `cat`, `rg`, `sed`, `head` files directly from the local clone via `ubuntu-cli_execute_command`.
       c) Use `ubuntu-cli_execute_parallel` to read multiple files in one round-trip when scanning module directories.

    3) Create / switch to a working branch (skip if already on the PR branch from step 2b):
       a) `git switch -c terraform-bot/<short-slug>-$(date +%Y%m%d%H%M%S)` for new work.
       b) `git switch <existing-branch>` when updating a branch that already exists.

    4) Apply edits in the working tree using the Ubuntu CLI (use file tools, `sed`, scaffolders, or the install/validate/test skill). Keep the diff focused — one logical change per commit.

    5) Commit and push:
       a) `git add -A`
       b) `git commit -m "<conventional commit message>"` — include the originating issue/PR number in the body when known.
       c) `git push -u origin HEAD` (the token from step 1c authenticates this push).

    6) Open or update the Pull Request:
       a) If no PR exists for the branch: `gh pr create --fill --base main --head "$(git branch --show-current)" --title "<concise title>" --body "<rich body>"`. Use a here-doc for the body so multi-line markdown survives.
       b) If a PR already exists (you got here via `gh pr checkout` or a prior run): just push the new commits; optionally `gh pr comment <pr_number> --body "<status update>"` to keep reviewers informed, and `gh pr edit <pr_number> --add-label terraform-bot` to tag it.
       c) Capture the PR URL from `gh pr view --json url -q .url` and surface it as a stage output for downstream stages and the final summary comment.

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

resource "sg_runbook_sop" "terraform_bot_orchestration" {
  name        = "terraform-bot-orchestration-sop"
  description = <<-EOT
    Skill: Operating manual for the Terraform Module Manager. Read this BEFORE doing anything else in any stage. It defines integration boundaries, subagent rules, and context hygiene that every other skill depends on.

    Keywords for skill discovery: terraform, opentofu, module, workflow, orchestration, subagent, integration boundaries, ubuntu cli, github cli, gh api, jq, note, plan, validate, security scan, AWS, GCP, Azure, infrastructure-as-code.

    ========================================================================
    1) Integration boundaries (which tool runs which kind of command)
    ========================================================================

    There are exactly two execution surfaces. They have separate filesystems and separate auth. Mismatching the two is the #1 cause of failed runs.

    a) GitHub Guild integration — `github-integration_execute_command`, `github-integration_execute_series`, `github-integration_execute_parallel`:
       - ONLY for `gh` CLI calls (`gh api`, `gh repo`, `gh pr`, `gh issue`, `gh release`) and `curl` calls against `api.github.com`.
       - Does NOT have `terraform`, `tofu`, `tfsec`, `checkov`, `git clone`, `find`, `cat`, `sed`, `python`, `bash` scripts, or any general-purpose Linux toolchain.
       - Each call is auto-summarized when the response exceeds the context budget; large `gh api` responses get truncated to ~750 chars. Always pre-filter with `--jq` and `?per_page=` to keep responses small.

    b) Ubuntu CLI integration — `ubuntu-cli_execute_command`, `ubuntu-cli_execute_series`, `ubuntu-cli_execute_parallel`:
       - Full Linux shell sandbox. Use it for `terraform`, `tofu`, `tfsec`, `checkov`, `tflint`, `git clone`, `gh repo clone`, `gh pr create`, `gh pr comment`, file I/O (`cat`/`find`/`rg`/`sed`), Python/Bash scripts, and any tool installation.
       - This is where the source clone, the validate/test loop, and the PR push live.
       - If `gh` itself is not installed in this sandbox, install it once (see `github-content-change-sop`).

    c) The two sandboxes do NOT share a filesystem. A file written via `github-integration_execute_command` (which is really just `gh`/`curl`) is not visible to `ubuntu-cli_execute_command`. Always pick one sandbox per task and stay in it.

    Decision rule: if the command starts with `gh api`, `gh repo list`, `gh issue`, or `curl https://api.github.com/...` → GitHub integration. EVERYTHING else (including `gh repo clone`, `gh pr create`, `gh pr comment`, because those need a working tree and git auth) → Ubuntu CLI.

    ========================================================================
    2) Repo materialization — clone once, reuse everywhere
    ========================================================================

    - The first non-trivial repo read in any stage MUST be a single `git clone` (or `gh repo clone`) via Ubuntu CLI into `/tmp/work/<repo>`. Persist the path under `note` key `repo_clone_path`.
    - Subsequent stages MUST call `read_notes` for `repo_clone_path` and re-use the existing clone (no second clone, no per-file `gh api /contents/...` fetches).
    - For multi-file reads, prefer one `ubuntu-cli_execute_parallel` over many serial `gh api /contents/<file>` calls. Per-file API reads of source code are the most expensive way to read a repo and trigger auto-summarization.

    ========================================================================
    3) Note discipline (persist once, read many)
    ========================================================================

    Persist every artifact that the workflow will reference more than once. Standard keys to use:
    - `issue_details` — title/body/author of the triggering issue or PR.
    - `repo_clone_path` — absolute path of the local clone.
    - `module_paths` — list of module directories under analysis.
    - `static_security_findings` — combined tfsec + checkov output (from terraform-install-validate-test-sop).
    - `validation_summary` — pass/fail of fmt/init/validate per module.
    - `test_summary` — `terraform test` output summary.
    - `working_branch` — the `terraform-bot/<slug>-<ts>` branch the manager created.
    - `pr_url` — output of `gh pr view --json url -q .url` after PR creation.

    Before fetching anything, ALWAYS `read_notes` first. If the key is populated, do not refetch.

    ========================================================================
    4) Context budget for `gh api` calls
    ========================================================================

    Auto-summarization will destroy >100 KB responses. To avoid it:
    - Always append `--jq '<filter>'` to constrain the response to the fields you actually need.
    - Always paginate with `?per_page=30` (or smaller) when listing.
    - Never call `gh api /repos/<o>/<r>/git/trees/HEAD?recursive=1` without a `--jq` selector — the raw response is huge.
    - Never fetch `gh api /repos/<o>/<r>/contents/<file>` for bulk source reads. Clone and `cat` instead.
    - If a response was auto-summarized, persist the summary to `note` and DO NOT re-call the same endpoint hoping for a different result — re-shape the query (different `--jq`, smaller scope).

    ========================================================================
    5) Subagent rules (use `create_agent` sparingly and correctly)
    ========================================================================

    Do not spawn a subagent for any task that the lead can finish in ≤ 3 tool calls. When you DO spawn a subagent:

    a) `tool_names` MUST include the Ubuntu CLI tools whenever the subagent will validate, test, or scan code:
       `["ubuntu-cli_execute_command","ubuntu-cli_execute_series","ubuntu-cli_execute_parallel","github-integration_execute_command","github-integration_execute_parallel","note","read_notes","search_skill"]`

    b) Inline the relevant skill content in the subagent `goal` (do not rely on the subagent finding our SOPs through `search_skill` — the index sometimes returns "No relevant skills found" for terraform-specific queries). Paste the steps from the SOP that matter into the goal verbatim.

    c) Inline the working state the subagent needs (repo clone path, module list, prior findings) so it does not re-discover. Reference `note` keys for anything large.

    d) Set tight budgets: `max_tool_iterations` ≤ 12 for analyzers / validators, ≤ 6 for fetchers. `timeout_seconds` ≤ 120.

    e) After a subagent returns, persist its output under a dedicated `note` key — do not pass it through more subagents by reference.

    ========================================================================
    6) End-state of every stage
    ========================================================================

    A stage is only "done" when:
    - All artifacts it produced are in `note` keys named above.
    - Any branch / PR mutation it performed has its URL surfaced under `pr_url`.
    - The agent has emitted a one-paragraph stage summary listing what it persisted, so the next stage can pick up cleanly.
  EOT
}

# ============================================================================
# Terraform Module Update Workflow
# ============================================================================

resource "sg_workflow" "terraform_module_update" {
  name        = "terraform-module-update"
  domain      = "infrastructure-as-code"
  description = "Analyzes requested changes to existing Terraform modules (from PR or issue). After triage, runs security/plan compliance and org-wide deployment impact in parallel, merges findings, runs the test loop, then registers into StackGen core and notifies on GitHub."
  approve     = true

  triggers = [
    { field = "event_type", values = ["issue.created", "pull_request.opened"], type = "active", source = "github" }
  ]

  runbook_refs = [
    sg_runbook_sop.terraform_bot_orchestration.name,
    sg_runbook_sop.terraform_module_compliance.name,
    sg_runbook_sop.terraform_install_validate_test.name,
    sg_runbook_sop.github_content_change.name,
    sg_runbook_sop.stackgen_module_registration.name
  ]

  required_inputs = ["repository_url", "issue_or_pr_number"]
  optional_inputs = ["requested_change"]

  example_queries = [
    "A developer opened an issue on the terraform repo asking to fix the RDS module to support encryption by default",
    "Analyze issue #45 for the networking module and implement the requested subnet changes if compliant"
  ]

  stages = [
    {
      stage_id    = "analyze-request"
      description = "Analyze the requested change on the existing module to determine intent and scope"
      note        = "Fetch issue or PR details. Understand what the dev/code assist is asking to fix or create."
      required    = true
    },
    {
      stage_id    = "security-scan-and-plan"
      description = "Clone the branch, bootstrap a Terraform/OpenTofu sandbox via the Ubuntu CLI skill, and run static security analysis plus `terraform plan` against organizational policies"
      note        = "Parallel track A: tfsec/checkov (or equivalent), `tf fmt`/`init`/`validate`/`plan`, blast-radius / Rego evaluation. Drives the `terraform-install-validate-test-sop` skill to install Terraform or OpenTofu in the Ubuntu CLI environment before running the compliance SOP. Do not block on org-wide graph queries—those run in the sibling stage."
      required    = true
    },
    {
      stage_id    = "deployment-impact-scan"
      description = "Discover deployed instances of the module and assess breaking-change risk via StackGen context and org inventory"
      note        = "Parallel track B: query StackGen Context Graph and deployment inventory for dependents and org impact. Do not block on full Ubuntu test harness work—that runs in the sibling stage."
      required    = true
    },
    {
      stage_id    = "merge-findings-and-test-loop"
      description = "Reconcile parallel compliance and impact results, author/run `terraform test` unit tests in the Ubuntu CLI sandbox, then upgrade or fork the module"
      note        = "Join stage: merge outputs from both parallel tracks. Drives the `terraform-install-validate-test-sop` skill to scaffold `*.tftest.hcl` unit tests (using `mock_provider` and `command = plan` to stay hermetic) and execute `tf test` until green. If compliant: iterate on the test loop. If breaking: new major or new module. If non-breaking: bump existing module version."
      required    = true
    },
    {
      stage_id    = "register-and-notify"
      description = "Register the new or updated module into StackGen core and comment on the GitHub PR"
      note        = "Once the module is updated and tests pass, register the module version into the StackGen module catalog. Finally, add a detailed comment to the original GitHub issue or PR explaining the changes made, the compliance status, and the new module version."
      required    = true
    }
  ]

  stage_bindings = [
    {
      stage_id  = "analyze-request"
      agent_ref = sg_agent.terraform_module_manager.name
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
      ]
      note = "Manager analyzes the requested change (serial gate before parallel work). Fetch the triggering issue/PR with ONE `gh api /repos/<o>/<r>/issues/<n> --jq '{title,body,state,user:.user.login,number}'` call, persist under `note` key `issue_details`, and stop. Do not list the entire repo tree here; the next stage handles materialization."
    },
    {
      stage_id         = "security-scan-and-plan"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["analyze-request"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.github_content_change.name,
        sg_runbook_sop.terraform_module_compliance.name,
        sg_runbook_sop.terraform_install_validate_test.name,
      ]
      note = "Step 1 (Ubuntu CLI): `git clone` / `gh pr checkout` ONCE into `/tmp/work/<repo>`, persist `repo_clone_path` in notes. Step 2 (Ubuntu CLI): drive `terraform-install-validate-test-sop` to install tofu/terraform + tfsec + checkov, then run fmt/init/validate/tfsec/checkov and persist `static_security_findings` + `validation_summary`. Step 3: `terraform plan` against the policy bundle. Do NOT read repo files via `gh api /contents/...` — read from the local clone. Do NOT spawn subagents without including ubuntu-cli tools in their `tool_names`."
    },
    {
      stage_id         = "deployment-impact-scan"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["analyze-request"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
      ]
      note = "Manager runs org-impact and context-graph track in parallel with security-scan-and-plan. Uses StackGen Context Graph queries only — no repo I/O, no `gh api /contents/...` fetches."
    },
    {
      stage_id         = "merge-findings-and-test-loop"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["security-scan-and-plan", "deployment-impact-scan"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.terraform_install_validate_test.name,
        sg_runbook_sop.github_content_change.name,
      ]
      note = "Read `repo_clone_path`, `static_security_findings`, `validation_summary` from notes — do NOT re-clone or re-scan. Author/run `terraform test` (or `tofu test`) unit tests in the existing clone via Ubuntu CLI. Then use github-content-change: create `terraform-bot/<slug>-<ts>` branch, commit auto-remediations, `git push -u origin HEAD`, `gh pr create --fill` (or `gh pr edit` if a PR already exists). Persist `working_branch` and `pr_url` in notes."
    },
    {
      stage_id         = "register-and-notify"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["merge-findings-and-test-loop"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
        sg_runbook_sop.stackgen_module_registration.name,
        sg_runbook_sop.github_content_change.name,
      ]
      note = "Read `pr_url`, `validation_summary`, `test_summary`, `static_security_findings` from notes. Register the module into StackGen core (single `stackgen` CLI call from the Ubuntu CLI sandbox), then ONE `gh pr comment <pr_number> --body-file -` posting the registered version, compliance status, and test output. Done."
    }
  ]
}

# ============================================================================
# Webhook Ingress for GitHub
# ============================================================================

resource "sg_webhook" "github_pr_issue" {
  name        = "github-terraform-bot-receiver"
  target_type = "workflow"
  target_name = sg_workflow.terraform_module_update.name
  action      = "A new GitHub issue or PR was created in the terraform module repository. Triage the payload, determine the requested change, and initiate the module update workflow."
  enabled     = true
}
