Parse the developer request or webhook payload into `WORK_ROOT/requirements_spec.json` via the **parse-requirements-runner** spawn contract.

**Default workspace:** `${workspace_id}` (${workspace_source_type}) → `${workspace_repository}` @ `${workspace_base_branch}`, path `${workspace_path_prefix}`.

1. Spawn exactly one **parse-requirements-runner** using spawn context **Parse intent once** (pipe parent input on stdin) or **Parse requirements command** after writing `WORK_ROOT/stage_input.raw`.
2. Mirror stdout only: `requirements_parsed=`, `requirements_blocked=`, `correlation_id=`, `orchestration_source=`, `stack_name=`, `confirm_deploy=`.
3. **Stage output ≤6 lines** — structured key=value only. FORBIDDEN: `load_skill`, `read_notes`, catalog discovery, prose summaries. Parent must not re-spawn runner on success.
4. When `requirements_blocked=true`, emit that token only — gates match structured output, not `blocked:missing_*` prose.
5. Downstream stages read `WORK_ROOT/requirements_spec.json` — never replay full predecessor markdown.
