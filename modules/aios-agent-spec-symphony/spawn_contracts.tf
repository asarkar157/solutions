# Per-stage subagent spawn contracts for spec-symphony workflow.

locals {
  shell_execute_series_working_dir_rule = "commands[0].working_dir=${local.shell_work_home} or omit — NEVER {{work_root}} or $HOME/.wf-* (host chdirs before clone-pack creates WORK_ROOT)."

  shell_execute_series_shell_dollar_rule = <<-EOT
Shell runner execute_series: use single $ for variables ($PD, $WORK_ROOT, $REPO_CLONE_URL). NEVER $$ before a name — bash expands $$ to shell PID and breaks pack decode.
Env scoping: use VAR=value …; semicolon before pack ensure.
Path scoping: copy spawn-header {{work_root}} verbatim in WORK_ROOT='{{work_root}}' — FORBIDDEN: $HOME/.wf-*, $HOME}/, or manual path concatenation (trace 50f1cc3d, 4c720966).
Spawn discipline: spawn subagents by **agent_name only** — Guild replaces goal with spawn contract. FORBIDDEN: custom goal/context JSON on spawn (trace 4c720966).
EOT

  specsym_spawn_context_header = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
ABS_WORK_ROOT: {{work_root}}
shell_work_home: ${local.shell_work_home}
execute_series_working_dir: ${local.shell_work_home}
SPECSYM_PACK_DIR: ${local.specsym_pack_dir}
script_pack_version: ${local.script_pack_version}
${local.shell_execute_series_shell_dollar_rule}
EOT

  specsym_spawn_context_blocker_notify = <<-EOT
${local.specsym_spawn_context_header}
Blocker comment command (copy verbatim — ONE execute_series):
  REPO_FULL_NAME='<repository_full_name from read_notes>' ISSUE_OR_PR='<issue_or_pr_number from read_notes>' BLOCKER_DETAIL='<clone_blocker + stage_summary:intake-clone-bootstrap from read_notes>' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/blocker-comment.sh
On notify_blocker=issue_not_found: note notify_skipped=issue_not_found (webhook used fake issue — operator should re-trigger with real GitHub issue).
Stdout MUST include notify_exit=0 or notify_blocker=issue_not_found.
EOT

  specsym_spawn_context_tracker_notify = <<-EOT
${local.specsym_spawn_context_header}
Tracker update command (when pr_url or ci_status in notes):
  REPO_FULL_NAME='<repository_full_name>' ISSUE_OR_PR='<issue_or_pr_number>' COMMENT_BODY='pr_url=<pr_url> ci_status=<ci_status>' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/blocker-comment.sh
EOT

  specsym_spawn_context_clone = <<-EOT
${local.specsym_spawn_context_header}
Clone command (copy verbatim — set env vars only; clone-pack reads WORK_ROOT/REPO_CLONE_URL from env; NO positional path args):
  WORK_ROOT='{{work_root}}' REPO_CLONE_URL='<repository_clone_url from read_notes>' DEFAULT_BRANCH='<repository_default_branch from read_notes>' ISSUE_OR_PR='<issue_or_pr_number from read_notes>' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/clone-pack.sh clone
On specsym_pack_error=: note clone_blocker=missing_script_pack. On clone_blocker=malformed_work_root: STOP — use WORK_ROOT='{{work_root}}' from spawn header only.
FORBIDDEN in commands[0].command: clone-pack.sh clone with path args; $HOME/.wf-*; $HOME}/; {{work_root}} in shell (Guild substitutes in spawn header only); CLONE_ONE_LINER; manual git clone; clone_info blob instead of repo_clone_path note.
EOT

  specsym_spawn_context_bootstrap = <<-EOT
${local.specsym_spawn_context_header}
Spec-bootstrap command:
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1 SDD_FRAMEWORK=${var.sdd_framework} CHANGE_TYPE=${var.change_type}; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh spec-bootstrap '{{work_root}}' '{{work_root}}/repo' '${var.sdd_framework}' '${var.change_type}'
EOT

  specsym_spawn_context_author_spec = <<-EOT
${local.specsym_spawn_context_header}
Author-spec command (shell scaffold from ticket):
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1 SDD_FRAMEWORK=${var.sdd_framework} CHANGE_TYPE=${var.change_type} FEATURE_ID='<from read_notes issue_or_pr>' ISSUE_TITLE='<from webhook>' ISSUE_BODY='<from webhook>' ISSUE_OR_PR='<issue_or_pr_number>'; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh author-spec '{{work_root}}' '{{work_root}}/repo' '${var.sdd_framework}' '${var.change_type}'
Stdout MUST include author_spec_status= and spec_tasks_path=.
EOT

  specsym_spawn_context_cursor_author = <<-EOT
${local.specsym_spawn_context_header}
Cursor author-spec command (ONE execute_series):
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1 FEATURE_ID='<feature id>' ISSUE_TITLE='<title>' ISSUE_BODY='<body>'; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh cursor-author-spec '{{work_root}}' '{{work_root}}/repo' '<feature_id>' '<title>' '<body>'
Requires CURSOR_API_KEY on runner. Stdout MUST include author_spec_status=ok.
EOT

  specsym_spawn_context_cursor_implement = <<-EOT
${local.specsym_spawn_context_header}
Cursor implement command (ONE execute_series — copy verbatim, set spec_tasks_path from read_notes):
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1 ISSUE_OR_PR='<issue_or_pr_number>'; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh cursor-implement '{{work_root}}' '{{work_root}}/repo' '<spec_tasks_path from notes or tasks.md>' '<issue_or_pr_number>'
Requires CURSOR_API_KEY. Stdout MUST include implement_edit_verified=true and implement_summary=.
FORBIDDEN: custom spawn JSON; manual agent invocations outside this command.
EOT

  specsym_spawn_context_validate = <<-EOT
${local.specsym_spawn_context_header}
Validate command:
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh validate '{{work_root}}' '{{work_root}}/repo' '<pr_number or empty>'
Stdout MUST include module_quality_summary= and ci_status=.
EOT

  specsym_spawn_context_commit_pr = <<-EOT
${local.specsym_spawn_context_header}
Commit-pr command:
  WORK_ROOT='{{work_root}}' REPO_FULL_NAME='<repository_full_name>' ISSUE_OR_PR='<issue_or_pr_number>' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh commit-pr '{{work_root}}' '{{work_root}}/repo' '<repository_default_branch>' '<issue_or_pr_number>'
Stdout MUST include pr_url= and working_branch=.
EOT

  specsym_spawn_context_archive = <<-EOT
${local.specsym_spawn_context_header}
Archive command:
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh archive '{{work_root}}' '{{work_root}}/repo' '${var.sdd_framework}'
EOT

  spawn_contracts_intake_clone = [
    {
      sub_agent_name = "intake-clone-bootstrap-clone"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 300
      goal                = "ABS_WORK_ROOT={{work_root}}. Clone ONLY — max 2 tools: read_notes then ONE ${local.shell_tool_prefix}_execute_series. read_notes repository_clone_url repository_default_branch issue_or_pr_number. Command MUST copy spawn-context Clone line **character-for-character**: WORK_ROOT='{{work_root}}' (absolute path from spawn header — NEVER '$HOME/.wf-*'). Then REPO_CLONE_URL/DEFAULT_BRANCH/ISSUE_OR_PR from notes, then clone-pack.sh clone with NO path arguments. note repo_clone_path repo_head_sha from stdout. On empty execute_series output: retry up to 3× (15s) before clone_blocker=runner_unavailable."
      context             = local.specsym_spawn_context_clone
    },
  ]

  spawn_contracts_repo_bootstrap = [
    {
      sub_agent_name = "repo-sdd-bootstrap-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 300
      goal                = "FIRST tool: ONE execute_series with spawn-context Spec-bootstrap command verbatim. FORBIDDEN: Phase 1/2/3/4 plans, load_skill. note sdd_framework_used from stdout. Stop."
      context             = local.specsym_spawn_context_bootstrap
    },
  ]

  spawn_contracts_author_spec = [
    {
      sub_agent_name = "author-spec-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 10
      max_tool_iterations = 42
      timeout_seconds     = 300
      goal                = "Thin ticket → spec artifacts. read_notes issue_or_pr_number requested_change. FIRST tool: ONE execute_series with spawn-context Author-spec command (set FEATURE_ID/ISSUE_* from notes). note author_spec_status spec_tasks_path spec_artifact_path from stdout. FORBIDDEN: implement code edits."
      context             = local.specsym_spawn_context_author_spec
    },
  ]

  spawn_contracts_author_spec_cursor = [
    {
      sub_agent_name = "author-spec-cursor-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 900
      goal                = "Cursor CLI author-spec ONLY — max 2 tools: read_notes then ONE execute_series with spawn-context Cursor author-spec command verbatim. note author_spec_status spec_tasks_path from stdout. FORBIDDEN: custom agent spawn JSON."
      context             = local.specsym_spawn_context_cursor_author
    },
  ]

  spawn_contracts_implement = [
    {
      sub_agent_name = "implement-spec-feature"
      task_type      = "coding"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 20
      max_tool_iterations = 48
      timeout_seconds     = 900
      goal                = "Implement per tasks.md or openspec/changes/* record. read_notes repo_clone_path (must end with /repo). REQUIRED: shell execute_series edits under repo_clone_path; verify with git diff --quiet or note implement_edit_verified=true. note implement_summary= from real edits only. FORBIDDEN: implement_summary without execute_series file edits; tasks.md path-only prose (trace e22cc371)."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_implement_cursor = [
    {
      sub_agent_name = "implement-cursor-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 1800
      goal                = "Implement via Cursor CLI ONLY — max 2 tools: read_notes (repo_clone_path, spec_tasks_path) then ONE execute_series with spawn-context Cursor implement command verbatim. note implement_edit_verified implement_summary from stdout. FORBIDDEN: plan-only prose without execute_series (trace e22cc371)."
      context             = local.specsym_spawn_context_cursor_implement
    },
  ]

  spawn_contracts_validate = [
    {
      sub_agent_name = "validate-and-test-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 12
      max_tool_iterations = 45
      timeout_seconds     = 600
      goal                = "FIRST tool MUST be execute_series with spawn-context Validate command. note module_quality_summary ci_status from stdout."
      context             = local.specsym_spawn_context_validate
    },
  ]

  spawn_contracts_create_pr = [
    {
      sub_agent_name = "create-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 12
      max_tool_iterations = 45
      timeout_seconds     = 300
      goal                = "If pr_url set in notes, skip. Else ONE execute_series with spawn-context Commit-pr. note pr_url working_branch."
      context             = local.specsym_spawn_context_commit_pr
    },
    {
      sub_agent_name = "create-pr-notify"
      task_type      = "efficiency"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 5
      max_tool_iterations = 42
      timeout_seconds     = 90
      goal                = "Blocked path ONLY. read_notes repository_full_name issue_or_pr_number clone_blocker stage_summary:intake-clone-bootstrap. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Blocker comment command verbatim. note notify_comment_id from stdout. FORBIDDEN: invent gh commands, load_skill, create-pr-runner."
      context             = local.specsym_spawn_context_blocker_notify
    },
  ]

  spawn_contracts_archive = [
    {
      sub_agent_name = "archive-specs-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 300
      goal                = "OpenSpec only. Skip when clone_blocker or create-pr blocked. Else ONE execute_series with spawn-context Archive. note archive result or skipped."
      context             = local.specsym_spawn_context_archive
    },
  ]

  spawn_contracts_update_tracker = [
    {
      sub_agent_name = "update-tracker-notify"
      task_type      = "efficiency"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 120
      goal                = "read_notes pr_url ci_status repository_full_name issue_or_pr_number. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Tracker update command when issue exists. If notify_blocker=issue_not_found, note notify_skipped only. FORBIDDEN: claiming missing tools when shell runner is available."
      context             = local.specsym_spawn_context_tracker_notify
    },
  ]
}
