terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.10, < 0.2.0"
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

  # Both integrations are required (see variable validation). Do not use compact() —
  # an empty ubuntu_cli would silently drop CLI tools while the SOPs still reference ubuntu-cli_*.
  integrations = [
    var.integration_names.github,
    var.integration_names.ubuntu_cli,
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
  name        = "terraform-module-compliance-sop"
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
  name        = "stackgen-module-registration-sop"
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
  name        = "terraform-install-validate-test-sop"
  approve     = true
  description = <<-EOT
    Skill: Provision an Ubuntu CLI sandbox with Terraform or OpenTofu, validate the module under review, run static security analysis (tfsec / checkov / tflint), and author + run unit tests via the native HCL test framework (`terraform test` / `tofu test`).

    Keywords for skill discovery: terraform, opentofu, tofu, hcl, infrastructure-as-code, IaC, module validation, terraform plan, terraform validate, terraform fmt, terraform init, terraform test, tftest, mock_provider, unit test, static analysis, security scan, tfsec, checkov, tflint, terraform registry, registry.terraform.io, module wrapper, AWS, GCP, Azure, sagemaker, s3, ec2, vpc, iam, rds, eks.

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
  approve     = true
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
    - A GitHub token captured into note `gh_token` (see `terraform-bot-orchestration-sop` §0a). Every Ubuntu subagent that needs `git`/`gh` MUST start by exporting it: `export GH_TOKEN="<gh_token>" && export GITHUB_TOKEN="$GH_TOKEN" && gh auth setup-git || true`. Never echo the token to logs, never include the value in any `stage_summary:*` note.

    Steps:
    1) Ensure the `gh` CLI is available AND authenticated:
       a) `which gh` — if present, run `gh --version` and continue to (c).
       b) Else install non-interactively on Debian/Ubuntu:
          `type -p curl >/dev/null || sudo apt-get install -y curl`
          `curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg`
          `sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg`
          `echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list`
          `sudo apt-get update && sudo apt-get install -y gh`
          Fallback (no apt/no root): download the tarball from `https://github.com/cli/cli/releases/latest`, untar into `$HOME/.local/bin`, and add it to `PATH`.
       c) Authenticate using the inlined token from note `gh_token`:
          `export GH_TOKEN="<gh_token value>" && export GITHUB_TOKEN="$GH_TOKEN"`
          `gh auth status || (echo "$GH_TOKEN" | gh auth login --with-token)`
          `gh auth setup-git`
          Do NOT run `gh auth login` interactively. Do NOT echo the token. If `gh_token` is missing from notes, STOP and surface "no GitHub token available" per orchestration-sop §8(a).

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
  approve     = true
  description = <<-EOT
    Skill: Operating manual for the Terraform Module Manager. Read this BEFORE doing anything else in any stage. It encodes the planner/executor split, integration boundaries, subagent budget rules, and context hygiene that every other skill depends on.

    Keywords for skill discovery: terraform, opentofu, module, workflow, orchestration, planner, subagent, create_agent, integration boundaries, ubuntu cli, github cli, gh api, jq, note, plan, validate, security scan, AWS, GCP, Azure, infrastructure-as-code, sagemaker, s3, rds, eks.

    ========================================================================
    0) Reality check — you are a planner, not an executor
    ========================================================================

    Your only direct tools are: `search_tools`, `create_agent`, `ask_clarifying_question`, `graph_query`, `notify`, `note`, `read_notes`, `delete_context`, `check_budget`, `knowledge_*`. You CANNOT call `github-integration_*` or `ubuntu-cli_*` directly. Every shell or API call happens inside a `create_agent` subagent.

    When this SOP (or any other SOP) tells you to "run `git clone ...`" or "call `gh api ...`", that ALWAYS means: spawn ONE subagent whose `tool_names` include the right integration and whose `goal` inlines the command(s). The templates in §7 below show exactly how.

    ========================================================================
    0a) Authentication bootstrap (read this BEFORE Template A)
    ========================================================================

    The Ubuntu CLI sandbox does NOT receive a GitHub token by default — assuming `$GH_TOKEN` is preset is the #1 reason past clones failed with "could not read Username for 'https://github.com'" or "authentication required". Likewise, the GitHub Guild integration's token is NOT automatically visible to Ubuntu subagents. You must surface it once per workflow run and reuse it.

    The token-surfacing flow (do this EXACTLY ONCE in `analyze-request`, then every later subagent reads `gh_token_available=true` from notes and re-receives the token via its `goal` text):

    1. Probe the Ubuntu sandbox first. Spawn a TINY Ubuntu-CLI subagent (or fold this into the clone subagent) that runs:
         `printenv GITHUB_TOKEN >/dev/null && echo gh_env_present=true || echo gh_env_present=false`
         `printenv GH_TOKEN >/dev/null && echo gh_env_present_alt=true || echo gh_env_present_alt=false`
       If either is `true`, the sandbox already has a usable token. Have the subagent run `export GH_TOKEN="$${GH_TOKEN:-$GITHUB_TOKEN}" && gh auth setup-git` and note `gh_token_source="ubuntu_env"`. Skip step 2.

    2. If the Ubuntu sandbox has no token, spawn ONE GitHub-integration subagent named `analyze-request-fetch-gh-token` that runs `gh auth token` (this works inside the GitHub Guild integration because that integration is always pre-authenticated). The subagent must:
         a) Call `gh auth token` and capture the raw output.
         b) note key="gh_token", value="<raw token>", sensitive=true.
         c) Also note key="gh_token_source", value="github_integration".
       NEVER echo the token in plaintext logs, NEVER include it in `stage_summary:*` notes, and NEVER pass it through `notify` to humans.

    3. Every later Ubuntu-CLI subagent that needs git/gh access MUST start by reading `gh_token` and exporting it. Inline this block at the top of every such subagent goal:
         `read_notes("gh_token")`  →  in the shell goal:
         `export GH_TOKEN="<value of gh_token note>"`
         `export GITHUB_TOKEN="$GH_TOKEN"`
         `gh auth setup-git || true`
       Then any subsequent `git clone`, `gh repo clone`, `gh pr create`, or `git push` works without further auth flow.

    Hard rule: do NOT attempt anonymous `git clone https://github.com/...` for private repos. If both step 1 and step 2 fail, STOP the workflow at the current stage, note `stage_summary:<stage>="blocked: no GitHub token available"`, and surface the blocker via `ask_clarifying_question` asking the operator to confirm the GitHub integration is healthy. DO NOT loop spawning more discovery subagents — that is the failure pattern from prior traces.

    ========================================================================
    0b) Trigger payload is the source of truth (NEVER search the org)
    ========================================================================

    This workflow is triggered by a GitHub webhook (`issue.created` or `pull_request.opened`). The webhook payload is delivered to the agent context and contains the EXACT repo + issue/PR identifiers. You MUST extract these from the payload rather than searching the org for "the repo that probably has the module the user mentioned" — that pattern produced the prior failed run where the agent enumerated `sks/*` repos looking for `aws-ecs-blue-green` and found nothing because the user had said "fix the aws-ecs-blue-green module" inside an issue filed on a totally different repo.

    Canonical extraction paths (all available on the trigger event):
      `repository_full_name`     = `trigger_event.payload.repository.full_name`        (e.g. "acme/terraform-modules")
      `repository_clone_url`     = `trigger_event.payload.repository.clone_url`        (HTTPS URL — pair with `gh_token` for auth)
      `repository_default_branch`= `trigger_event.payload.repository.default_branch`
      `issue_or_pr_number`       = `trigger_event.payload.issue.number` OR `trigger_event.payload.pull_request.number`
      `pr_head_ref`              = `trigger_event.payload.pull_request.head.ref`       (PR branch name; empty for plain issues)
      `pr_head_clone_url`        = `trigger_event.payload.pull_request.head.repo.clone_url` (set for forks; falls back to `repository_clone_url` for same-repo PRs)
      `event_type`               = `trigger_event.type`                                ("issue.created" | "pull_request.opened")

    The `analyze-request` stage MUST persist ALL of these (under those exact note keys) as its first action, BEFORE any subagent that needs the repo. If a field is empty (e.g. `pr_head_ref` on an `issue.created` event), record it as `""` — downstream stages branch on that.

    Repo identification rule: the `repo_clone_path` MUST be derived from `repository_full_name` (or `pr_head_repo_full_name` for cross-fork PRs). NEVER guess the repo from substrings of the issue body, NEVER list any org via `gh repo list`, and NEVER pick a repo because its name "sounds related" to a module name mentioned in the issue body.

    ========================================================================
    1) Integration boundaries (which subagent gets which tools)
    ========================================================================

    Two execution surfaces with separate filesystems and separate auth. Mismatching them is the #1 cause of failed runs (a prior trace tried to run `terraform validate` via the GitHub integration — that integration can only run `gh`/`curl`, so the validator never validated).

    a) GitHub Guild integration — `github-integration_execute_command|series|parallel`:
       - ONLY for `gh` API calls (`gh api`, `gh repo list`, `gh issue`, `gh release`) and `curl https://api.github.com/...`.
       - Does NOT have `terraform`, `tofu`, `tfsec`, `checkov`, `git clone`, `find`, `cat`, `sed`, `python`, or any general-purpose Linux toolchain.
       - Responses > ~50 KB are auto-summarized down to ~750 chars and the original is lost. Always pre-filter with `--jq` and `?per_page=`.

    b) Ubuntu CLI integration — `ubuntu-cli_execute_command|series|parallel`:
       - Full Linux shell sandbox. Use it for `terraform`, `tofu`, `tfsec`, `checkov`, `tflint`, `git clone`, `gh repo clone`, `gh pr create`, `gh pr comment`, `find`, `cat`, `rg`, `sed`, Python/Bash scripts, and any tool installation.
       - Also use it for read-only `curl`/`jq` against **public** HTTPS APIs that are not GitHub — e.g. `https://registry.terraform.io/v1/modules/search` (Terraform Registry module discovery). Never paste secrets into query strings.
       - The source clone, validate/test loop, and PR push all live here.

    c) The two sandboxes do NOT share a filesystem. Pick one per subagent and stay in it.

    Decision rule: command starts with `gh api`, `gh repo list`, `gh issue`, or `curl https://api.github.com/...` → GitHub-integration subagent. `curl`/`jq` to `registry.terraform.io` for module search → Ubuntu-CLI subagent. EVERYTHING else (including `gh repo clone`, `gh pr create`, `gh pr comment`) → Ubuntu-CLI subagent.

    ========================================================================
    2) Repo materialization — clone once, reuse everywhere
    ========================================================================

    The first non-trivial repo read in any stage MUST be a single `git clone` via an Ubuntu-CLI subagent into `/tmp/work/<repo>`. Persist the absolute path under `note` key `repo_clone_path`. Every later stage starts by `read_notes` for `repo_clone_path` and reuses the existing clone — no second clone, no per-file `gh api /contents/...` fetches.

    A prior trace spawned 7 separate subagents (`discover-repo-structure`, `full-aws-directory-scan`, `raw-aws-directory-list`, `list-exact-filenames`, `find-sagemaker-modules`, `get-exact-sagemaker-paths`, `print-sagemaker-dirs`) each calling `gh api git/trees/HEAD?recursive=1` to list the same directory. A single `git clone` + one `find` would have replaced all of them. Don't repeat this.

    ========================================================================
    2a) Target module resolution (after the clone exists)
    ========================================================================

    The webhook payload tells you WHICH REPO to clone (per §0b). It does NOT necessarily tell you which subdirectory inside that repo is the target module. Resolve that ONCE, in `security-scan-and-plan`, using ONLY the local clone — never `gh repo list` against the whole org.

    Resolution algorithm (run all of these inside ONE Ubuntu-CLI subagent — no fan-out):

    a) Pull candidates from the issue/PR body. From `issue_details.body`, extract:
       - Explicit paths like `modules/aws/ecs-blue-green/` or `terraform/modules/<name>/`.
       - Module names like `aws-ecs-blue-green`, `terraform-aws-eks`, `<provider>-<service>-<variant>`.
       - File paths mentioned with backticks or fenced code blocks.
       Persist the list as note `target_module_hints`.

    b) Search the local clone (NOT the org) for matching directories. Use a single command:
         `find <repo_clone_path> -type d \( -name "<hint1>" -o -name "<hint2>" -o -name "terraform-aws-<hint>" \) -not -path '*/.terraform/*' -not -path '*/.git/*'`
       Also scan for the hint as a substring of any directory path:
         `find <repo_clone_path> -type d -not -path '*/.terraform/*' -not -path '*/.git/*' | rg -i '<hint-as-regex>'`

    c) For PR triggers, prefer the directories touched by the PR head branch:
         `cd <repo_clone_path> && git diff --name-only origin/<default_branch>...HEAD | xargs -I{} dirname {} | sort -u`
       The intersection of (b) and (c) is the high-confidence target.

    d) For each resolved path, confirm it is a Terraform module: contains at least one `*.tf` file and (preferably) a `main.tf` / `variables.tf`. Drop any path without `*.tf`.

    e) Persist results as note `module_paths` (a list of absolute paths in the clone, ordered most-likely first). Also note `module_resolution_confidence` ∈ {"exact","probable","ambiguous","not_found","registry_wrap","greenfield"}:
       - "exact" — single directory matches a hint AND is in the PR diff.
       - "probable" — single directory matches a hint OR is the only `*.tf`-bearing dir touched by the PR.
       - "ambiguous" — multiple candidates with no PR-diff tiebreak.
       - "not_found" — no candidates at all in the clone.
       - "registry_wrap" / "greenfield" — set only in `merge-findings-and-test-loop` after Template H / G succeeds (not set in `security-scan-and-plan`).

    Confidence-driven branching (encoded in §8, do NOT improvise):
      "exact"      → continue to validate/test loop with `module_paths[0]`.
      "probable"   → continue, but include the alternatives in the final PR comment for human review.
      "ambiguous"  → `ask_clarifying_question` (one question) listing the top 5 candidates; do NOT spawn more discovery subagents.
      "not_found"  → branch to registry-backed new module (Template H), from-scratch scaffold (Template G), or `ask_clarifying_question`, per §8.

    ========================================================================
    3) Note discipline (persist once, read many)
    ========================================================================

    Canonical note keys (use these exact names — do not invent new ones per subagent):
    - `issue_details` — title/body/author of the triggering issue or PR.
    - `repo_clone_path` — absolute path of the local clone.
    - `module_paths` — list of module directories under analysis.
    - `registry_module_source` — chosen public registry module address (e.g. `terraform-aws-modules/vpc/aws`, no version pin in this string).
    - `registry_module_version` — semver constraint or exact version pinned in the wrapper `module` block (e.g. `5.0.0` or `~> 5.0`).
    - `registry_search_query` — query string sent to `registry.terraform.io/v1/modules/search`.
    - `registry_wrap_summary` — one paragraph: search hits considered, chosen module + version, why it fits the issue.
    - `registry_wrap_failed` — boolean string "true" when registry path could not produce a module; triggers Template G fallback.
    - `validation_summary` — pass/fail of fmt/init/validate per module.
    - `test_summary` — `terraform test` output summary.
    - `deployment_impact` — context-graph dependency / org-impact summary.
    - `working_branch` — the `terraform-bot/<slug>-<ts>` branch.
    - `pr_url` — output of `gh pr view --json url -q .url` after PR creation.
    - `registered_versions` — output of `stackgen` registration for each module.
    - `stage_summary:<stage_id>` — one-paragraph summary at the end of each stage.

    Always `read_notes` first. If the key is populated, do NOT refetch — re-shape your plan to use what's there.

    ========================================================================
    4) Context budget for `gh api` calls
    ========================================================================

    - Always append `--jq '<filter>'` to keep the response under ~10 KB.
    - Always paginate with `?per_page=30` or smaller when listing.
    - Never run `gh api /repos/<o>/<r>/git/trees/HEAD?recursive=1` without a `--jq` selector — the raw response is megabytes and triggers auto-summarization.
    - Never fetch `gh api /repos/<o>/<r>/contents/<file>` for bulk source reads. Clone and `cat` instead.
    - If a response was auto-summarized, persist the summary and STOP re-calling the same endpoint hoping for a different result. Re-shape the query (smaller scope, different `--jq`).

    ========================================================================
    5) Subagent rules (the most-violated section)
    ========================================================================

    a) Hard cap: at most ONE subagent per logical task per stage. A prior trace spawned 22 unique subagent names — `fetch-all-module-contents`, `fetch-current-module-files`, `fetch-module-contents-v2`, `fetch-with-base64-cmd`, `deep-content-fetcher`, `repo-content-fetcher`, `deep-discovery`, etc. — all doing the same fetch. Each subagent costs ~$0.50 and 30-90s. Don't fan out.

    b) Subagent naming convention: `<stage_id>-<phase>` ONLY. Approved phases per stage:
       - `analyze-request-fetch-issue`
       - `security-scan-and-plan-clone`
       - `security-scan-and-plan-validate`
       - `security-scan-and-plan-scan`
       - `security-scan-and-plan-plan`
       - `deployment-impact-scan-graph-query`
       - `merge-findings-and-test-loop-registry-wrap`
       - `merge-findings-and-test-loop-author-tests`
       - `merge-findings-and-test-loop-pr`
       - `register-and-notify-register`
       - `register-and-notify-comment`
       If you find yourself wanting a name not in this list, you're fanning out — STOP and consolidate into one of the approved names.

    c) `tool_names` rules:
       - Validator / test / scan subagents: include `ubuntu-cli_execute_command`, `ubuntu-cli_execute_series`, `ubuntu-cli_execute_parallel`, `note`, `read_notes`, `search_skill`, `load_skill`.
       - GH API fetcher subagents: include `github-integration_execute_command`, `github-integration_execute_parallel`, `note`, `read_notes`.
       - PR-author subagents: include `ubuntu-cli_*` (for `gh pr create`, `gh pr comment`, `git push`), PLUS `note`, `read_notes`.
       - Always include `note` and `read_notes` so the subagent can persist partial results before hitting its budget limit.

    d) Inline content into the subagent `goal` (subagents cannot see your skills):
       1. Paste the relevant SOP steps verbatim (the planner system prompt explicitly states: *"sub-agents CANNOT see the learned skills, only you can. You MUST copy the skill's steps directly into the sub-agent's goal text."*).
       2. Paste the relevant note keys' current values OR explicit `read_notes` instructions with key names.
       3. Specify the exact commands to run, the note keys to write, and the success criterion.

    e) Tight budgets: `max_tool_iterations` ≤ 10 for analyzers/validators, ≤ 5 for fetchers. `timeout_seconds` ≤ 120. `max_llm_calls` ≤ 6.

    f) Always call `check_budget` before any `create_agent`. If remaining budget < $2, skip non-critical subagents and go straight to `register-and-notify` with whatever evidence is already in notes. The agent has a $10/day budget; the prior trace hit $10.74 and never reached PR creation.

    g) If a subagent fails or partially succeeds: extract any useful output from its response, `note` it, and DO NOT spawn a retry with a slightly different name. After 2 failures on the same logical task, accept partial results and continue.

    ========================================================================
    6) End-state of every stage
    ========================================================================

    Before declaring a stage done you MUST `note` a `stage_summary:<stage_id>` key with: what you fetched, what notes you populated, which subagents you spawned, and any blockers. The next stage reads this first.

    ========================================================================
    7) Subagent goal templates (copy-paste these)
    ========================================================================

    Template A — "clone the repo" (one-shot for any stage that needs source):
      agent_name: "<stage_id>-clone"
      tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","note","read_notes"]
      max_tool_iterations: 6, max_llm_calls: 5, timeout_seconds: 180
      goal: |
        Clone <repository_clone_url> (from notes) to /tmp/work/<repo_name> and persist the path.
        Inputs (paste verbatim from your notes when spawning):
          - repository_full_name (e.g. "acme/terraform-modules")
          - repository_clone_url
          - pr_head_ref (may be empty)
          - pr_head_clone_url (may equal repository_clone_url; differs for forks)
          - issue_or_pr_number
          - gh_token  (NEVER log it; only use in env exports below)
        Steps (run as a single execute_series so the env survives across commands):
          1. `export GH_TOKEN="<gh_token from notes>" && export GITHUB_TOKEN="$GH_TOKEN" && gh auth setup-git || true`
          2. `REPO_NAME=$(basename <repository_full_name>) && mkdir -p /tmp/work && cd /tmp/work`
          3. `[ -d "$REPO_NAME" ] || git clone "https://x-access-token:$GH_TOKEN@github.com/<repository_full_name>.git" "$REPO_NAME"`
          4. `cd "/tmp/work/$REPO_NAME" && git fetch --all --prune`
          5. If `<pr_head_clone_url>` differs from `<repository_clone_url>` (fork PR): `git remote add fork "https://x-access-token:$GH_TOKEN@<pr_head_clone_url-without-scheme>" 2>/dev/null || true && git fetch fork <pr_head_ref>:<pr_head_ref>` then `git switch <pr_head_ref>`.
             Else if `<pr_head_ref>` is non-empty: `git fetch origin "pull/<issue_or_pr_number>/head:pr-<issue_or_pr_number>" && git switch "pr-<issue_or_pr_number>"`.
             Else (plain issue, no PR yet): stay on `<repository_default_branch>`.
          6. `git rev-parse HEAD`  → capture SHA.
          7. note key="repo_clone_path", value="/tmp/work/$REPO_NAME"
          8. note key="repo_head_sha", value="<sha>"
        If step 3 fails with auth error, do NOT retry with different URLs — stop and note `clone_blocker="auth"` so the planner can branch to §8.
        Stop after these steps; do not list directory contents (next phase does that).

    Template B — "fetch the triggering issue + capture token" (analyze-request stage):
      agent_name: "analyze-request-fetch-issue"
      tool_names: ["github-integration_execute_command","github-integration_execute_series","note","read_notes"]
      max_tool_iterations: 4, max_llm_calls: 4, timeout_seconds: 90
      goal: |
        Fetch the triggering issue/PR, capture an auth token for downstream Ubuntu work, and persist trigger-payload notes.
        Inputs (paste verbatim from the trigger event):
          - repository_full_name, issue_or_pr_number, event_type ("issue.created"|"pull_request.opened")
        Steps (run as a single execute_series):
          1. `gh auth token`  → capture the raw token output.
          2. If event_type starts with "issue":
               `gh api /repos/<repository_full_name>/issues/<issue_or_pr_number> --jq '{number,title,body,state,author:.user.login,labels:[.labels[].name]}'`
             Else (pull_request.*):
               `gh api /repos/<repository_full_name>/pulls/<issue_or_pr_number> --jq '{number,title,body,state,author:.user.login,labels:[.labels[].name],head:{ref:.head.ref,sha:.head.sha,clone_url:.head.repo.clone_url,full_name:.head.repo.full_name},base:{ref:.base.ref}}'`
          3. note key="gh_token", value=<token from step 1>, sensitive=true
          4. note key="gh_token_source", value="github_integration"
          5. note key="issue_details", value=<the JSON from step 2, verbatim>
          6. If pull_request, also note key="pr_head_ref" / "pr_head_clone_url" / "pr_head_repo_full_name" extracted from step 2.
        Do NOT fetch comments, tree, or `/contents/` here — that work is forbidden in analyze-request (see §0b). Stop after step 6.

    Template C — "install + validate + scan" (security-scan-and-plan stage):
      agent_name: "security-scan-and-plan-validate"
      tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","ubuntu-cli_execute_parallel","note","read_notes"]
      max_tool_iterations: 10, max_llm_calls: 6, timeout_seconds: 240
      goal: |
        Validate the module(s) at the clone path, run static security analysis, persist results.
        Read notes first: `repo_clone_path`, `module_paths`.
        Follow `terraform-install-validate-test-sop` steps 1, 2, 2b verbatim:
        <PASTE STEPS 1 + 2 + 2b FROM terraform-install-validate-test-sop HERE>
        Persist: `validation_summary` (per-module fmt/init/validate result) and `static_security_findings` (combined tfsec+checkov findings).

    Template D — "open the PR" (merge-findings-and-test-loop stage):
      agent_name: "merge-findings-and-test-loop-pr"
      tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","note","read_notes"]
      max_tool_iterations: 8, max_llm_calls: 5, timeout_seconds: 180
      goal: |
        Create a working branch in the existing clone, commit the prepared changes, push, and open / update a PR.
        Read notes first: `repo_clone_path`, `issue_details`, `validation_summary`, `test_summary`.
        Follow `github-content-change-sop` steps 3-6 verbatim:
        <PASTE STEPS 3-6 FROM github-content-change-sop HERE>
        Persist: `working_branch`, `pr_url`.

    Template E — "comment on the PR/issue" (register-and-notify stage, also used for blocked-status notifications):
      agent_name: "register-and-notify-comment"
      tool_names: ["ubuntu-cli_execute_command","note","read_notes"]
      max_tool_iterations: 3, max_llm_calls: 3, timeout_seconds: 60
      goal: |
        Inputs from notes: `gh_token`, `repository_full_name`, `issue_or_pr_number`, `pr_url` (optional), `registered_versions`, `validation_summary`, `test_summary`, `static_security_findings`, `deployment_impact`, `stage_summary:*` (any blocked stages).
        Steps:
          1. `export GH_TOKEN=<gh_token> && export GITHUB_TOKEN=$GH_TOKEN`
          2. If `pr_url` is non-empty: post on the PR. Else (still an issue): post on the issue.
             Use ONE call:
               `gh pr comment "$pr_url" --body-file - <<'EOF'\n<summary>\nEOF`
             or
               `gh issue comment <issue_or_pr_number> --repo <repository_full_name> --body-file - <<'EOF'\n<summary>\nEOF`
          3. If any `stage_summary:*` note begins with "blocked:", include a "## Workflow blocked" section quoting that blocker so reviewers see exactly why the run stopped.
        Stop after the comment.

    Template F — "capture GitHub token via the Guild integration" (only when §0a step 1 reports the Ubuntu sandbox has no token):
      agent_name: "analyze-request-fetch-gh-token"
      tool_names: ["github-integration_execute_command","note","read_notes"]
      max_tool_iterations: 2, max_llm_calls: 2, timeout_seconds: 45
      goal: |
        Capture a usable GitHub token from the Guild integration so later Ubuntu-CLI subagents can `git clone` / `git push` private repos.
        1. `gh auth token`  → capture the raw token (single line).
        2. note key="gh_token", value=<token>, sensitive=true
        3. note key="gh_token_source", value="github_integration"
        Do NOT echo the token, do NOT log it, do NOT include it in any stage_summary. Stop after step 3.

    Template G — "scaffold a new module from scratch" (fallback when Template H finds no suitable registry module):
      agent_name: "merge-findings-and-test-loop-scaffold"
      tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","note","read_notes"]
      max_tool_iterations: 12, max_llm_calls: 8, timeout_seconds: 300
      goal: |
        Create a NEW Terraform module under the existing clone, validate it, and stage it for PR.
        Inputs from notes: `repo_clone_path`, `issue_details`, `target_module_hints`, `gh_token`.
        Steps:
          1. `export GH_TOKEN=<gh_token>`
          2. Pick the module name from `target_module_hints[0]` (kebab-case), e.g. `aws-ecs-blue-green`.
          3. Pick the parent directory using these rules, in order: existing `modules/` dir at the repo root, else `terraform/modules/`, else create `modules/`.
          4. Scaffold under `<parent>/<module_name>/`:
               - `main.tf`     — minimum required resources implied by the issue body; otherwise leave a single commented placeholder.
               - `variables.tf` — declare every input mentioned in the issue body; default sensitive defaults to `null`.
               - `outputs.tf`  — at minimum an `id` output and any user-requested attributes.
               - `README.md`   — module purpose, inputs, outputs, example usage block; cite the originating issue number.
               - `tests/unit.tftest.hcl` — at least one `command = plan` run with `mock_provider` per provider used.
          5. Follow `terraform-install-validate-test-sop` steps 1, 2, 2b, 4 inline to install OpenTofu, run fmt/init/validate/test, capture findings.
          6. note key="module_paths", value=["<absolute path to new module>"]
          7. note key="module_resolution_confidence", value="greenfield"
          8. note key="scaffold_summary", value=<one paragraph: chosen name/path, files created, test outcome>
        DO NOT commit / push here — the PR subagent in `merge-findings-and-test-loop-pr` handles that.

    Template H — "registry-backed new module" (preferred greenfield path — search Terraform Registry, wrap a published module, test, then hand off to PR subagent):
      agent_name: "merge-findings-and-test-loop-registry-wrap"
      tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","ubuntu-cli_execute_parallel","note","read_notes"]
      max_tool_iterations: 14, max_llm_calls: 8, timeout_seconds: 360
      goal: |
        When the issue asks for a NEW module, prefer a vetted **Terraform Registry** module over inventing resources from scratch.
        Inputs from notes: `repo_clone_path`, `issue_details`, `target_module_hints`, `repository_default_branch`, `gh_token`.

        Registry API (read-only HTTPS — run from Ubuntu CLI with `curl` + `jq`; keep responses small):
          - Search: `curl -fsSL "https://registry.terraform.io/v1/modules/search?q=<URL_ENCODED_QUERY>&provider=<aws|google|azurerm>" | jq -c '.modules[:10] | [.[] | {id,namespace,name,provider,version,downloads}]'`
          - Versions for a chosen triple: `curl -fsSL "https://registry.terraform.io/v1/modules/<namespace>/<name>/<provider>/versions" | jq -c '[.modules[0].versions[] | .version] | .[-5:]'` (last few entries = newest published)
          - Optional module detail (inputs/outputs hints): `curl -fsSL "https://registry.terraform.io/v1/modules/<namespace>/<name>/<provider>/<version>" | jq '{root: .root, inputs: (.root.inputs // {} | keys), outputs: (.root.outputs // {} | keys)}'`

        Steps:
          1. `export GH_TOKEN=<gh_token>` (for git identity only; registry calls are unauthenticated GETs).
          2. Build `registry_search_query` from `issue_details.title` + first 200 chars of `issue_details.body` + `target_module_hints` (strip markdown, collapse spaces, max ~80 chars for the `q=` param). URL-encode it for curl.
          3. Infer default `provider` for search: `aws` if body/title mentions ECS/EKS/VPC/RDS/S3/etc.; `google` for GKE/GCS; `azurerm` for Azure; else default `aws`.
          4. Run the search curl+jq ONCE. If `.modules` is empty, try ONE narrower fallback query (e.g. single best hint token) then ONE broader query (e.g. `vpc` instead of `aws-vpc-ha`). If still empty after 3 total search attempts, note `registry_wrap_failed=true`, `registry_wrap_summary="no registry hits after bounded search"`, and STOP without writing files — the planner falls back to Template G.
          5. Pick ONE module from results: prefer official-looking namespaces (`terraform-aws-modules`, `GoogleCloudPlatform`, `Azure`, hashicorp partners), highest `downloads`, and semantic match to the issue. Record `registry_module_source` as `"<namespace>/<name>/<provider>"` (no `//` submodule unless the issue names one).
          6. Pick a concrete `registry_module_version`: prefer the latest **non**-deprecated semver from the versions endpoint; pin exactly in HCL (e.g. `version = "5.21.0"`) so CI is reproducible.
          7. Directory layout (same parent rules as Template G): `<parent>/<local_dir>/` where `<local_dir>` is kebab-case from hints or issue slug.
          8. Write a **thin wrapper** (do NOT vendor thousands of lines of upstream source):
               - `main.tf` — single `module "this"` block with `source = "<namespace>/<name>/<provider>"` and `version = "<chosen>"`. Pass through only variables the issue explicitly needs; for everything else use `{}` or minimal safe defaults so `terraform validate` passes. Add a one-line comment linking `https://registry.terraform.io/modules/<namespace>/<name>/<provider>/<version>`.
               - `variables.tf` — declare forwarded inputs with sensible types/defaults so `plan` works offline in tests.
               - `outputs.tf` — re-export the subset of upstream outputs the issue cares about (or `value = module.this` if small).
               - `README.md` — state that this repo module wraps the public registry module, list pinned version + registry URL, cite originating issue number, document why this wrapper exists.
               - `versions.tf` — `terraform { required_version = ">= 1.5" ; required_providers { <provider> = { source = "<registry source>"; version = ">= ..." } } }` aligned with the wrapped module's provider.
               - `tests/unit.tftest.hcl` — at least two `run` blocks: (i) `command = plan` with `mock_provider` for the cloud provider proving default inputs produce a valid graph; (ii) optional `variables` block testing one non-default input path if the issue demands it.
          9. Follow `terraform-install-validate-test-sop` steps 1, 2, 2b, 4 inline (`tf fmt`, `init -backend=false`, `validate`, `tf test -verbose`). Registry modules download during `init` — network must be allowed in the sandbox.
          10. On success: note `module_paths` = ["<absolute path>"], `module_resolution_confidence` = "registry_wrap", `registry_search_query`, `registry_wrap_summary` (chosen id, version, downloads, 1-line rationale), `test_summary` (pass/fail + last 80 lines of test output), `validation_summary`, `static_security_findings` (soft-fail scan on the new dir).
          11. On validate/test failure after one minimal fix attempt (adjust variables/outputs or mock_provider only): if still failing, note `registry_wrap_failed=true` and STOP — planner may fall back to Template G or ask human.

        DO NOT commit / push here — `merge-findings-and-test-loop-pr` handles that.
        DO NOT call `gh api` for registry data — only `registry.terraform.io` + local files.

    ========================================================================
    8) Failure & fallback paths (use these BEFORE looping with more discovery subagents)
    ========================================================================

    Past traces failed because the agent kept spawning "discover-repo-structure" / "find-modules" subagents after the first failure. That is the wrong response. When a stage cannot proceed, pick exactly one of the bounded responses in (a)–(d) below — do not improvise a fifth discovery loop.

    a) BLOCKER: "no GitHub token" (Ubuntu sandbox env missing AND `gh auth token` via integration returned empty).
         → note key="stage_summary:<current_stage>" value="blocked: no GitHub token; integration may be unauthenticated"
         → call `ask_clarifying_question` with: "The GitHub Guild integration appears unauthenticated. Please verify the integration's PAT/App is configured, then retry the workflow."
         → STOP. Do not spawn more subagents this stage.

    b) BLOCKER: "repo clone failed" (Template A reported `clone_blocker="auth"` or 404).
         → note key="stage_summary:<current_stage>" value="blocked: cannot clone <repository_full_name>; verify the GitHub integration has access"
         → Run Template E (register-and-notify-comment) to post the blocker on the originating issue/PR.
         → STOP.

    c) BLOCKER: "module path ambiguous" (`module_resolution_confidence` = "ambiguous").
         → call `ask_clarifying_question` listing up to 5 candidate paths from `module_paths` and asking the operator to pick one.
         → On answer, persist the chosen path back to `module_paths` and continue. NO new discovery subagents.

    d) FALLBACK: "module path not_found" (`module_resolution_confidence` = "not_found").
         Decision tree:
           1. Inspect `issue_details.body` for greenfield intent ("create a new module", "scaffold", "add module", "missing module", "new <provider>-<service>", "add from registry", "terraform registry", explicit "create").
           2. If greenfield intent is unambiguous → **prefer Template H** (`merge-findings-and-test-loop-registry-wrap`): search `https://registry.terraform.io/v1/modules/search`, pick a published module + version, add a thin wrapper + `*.tftest.hcl`, run validate/test. This is the default for "new module" issues so the org gets battle-tested upstream instead of hand-written guesses.
           3. If Template H leaves `registry_wrap_failed=true` OR `module_paths` still empty → fall back to **Template G** (`merge-findings-and-test-loop-scaffold`) from scratch in the same stage (still counts as one logical follow-up — do NOT spawn a third registry retry).
           4. Else (no greenfield intent) → call `ask_clarifying_question` exactly ONCE: "I couldn't find a `<hint>` module in `<repository_full_name>`. Should I (a) add one from the Terraform Registry (wrapper + tests + PR), (b) scaffold without registry, (c) use a different repo, or (d) skip?" Map answers to Template H / Template G / blocked / blocked respectively.

    Hard rule for §8: a single workflow run may invoke `ask_clarifying_question` AT MOST ONCE per stage. If you already asked once in a stage, you must commit to one of the responses in (a)–(d) without re-asking. After answering, the next non-clarifying step must be either `Template H`, `Template G`, `Template E` (blocked notification), or a normal stage continuation — never another discovery fan-out.
  EOT
}

# ============================================================================
# Terraform Module Update Workflow
# ============================================================================

resource "sg_workflow" "terraform_module_update" {
  name        = "terraform-module-update"
  domain      = "infrastructure-as-code"
  description = "Analyzes Terraform module change requests from GitHub issues or PRs. For new modules, prefers Terraform Registry discovery (thin wrapper + tests + PR) before from-scratch scaffold. Runs security/plan compliance and deployment impact, merges findings, runs the test loop, registers into StackGen, and notifies on GitHub."
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
    "Analyze issue #45 for the networking module and implement the requested subnet changes if compliant",
    "Issue #12: add a new aws-ecs-blue-green module — search the Terraform Registry for a suitable ECS module, wrap it with tests, and open a PR"
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
      description = "Merge compliance and impact, add tests; for new modules prefer Terraform Registry wrapper + tests then PR (fallback: from-scratch scaffold)"
      note        = "Join stage: merge parallel tracks. For new-module issues, run Template H (registry.terraform.io search + thin wrapper + tftest) before Template G. Run install/validate/test skill; open PR via gh. If compliant iterate; if breaking plan major or new module path."
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
      skill_refs = concat(["terraform-bot-orchestration-sop"], try(var.workflow_skill_refs["terraform-module-update::analyze-request"], []))
      note       = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $0.75, ≤ 120s.

        Plan (do this exactly; the prior failed run skipped steps 1 + 2 and let later stages guess the repo):
        1. Extract these fields from the trigger event payload (`trigger_event.payload`) and write them to notes BEFORE spawning any subagent:
             - `repository_full_name`        ← `repository.full_name`
             - `repository_clone_url`        ← `repository.clone_url`
             - `repository_default_branch`   ← `repository.default_branch`
             - `issue_or_pr_number`          ← `issue.number` or `pull_request.number`
             - `event_type`                  ← `trigger_event.type`
             - `pr_head_ref`                 ← `pull_request.head.ref`         (empty for issue events)
             - `pr_head_clone_url`           ← `pull_request.head.repo.clone_url` (empty for issue events)
             - `pr_head_repo_full_name`      ← `pull_request.head.repo.full_name` (empty for issue events)
           If any of `repository_full_name` / `issue_or_pr_number` is empty, branch to §8(a) of `terraform-bot-orchestration-sop` immediately — DO NOT search the org for the repo.
        2. `read_notes` for `issue_details` and `gh_token`. If both are already populated (re-entry case), skip to step 4.
        3. Spawn EXACTLY one subagent named `analyze-request-fetch-issue` per orchestration-sop Template B. It does TWO things in one execute_series: (a) `gh auth token` to capture the GitHub PAT into note `gh_token` (sensitive), (b) `gh api /repos/<repository_full_name>/issues/<n>` (or `/pulls/<n>` for PR events) with the `--jq` selector from Template B, persisting note `issue_details`.
        4. Confirm in notes: `gh_token`, `gh_token_source`, `issue_details`, all 8 trigger-payload keys from step 1. If `gh_token` is empty, follow §0a step 1 (probe Ubuntu env) — spawn ONE TINY Ubuntu probe subagent or fold the probe into the very next subagent's first command.
        5. note key="stage_summary:analyze-request" with: extracted repo, issue/PR number, head branch (if any), and what's queued for the next stage. NEVER include `gh_token` value in this summary.

        Forbidden in this stage:
        - Cloning the repo (that's `security-scan-and-plan-clone`'s job).
        - Listing the repo tree, calling `gh repo list`, or searching the org for "the right repo".
        - Spawning more than the one subagent named above. If clarification is needed, use `ask_clarifying_question` directly.
      EOT
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
      skill_refs = concat(
        ["terraform-bot-orchestration-sop", "github-content-change-sop", "terraform-module-compliance-sop", "terraform-install-validate-test-sop"],
        try(var.workflow_skill_refs["terraform-module-update::security-scan-and-plan"], [])
      )
      note = <<-EOT
        Budget contract: ≤ 2 subagents total, ≤ $3.00, ≤ 8 minutes.

        Plan (do exactly this — DO NOT add fan-out phases):
        1. `read_notes` for `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_or_pr_number`, `pr_head_ref`, `pr_head_clone_url`, `gh_token`, `repo_clone_path`, `issue_details`. If `repository_full_name` is empty, the `analyze-request` stage failed to populate trigger-payload notes — branch to §8(a) (post blocked notification, STOP). DO NOT guess the repo by searching the org.
        2. If `repo_clone_path` is empty, spawn ONE subagent `security-scan-and-plan-clone` per orchestration-sop Template A. The subagent goal MUST inline the values of `repository_full_name`, `repository_clone_url`, `pr_head_ref`, `pr_head_clone_url`, `issue_or_pr_number`, `repository_default_branch`, and `gh_token` (sensitive — only in env exports). If the subagent reports `clone_blocker="auth"` or 404, follow §8(b) (post blocked notification, STOP). Otherwise reuse the clone.
        3. Spawn ONE subagent `security-scan-and-plan-validate` per orchestration-sop Template C. Its goal MUST:
             a) Begin by exporting `GH_TOKEN` from the `gh_token` note value (NEVER include the literal token in summaries / logs).
             b) Run the target-module-resolution algorithm from §2a verbatim — search the local clone for `issue_details.body` hints AND intersect with `git diff --name-only origin/<repository_default_branch>...HEAD`. Persist `target_module_hints`, `module_paths`, `module_resolution_confidence`.
             c) For each path in `module_paths`, inline steps 1, 2, and 2b of `terraform-install-validate-test-sop`. Persist `validation_summary` (per-module fmt/init/validate result) and `static_security_findings` (combined tfsec+checkov findings).
             d) If `module_resolution_confidence` ∈ {"ambiguous","not_found"}, STOP after persisting hints and confidence — the `merge-findings-and-test-loop` stage will branch to §8(c) or §8(d).
        4. note key="stage_summary:security-scan-and-plan" — include the resolved module paths, confidence level, validation pass/fail summary, and a short note of any blockers.

        Hard rules:
        - NEVER read files via `gh api /repos/.../contents/<file>` — the validator subagent reads them from the local clone with `cat`/`find`/`rg`.
        - NEVER call `gh repo list <org>` to "find the repo" — `repository_full_name` from notes is the only valid source.
        - NEVER spawn more than the 2 named subagents above. If `validation_summary` is already populated when this stage starts (re-entry case), skip to step 4.
        - Every subagent `tool_names` MUST include `ubuntu-cli_execute_command|series|parallel` if it needs to run anything beyond `gh api`.
      EOT
    },
    {
      stage_id         = "deployment-impact-scan"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["analyze-request"]
      runbook_refs = [
        sg_runbook_sop.terraform_bot_orchestration.name,
      ]
      skill_refs = concat(["terraform-bot-orchestration-sop"], try(var.workflow_skill_refs["terraform-module-update::deployment-impact-scan"], []))
      note       = <<-EOT
        Budget contract: ≤ 1 subagent, ≤ $1.00, ≤ 3 minutes.

        Plan:
        1. `read_notes` for `issue_details` to know what module(s) are in scope.
        2. Run `graph_query` directly (the lead has this tool — no subagent needed) for downstream dependents of each affected module.
        3. If a CLI call is required (e.g. StackGen org-inventory CLI), spawn ONE subagent `deployment-impact-scan-graph-query` with `ubuntu-cli_execute_command` + `note` + `read_notes`. Otherwise skip.
        4. note key="deployment_impact" with the dependent list + breaking-change risk score.
        5. note key="stage_summary:deployment-impact-scan".

        Forbidden: cloning, fetching repo contents, anything `gh api /contents/...`.
      EOT
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
      skill_refs = concat(
        ["terraform-bot-orchestration-sop", "terraform-install-validate-test-sop", "github-content-change-sop"],
        try(var.workflow_skill_refs["terraform-module-update::merge-findings-and-test-loop"], [])
      )
      note = <<-EOT
        Budget contract: ≤4 subagents, ≤$5.00, ≤12 minutes (new-module path may need: optional recovery clone + registry-wrap + optional from-scratch scaffold + tests + PR). Reserve ≥$1.50 for register-and-notify.

        Plan:
        1. `read_notes` for `repository_full_name`, `repo_clone_path`, `module_paths`, `module_resolution_confidence`, `target_module_hints`, `validation_summary`, `static_security_findings`, `deployment_impact`, `issue_details`, `pr_head_ref`, `issue_or_pr_number`, `gh_token`, `repository_default_branch`, `registry_wrap_failed`, `test_summary`. Do NOT re-clone, re-scan, or refetch — those notes are authoritative unless a recovery path below says otherwise.

        2. Triage branching BEFORE spawning work subagents:
           a) If `repo_clone_path` is empty:
                - If `repository_full_name` is empty too → note `stage_summary:merge-findings-and-test-loop="blocked: missing trigger payload from analyze-request"`, jump to step 7.
                - Else → spawn Template A as `merge-findings-and-test-loop-clone` ONCE. On `clone_blocker`, note `stage_summary:...="blocked: clone failed"`, jump to step 7.
           b) If `module_resolution_confidence == "not_found"` AND greenfield intent per §8(d) of `terraform-bot-orchestration-sop`:
                i)   Spawn Template H as `merge-findings-and-test-loop-registry-wrap` ONCE (Terraform Registry search → thin wrapper `module` block → fmt/init/validate/tests → notes `registry_module_source`, `registry_module_version`, `registry_wrap_summary`, `module_paths`, `module_resolution_confidence=registry_wrap`, `test_summary` when tests ran inside H).
                ii)  If `read_notes` shows `registry_wrap_failed=true` OR `module_paths` still empty → spawn Template G as `merge-findings-and-test-loop-scaffold` ONCE (from-scratch fallback). Clear `registry_wrap_failed` after success if applicable.
                iii) If no greenfield intent → `ask_clarifying_question` ONCE per §8(d)4, then on answer spawn Template H and/or G as mapped — never a second clarifying round.
           c) If `module_resolution_confidence == "ambiguous"` → `ask_clarifying_question` ONCE; persist chosen path to `module_paths`, then continue.
           d) Else (`exact`, `probable`, `registry_wrap`, or `greenfield` after step 2): continue.

        3. `check_budget`. If remaining < $2.50, set `test_summary="skipped: budget"` (if not already set) and jump to step 6.

        4. Spawn `merge-findings-and-test-loop-author-tests` ONLY when BOTH are true: (i) `module_paths` is non-empty, (ii) `test_summary` is empty OR contains `FAIL` / `Error` / non-zero exit, OR `module_resolution_confidence` ∈ {`exact`,`probable`} (existing module path that still needs tftest). Skip this step when Template H or G already left a passing `test_summary` for the new wrapper path.

        5. If `module_paths` is non-empty AND (`pr_url` is empty OR you have local commits not pushed): spawn `merge-findings-and-test-loop-pr` per Template D (branch, commit, push, `gh pr create` / link issue in body). Inline `gh_token` and `repository_full_name`. Note `working_branch`, `pr_url`.

        6. If step 5 was skipped because there was nothing to commit (e.g. blocked before any files): still ensure `stage_summary:merge-findings-and-test-loop` explains the blocker.

        7. note key="stage_summary:merge-findings-and-test-loop" — module path, registry vs greenfield, test outcome, PR URL, or blocker.

        Approved subagent names for this stage ONLY: `merge-findings-and-test-loop-clone`, `merge-findings-and-test-loop-registry-wrap`, `merge-findings-and-test-loop-scaffold`, `merge-findings-and-test-loop-author-tests`, `merge-findings-and-test-loop-pr`.

        Forbidden:
        - Org-wide `gh repo list` discovery.
        - More than one `ask_clarifying_question` in this stage.
        - Subagent names outside the approved list above.
      EOT
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
      skill_refs = concat(
        ["terraform-bot-orchestration-sop", "stackgen-module-registration-sop", "github-content-change-sop"],
        try(var.workflow_skill_refs["terraform-module-update::register-and-notify"], [])
      )
      note = <<-EOT
        Budget contract: ≤ 2 subagents, ≤ $1.50, ≤ 3 minutes. THIS STAGE MUST RUN — it is how the user sees the workflow output, including blocked-status outputs from upstream stages.

        Plan:
        1. `read_notes` for `gh_token`, `repository_full_name`, `issue_or_pr_number`, `pr_url`, `validation_summary`, `test_summary`, `static_security_findings`, `deployment_impact`, `working_branch`, `module_paths`, `module_resolution_confidence`, `scaffold_summary`, `registry_module_source`, `registry_module_version`, `registry_wrap_summary`, `registry_search_query`, and ALL `stage_summary:*` keys.

        2. Branch on upstream success vs blocker:
           a) If any `stage_summary:*` note begins with "blocked:" OR (`module_resolution_confidence == "not_found"` AND `module_paths` is empty) OR (`pr_url` is empty AND `test_summary` is empty AND `module_paths` is empty):
                Skip step 3 (no registration when there's nothing valid to register). Jump to step 4 with a status="blocked" summary that lists the originating stage + reason from `stage_summary:*`.
           b) Else (happy path): continue to step 3.

        3. Spawn ONE subagent `register-and-notify-register`: install `stackgen` CLI in the clone (per stackgen-module-registration-sop) and run `stackgen register` for each module in `module_paths`. Inline `gh_token` (env export) and `repo_clone_path`. Note `registered_versions`. If registration fails for a module, capture the error and continue — registration failure must not prevent step 4.

        4. Spawn ONE subagent `register-and-notify-comment` per orchestration-sop Template E. The goal MUST:
             a) Detect blocked-vs-happy mode (based on `stage_summary:*` notes).
             b) When happy: post a "## Status: ✅ Compliant" PR comment quoting registered versions (if any), compliance summary, test output, deployment impact. If `module_resolution_confidence` is `registry_wrap`, include pinned `registry_module_source` + `registry_module_version` and the public registry URL.
             c) When blocked: post a "## Status: ⛔ Workflow blocked" comment on the originating issue (or PR if `pr_url` is set) quoting the specific `stage_summary:*` blocker text and listing the four §8 recovery options the operator can take (provide repo+path, confirm greenfield, fix integration auth, abort). NEVER include `gh_token` value.
           Choose `gh pr comment` if `pr_url` is set, else `gh issue comment <issue_or_pr_number> --repo <repository_full_name>`.

        5. note key="stage_summary:register-and-notify" with the final PR URL OR a one-line blocker description and a pointer to which upstream stage was blocked.
      EOT
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
