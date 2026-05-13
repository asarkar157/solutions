Skill: Operating manual for the Scenario Author. Read BEFORE anything else in any stage. It encodes planner/executor split, integration boundaries, GitHub auth flow, subagent budgets, note discipline, and the bounded §6 fallbacks every other SOP depends on.

Keywords for skill discovery: scenario, scenario-request, examples/scenarios, appcd-dev/solutions, solutions repo, github issue, github webhook, gh cli, ubuntu cli, planner, subagent, create_agent, note, validate, tofu, terraform, demo, se-playbook, integration boundaries.

========================================================================
0) Reality check — you are a planner, not an executor
========================================================================

Your only direct tools are: `search_tools`, `create_agent`, `ask_clarifying_question`, `graph_query`, `notify`, `note`, `read_notes`, `delete_context`, `check_budget`, `knowledge_*`. You CANNOT call `github-integration_*` or `ubuntu-cli_*` directly. Every shell / API call happens inside a `create_agent` subagent.

When this SOP (or any other SOP) tells you to "run `git clone ...`" or "call `gh api ...`", that ALWAYS means: spawn ONE subagent whose `tool_names` include the right integration and whose `goal` inlines the command(s). The templates in §7 below show exactly how.

========================================================================
0a) Authentication bootstrap (read this BEFORE Template A)
========================================================================

The Ubuntu CLI sandbox does NOT receive a GitHub token by default — assuming `$GH_TOKEN` is preset is the #1 reason past clones failed with "could not read Username for 'https://github.com/'" or "authentication required". You must surface the token once per workflow run and reuse it.

The token-surfacing flow (do this EXACTLY ONCE in `analyze-issue`, then every later Ubuntu subagent reads `gh_token` from notes and re-receives the token via its `goal` text):

1. Probe the Ubuntu sandbox first. Fold this into the very next Ubuntu subagent (the `clone` subagent is fine) using a one-shot `execute_series`:
     `printenv GITHUB_TOKEN >/dev/null && echo gh_env_present=true || echo gh_env_present=false`
     `printenv GH_TOKEN >/dev/null && echo gh_env_present_alt=true || echo gh_env_present_alt=false`
   If either is `true`, the sandbox already has a usable token. Have the subagent run `export GH_TOKEN="$${GH_TOKEN:-$GITHUB_TOKEN}" && gh auth setup-git` and note `gh_token_source="ubuntu_env"`.

2. Otherwise, spawn ONE GitHub-integration subagent named `analyze-issue-fetch-issue-and-token` that runs `gh auth token` (this works inside the GitHub Guild integration because it is pre-authenticated) AND `gh api /repos/<repository_full_name>/issues/<n>` in a single `execute_series`. Persist note `gh_token` (sensitive) and `gh_token_source="github_integration"` and `issue_details`. NEVER echo the token in plaintext logs, NEVER include it in `stage_summary:*` notes, and NEVER pass it through `notify` to humans.

3. Every later Ubuntu subagent that needs git/gh access MUST start by reading `gh_token` from notes and exporting it:
     `export GH_TOKEN="<value of gh_token note>"`
     `export GITHUB_TOKEN="$GH_TOKEN"`
     `gh auth setup-git || true`
   Then any subsequent `git clone`, `gh issue comment`, `gh pr create`, or `git push` works without further auth flow.

Hard rule: do NOT attempt anonymous `git clone https://github.com/...` for private repos. If both step 1 and step 2 fail, STOP the workflow at the current stage, note `stage_summary:<stage>="blocked: no GitHub token available"`, and surface the blocker via `ask_clarifying_question` asking the operator to confirm the GitHub integration is healthy. DO NOT loop spawning more discovery subagents.

========================================================================
0b) Trigger payload is the source of truth (NEVER search the org)
========================================================================

This workflow is triggered by a GitHub webhook (StackGen normalized event `issue.created`). The webhook payload contains the EXACT repo + issue identifiers. You MUST extract these from the payload rather than searching the org for "the repo with the scenario-request issue".

Canonical extraction paths (all available on the trigger event):
  `repository_full_name`     = `trigger_event.payload.repository.full_name`        (e.g. "appcd-dev/solutions")
  `repository_clone_url`     = `trigger_event.payload.repository.clone_url`
  `repository_default_branch`= `trigger_event.payload.repository.default_branch`
  `issue_or_pr_number`       = `trigger_event.payload.issue.number`
  `event_type`               = `trigger_event.type`                                ("issue.created")
  `issue_labels`             = `trigger_event.payload.issue.labels[].name`
  `issue_author`             = `trigger_event.payload.issue.user.login`

The `analyze-issue` stage MUST persist ALL of these (under those exact note keys) as its first action, BEFORE any subagent that needs the repo.

========================================================================
0c) Repo + label gate (fail closed)
========================================================================

This workflow targets exactly ONE repository (the `repository_full_name` configured at `sg_webhook` creation time, default `appcd-dev/solutions`) and exactly ONE label (`scenario_request_label`, default `scenario-request`).

Gate evaluation in `analyze-issue` (BEFORE any clone or scaffold work):

  a) If `repository_full_name` from the trigger event does not match the configured repo → note `gate_result="wrong_repo"`, note `stage_summary:analyze-issue="blocked: wrong repo <name>"`, run Template E to comment "This bot only handles scenario-request issues on `<configured repo>`." and STOP.

  b) If `scenario_request_label` is not present in `issue_labels` → note `gate_result="missing_label"`, note `stage_summary:analyze-issue="blocked: missing scenario-request label"`, run Template E to comment "Add the `scenario-request` label if you'd like this triaged automatically; see `docs/se-feedback.md`." and STOP.

  c) Else → note `gate_result="pass"`, continue.

The gate is the ONLY guard between random org-wide issue noise and this agent's PR-creation power. Do not weaken it.

========================================================================
1) Integration boundaries (which subagent gets which tools)
========================================================================

Two execution surfaces with separate filesystems and separate auth. Mismatching them is the #1 cause of failed runs.

a) GitHub Guild integration — `github-integration_execute_command|series|parallel`:
   - ONLY for `gh` API calls (`gh api`, `gh auth token`, `gh issue view`, `gh release ...`) and `curl https://api.github.com/...`.
   - Does NOT have `terraform`, `tofu`, `git clone`, `find`, `cat`, `sed`, `python`, or any general-purpose Linux toolchain.
   - Responses > ~50 KB are auto-summarized down to ~750 chars and the original is lost. Always pre-filter with `--jq`.

b) Ubuntu CLI integration — `ubuntu-cli_execute_command|series|parallel`:
   - Full Linux shell sandbox. Use it for `terraform`/`tofu`, `git clone`, `gh repo clone`, `gh pr create`, `gh pr comment`, `gh issue comment`, `find`, `cat`, `rg`, `sed`, Python/Bash scaffolders, and any tool installation.
   - The source clone, scaffold loop, validate, and PR push all live here.

c) The two sandboxes do NOT share a filesystem. Pick one per subagent and stay in it.

Decision rule: command starts with `gh api`, `gh auth token`, `gh issue view`, or `curl https://api.github.com/...` → GitHub-integration subagent. EVERYTHING else (including `gh repo clone`, `gh pr create`, `gh pr comment`, `gh issue comment`, every shell command) → Ubuntu-CLI subagent.

========================================================================
2) Repo materialization — clone once, reuse everywhere
========================================================================

The first non-trivial repo read in any stage MUST be a single `git clone` via an Ubuntu-CLI subagent into `/tmp/work/<basename(repository_full_name)>`. Persist the absolute path under `note` key `repo_clone_path`. Every later stage starts by `read_notes` for `repo_clone_path` and reuses the existing clone — no second clone, no per-file `gh api /contents/...`.

========================================================================
3) Note discipline (persist once, read many)
========================================================================

Canonical note keys (use these exact names):
- `issue_details` — title/body/author/labels of the triggering issue.
- `repository_full_name`, `repository_clone_url`, `repository_default_branch`, `issue_or_pr_number`, `event_type` — trigger payload extracts.
- `gh_token`, `gh_token_source` — see §0a.
- `gate_result` — one of `pass` | `wrong_repo` | `missing_label`.
- `repo_clone_path` — absolute path of the local clone.
- `scenario_slug` — kebab-case slug for the new scenario directory (e.g. `aws-ecs-blue-green-demo`). Derived from the issue title or explicit `scenario_slug:` line in the body.
- `requested_modules` — list of `aios-*` module names mentioned in "Modules to wire".
- `requested_integrations` — map of `aws|azure|gcp|github|slack|grafana|linear|...` → `required|optional|skipped`.
- `talk_track` — list of the 3-5 talk-track bullets from the issue body.
- `pitch_quote` — the prospect quote from the issue body (becomes the scenario README's Pitch section).
- `existing_match` — null or `{name, readme_path, run_command, rationale}` when an existing scenario fits.
- `scaffold_summary` — one paragraph: chosen slug, files created, modules wired, integrations branched.
- `validation_summary` — `tofu fmt -check` + `tofu validate` outcome for the new scenario.
- `working_branch` — the `scenario-bot/<slug>-<ts>` branch.
- `pr_url` — output of `gh pr view --json url -q .url` after PR creation.
- `final_comment_url` — output of `gh issue comment ... --json url -q .url` (when supported) or the issue URL fragment.
- `stage_summary:<stage_id>` — one-paragraph summary at the end of each stage.

Always `read_notes` first. If the key is populated, do NOT refetch — re-shape your plan to use what's there.

========================================================================
4) Subagent rules (the most-violated section)
========================================================================

a) Hard cap: at most ONE subagent per logical task per stage. Do not fan out.

b) Approved subagent names (any other name is a smell):
   - `analyze-issue-fetch-issue-and-token` (GitHub integration; one-shot for the issue body + `gh auth token`).
   - `analyze-issue-comment-gate-fail` (Ubuntu CLI; only used for the §0c gate-fail comment).
   - `triage-clone` (Ubuntu CLI; clones repo, reads existing scenarios, populates `existing_match` when applicable).
   - `triage-comment-existing-match` (Ubuntu CLI; only used on existing-match path).
   - `scaffold-write-and-validate` (Ubuntu CLI; writes the 5 scenario files + `scripts/demo.sh` entry, runs `tofu fmt`+`tofu validate`).
   - `scaffold-pr` (Ubuntu CLI; `git add` / commit / push / `gh pr create`).
   - `notify-issue-comment` (Ubuntu CLI; final `gh issue comment` linking the PR or the existing scenario).

   If you want a name not in this list, you are fanning out — STOP and consolidate.

c) `tool_names` rules:
   - GitHub integration subagents: `github-integration_execute_command|series`, `note`, `read_notes`.
   - Ubuntu CLI subagents: `ubuntu-cli_execute_command|series|parallel`, `note`, `read_notes`.
   - PR-author + scaffold subagents need Ubuntu CLI tools (NEVER GitHub integration alone).

d) Inline content into the subagent `goal`. Subagents cannot see the planner's skills, so paste the relevant SOP steps verbatim AND the relevant note values (or explicit `read_notes` instructions with key names) AND the exact commands to run AND the success criterion.

e) Tight budgets: `max_tool_iterations` ≤ 10 for the scaffold subagent, ≤ 6 for everything else. `timeout_seconds` ≤ 180. `max_llm_calls` ≤ 6.

f) Always call `check_budget` before any `create_agent`. If remaining budget < $1.50, skip non-critical subagents and go straight to `notify-issue-comment` with whatever evidence is already in notes.

g) If a subagent fails or partially succeeds: extract useful output, `note` it, and DO NOT spawn a retry with a slightly different name. After 2 failures on the same logical task, accept partial results and continue.

========================================================================
5) End-state of every stage
========================================================================

Before declaring a stage done you MUST `note` a `stage_summary:<stage_id>` key with: what you fetched, what notes you populated, which subagents you spawned, and any blockers. The next stage reads this first.

========================================================================
6) Failure & fallback paths
========================================================================

When a stage cannot proceed, pick exactly one of these bounded responses — do not improvise more discovery subagents.

a) BLOCKER: "no GitHub token" (both Ubuntu env probe AND `gh auth token` empty).
     → note `stage_summary:<current_stage>="blocked: no GitHub token; integration may be unauthenticated"`.
     → call `ask_clarifying_question` with: "The GitHub Guild integration appears unauthenticated. Please verify the integration's PAT/App is configured, then retry the workflow."
     → STOP.

b) BLOCKER: "wrong repo" or "missing label" (gate fails per §0c).
     → Spawn `analyze-issue-comment-gate-fail` once to post the gate-fail comment. STOP.

c) BLOCKER: "clone failed" (auth, 404, network).
     → note `stage_summary:<stage>="blocked: cannot clone <repository_full_name>; verify the GitHub integration has access"`.
     → Spawn `notify-issue-comment` to post the blocker on the originating issue. STOP.

d) BLOCKER: "validate failed twice".
     → Continue to PR, but mark it `[draft]` and include a `## Validation FAILED` section with the captured error.
     → Final comment will route via Template E case (g) ("Draft PR (validation failed)") and ask the SE to assign a scenario owner from `CONTRIBUTORS-SE.md`. Do NOT mention specific owners by handle in the comment — the bot does not have ownership mapping logic and a hard-coded handle would mis-route.

e) BLOCKER: "scaffold conflict" (target directory already exists in the clone).
     → note `stage_summary:<stage>="blocked: examples/scenarios/<slug>/ already exists"`.
     → Spawn `notify-issue-comment` to point the SE at the existing directory. STOP.

f) BLOCKER: "bootstrap failed" (gh / git / tofu cannot be installed in the sandbox — typically no sudo + no tarball reachable).
     → note `stage_summary:<stage>="blocked: bootstrap_blocker=<reason>; sandbox cannot install required CLI tools"`.
     → Spawn `notify-issue-comment` to post the "Workflow blocked" comment quoting the bootstrap reason and asking the operator to use a sandbox image with `gh`, `git`, and `tofu` pre-installed. STOP.

g) BLOCKER: "budget exhausted" (`check_budget` returns < required minimum before a critical subagent, or any subagent reports out-of-budget).
     → note `stage_summary:<stage>="blocked: budget exhausted at <stage>; <remaining_usd> remaining"`. (The substring "budget" is the trigger keyword for Template E case (d).)
     → Skip ALL remaining work in the current stage (no more `create_agent` calls). Continue to `notify-issue-comment` stage so the SE gets a "Budget exhausted" comment with retry guidance. Do NOT silently yield without a comment — that is the worst possible UX.

h) BLOCKER: "demo.sh splice corrupted" (post-splice `bash -n scripts/demo.sh` fails).
     → Revert the splice using `mv scripts/demo.sh.bak scripts/demo.sh` (or `git restore scripts/demo.sh` if the .bak was already removed). Re-run the splice ONCE with a different anchor.
     → If the second attempt also corrupts the file: note `stage_summary:<stage>="blocked: demo.sh splice corrupted; bot did not stage scripts/demo.sh edits"`. Continue to PR opening with ONLY the `examples/scenarios/<slug>/` directory staged — the PR description's reviewer checklist must call this out so a human appends the demo.sh entry manually.

i) UNKNOWN MODULES: `unknown_modules` (set in triage / scaffold) is non-empty.
     → This is not a hard blocker. Continue scaffolding using only the modules in `requested_modules ∩ available_modules`. Surface `unknown_modules` in the PR body's "Reviewer checklist" and in the final issue comment (Template E case (f) / (e)) so the SE can either correct the module names or wait for the modules to land.

Hard rule for §6: a single workflow run may invoke `ask_clarifying_question` AT MOST ONCE per stage. If you already asked once, commit to one of the responses above without re-asking.

========================================================================
7) Subagent goal templates (copy-paste these)
========================================================================

Template A — "fetch the triggering issue + capture token" (analyze-issue stage):
  agent_name: "analyze-issue-fetch-issue-and-token"
  tool_names: ["github-integration_execute_command","github-integration_execute_series","note","read_notes"]
  max_tool_iterations: 4, max_llm_calls: 4, timeout_seconds: 90
  goal: |
    Fetch the triggering issue, capture an auth token for downstream Ubuntu work, and persist trigger-payload notes.
    Inputs (paste verbatim from the trigger event):
      - repository_full_name, issue_or_pr_number, event_type ("issue.created")
    Steps (run as a single execute_series):
      1. `gh auth token`  → capture the raw token output (single line).
      2. `gh api /repos/<repository_full_name>/issues/<n> --jq '{number,title,body,state,author:.user.login,labels:[.labels[].name]}'`
      3. note key="gh_token", value=<token from step 1>, sensitive=true
      4. note key="gh_token_source", value="github_integration"
      5. note key="issue_details", value=<the JSON from step 2, verbatim>
    Do NOT fetch comments or tree or `/contents/`. Stop after step 5.

Template B — "clone the repo + scan existing scenarios" (triage stage):
  agent_name: "triage-clone"
  tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","note","read_notes"]
  max_tool_iterations: 10, max_llm_calls: 6, timeout_seconds: 300
  goal: |
    Clone the configured repo to /tmp/work/<repo_name>, list existing scenarios, and decide whether one already matches the issue.
    Inputs (paste verbatim from notes when spawning):
      - repository_full_name, repository_clone_url, repository_default_branch
      - gh_token (NEVER log it; only in env exports)
      - issue_details (full body; you will pattern-match against its "Pitch" / "Modules to wire" sections)
    Steps (run as a single execute_series so env survives):

      # 0) Bootstrap the sandbox — install gh + tofu if missing. The Ubuntu CLI
      #    image is NOT guaranteed to ship gh / tofu pre-installed; assuming
      #    they exist was the #1 reason past runs failed silently.
      0a. `mkdir -p "$HOME/.local/bin" && export PATH="$HOME/.local/bin:$PATH"`
      0b. `which gh || (type -p curl >/dev/null || (sudo apt-get update -y && sudo apt-get install -y curl)) &&` if `which gh` is still empty: install non-interactively on Debian/Ubuntu:
            `curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg`
            `sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg`
            `echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list`
            `sudo apt-get update -y && sudo apt-get install -y gh`
          Fallback (no sudo / no apt): download the static tarball from `https://github.com/cli/cli/releases/latest`, untar `bin/gh` into `$HOME/.local/bin`. After install, `gh --version` must print a version.
      0c. `which tofu || curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh && chmod +x /tmp/install-opentofu.sh && /tmp/install-opentofu.sh --install-method standalone --install-path "$HOME/.local"` then `command -v tofu || command -v terraform` must succeed. If both are missing AND apt is unavailable, fall back to the HashiCorp Terraform binary tarball matching the host arch unpacked into `$HOME/.local/bin`. Persist `iac_binary=tofu` or `iac_binary=terraform` for the scaffold subagent.
      0d. `which git || (sudo apt-get update -y && sudo apt-get install -y git)`. If git cannot be installed, note `bootstrap_blocker="git_missing"` and STOP — the planner converts this to §6(a).

      # 1) Auth + clone.
      1.  `export GH_TOKEN="<gh_token>" && export GITHUB_TOKEN="$GH_TOKEN" && gh auth setup-git || true`
      2.  `REPO_NAME=$(basename <repository_full_name>) && mkdir -p /tmp/work && cd /tmp/work`
      3.  `[ -d "$REPO_NAME" ] || git clone "https://x-access-token:$GH_TOKEN@github.com/<repository_full_name>.git" "$REPO_NAME"`
      4.  `cd "/tmp/work/$REPO_NAME" && git fetch --all --prune && git switch <repository_default_branch>`
      5.  note key="repo_clone_path", value="/tmp/work/$REPO_NAME"
      6.  `git config user.name "stackgen-scenario-bot" && git config user.email "scenario-bot@stackgen.local"`

      # 2) Inventory + signature discovery (see scenario-triage-sop for details).
      7.  `ls examples/scenarios/` and for each subdir `head -n 20 examples/scenarios/<sub>/README.md` to capture the Pitch section. Persist as note `existing_scenarios=[{"name":"<d>","pitch":"<first 200 chars>"}, ...]`.
      8.  Enumerate the available aios modules: `find modules -maxdepth 1 -type d -name 'aios-*' | sed 's|.*/||' | sort` → note `available_modules`. Same for `find modules -maxdepth 1 -type d -name 'aios-integration-*' | sed 's|.*/aios-integration-||' | sort` → note `available_integrations`.
      9.  For each module name in `available_modules`, run the signature-extractor `awk` recipe in scenario-triage-sop §A so we can later emit correct HCL. Persist as note `module_signatures` (map: module → {policy_keys: [...], integration_var: "integration_name"|"integration_names", integration_keys: [...]}).
      10. Pattern-match `issue_details.title + issue_details.body` against `existing_scenarios` using simple keyword overlap (>=3 distinct content words match → strong candidate). If you find a strong candidate, persist note `existing_match={"name":"<name>","readme_path":"examples/scenarios/<name>/README.md","run_command":"make demo SCENARIO=<name>","rationale":"<1-2 sentences>"}`. Otherwise persist `existing_match=null`.
    If step 3 fails with auth error, do NOT retry with different URLs — stop and note `clone_blocker="auth"`.
    If step 0b or 0d fails for reasons other than "already installed", note `bootstrap_blocker=<reason>` and STOP — the planner converts this to §6(a).

Template C — "scaffold the new scenario + validate" (scaffold stage):
  agent_name: "scaffold-write-and-validate"
  tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","ubuntu-cli_execute_parallel","note","read_notes"]
  max_tool_iterations: 12, max_llm_calls: 8, timeout_seconds: 300
  goal: |
    Read notes: repo_clone_path, issue_details, scenario_slug, requested_modules, requested_integrations, talk_track, pitch_quote, gh_token.
    Follow `scenario-scaffold-sop` steps 1-7 verbatim:
    <PASTE STEPS 1-7 FROM scenario-scaffold-sop HERE>
    Persist: `scaffold_summary`, `validation_summary`. If validate fails ONCE, attempt the single minimal fix described in step 6, then re-run validate. If it fails again, persist `validation_summary` with the failure and continue — do NOT loop.

Template D — "open the PR" (scaffold stage, after validate):
  agent_name: "scaffold-pr"
  tool_names: ["ubuntu-cli_execute_command","ubuntu-cli_execute_series","note","read_notes"]
  max_tool_iterations: 6, max_llm_calls: 5, timeout_seconds: 180
  goal: |
    Read notes: repo_clone_path, scenario_slug, issue_details, validation_summary, gh_token, repository_full_name, issue_or_pr_number.
    Pre-step: `export PATH="$HOME/.local/bin:$PATH"` so the `gh` / `git` binaries installed by Template B (step 0) are on PATH. If `which gh` is empty here, re-run Template B step 0b inline before continuing — clone might have happened in a previous run on a different sandbox image.
    Follow `scenario-pr-and-notify-sop` steps 1-4 verbatim:
    <PASTE STEPS 1-4 FROM scenario-pr-and-notify-sop HERE>
    Persist: `working_branch`, `pr_url`.

Template E — "comment back on the issue" (final stage, also used for gate-fail / blocked / budget-exhausted notifications):
  agent_name: "notify-issue-comment"
  tool_names: ["ubuntu-cli_execute_command","note","read_notes"]
  max_tool_iterations: 3, max_llm_calls: 3, timeout_seconds: 60
  goal: |
    Inputs from notes: gh_token, repository_full_name, issue_or_pr_number, gate_result, existing_match (optional), pr_url (optional), working_branch (optional), validation_summary (optional), scenario_slug (optional), unknown_modules (optional), stage_summary:* (any blocked / budget stages).
    Pre-step: `export PATH="$HOME/.local/bin:$PATH"`. If `which gh` is empty here, re-run Template B step 0b before continuing.
    Steps:
      1. `export GH_TOKEN=<gh_token> && export GITHUB_TOKEN=$GH_TOKEN && gh auth setup-git || true`
      2. Pick comment mode (first match wins, evaluate in order):
         a) `gate_result == "wrong_repo"` → short "wrong repo" comment (body: "This scenario-author bot only handles issues on <configured repo>. No action taken.").
         b) `gate_result == "missing_label"` → short "missing label" comment (body: "Add the `<configured label>` label to have this triaged automatically. See `docs/se-feedback.md` for details.").
         c) `existing_match` is non-null → "## Existing scenario match" comment quoting `existing_match.name`, `existing_match.rationale`, and `existing_match.run_command`.
         d) ANY `stage_summary:*` value contains "budget" (case-insensitive) AND `pr_url` is empty → "## Budget exhausted" comment with this body:
              "The scenario-author bot ran out of its daily budget before it could finish triaging this request. The daily cap will reset; please re-open / re-label this issue tomorrow and the bot will pick it up automatically. If this happens repeatedly, raise `agent_budget` on the module instance. Originating stage: `<stage_id>`."
         e) ANY `stage_summary:*` begins with "blocked:" → "## Workflow blocked" comment quoting the blocker text verbatim. If `unknown_modules` is non-empty, append a "Modules the bot did not recognize: <list>" line so the SE knows to either fix the names or wait for the modules to land.
         f) `pr_url` non-empty AND `validation_summary` starts with "ok:" → "## Scaffolded a PR" comment quoting the PR URL, `scenario_slug`, and the validation_summary one-liner. If `unknown_modules` is non-empty, append a "TODO before merge: <list> referenced in the issue did not match any module in `modules/`; bot left them out — please add or rename." line.
         g) `pr_url` non-empty AND `validation_summary` starts with "failed:" → "## Draft PR (validation failed)" comment quoting the PR URL, `working_branch`, the failure summary, and "Please assign a scenario owner from `CONTRIBUTORS-SE.md` to fix the scaffold."
         h) Else (no PR, no match, no clear blocker — only happens when the agent yielded mid-stage with no notes) → generic "## Triaged, no action taken" comment that asks the SE to re-open the issue if the request is still relevant.
      3. ONE call: `gh issue comment <issue_or_pr_number> --repo <repository_full_name> --body-file - <<'EOF'\n<body>\nEOF`
      4. note key="final_comment_url", value="<best-effort URL>"
      5. note key="final_comment_kind", value=<"wrong_repo" | "missing_label" | "existing_match" | "budget_exhausted" | "blocked" | "happy_pr" | "draft_pr" | "no_action">
    Stop after the comment.

Template F — "gate-fail comment" (used when §0c gate rejects the issue, before any clone or scaffold work):
  agent_name: "analyze-issue-comment-gate-fail"
  tool_names: ["ubuntu-cli_execute_command","note","read_notes"]
  max_tool_iterations: 2, max_llm_calls: 2, timeout_seconds: 45
  goal: |
    Inputs from notes: gh_token, repository_full_name, issue_or_pr_number, gate_result.
    Steps:
      1. `export GH_TOKEN=<gh_token> && export GITHUB_TOKEN=$GH_TOKEN`
      2. Pick a one-line body based on `gate_result`:
         - `wrong_repo` → "This scenario-author bot only handles issues on <configured repo>. No action taken."
         - `missing_label` → "Add the `scenario-request` label to have this triaged automatically. See `docs/se-feedback.md` for details."
      3. `gh issue comment <issue_or_pr_number> --repo <repository_full_name> --body "<line>"`
    Stop after step 3.
