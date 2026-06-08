Confirm governed deployment prerequisites, then open a GitHub PR with the generated CloudFormation template.

**Open PR:**
1. Spawn exactly one **open-pr-runner** using the spawn-context **Commit PR command** (Ubuntu sidecar runs `gh` — do **not** call github-integration MCP).
2. The script runs `governed-deployment-check.sh` and emits `governed_deployment_ready=true` or `governed_deployment_blocked=true`.
3. Default PR target: `${target_repository_full_name}` @ `${target_base_branch}`. Override with `github_repo_override` in `requirements_spec.json` when set.
4. Template must exist at `WORK_ROOT/generated/template.yaml` from synthesize-template.
5. Export only `PR_TITLE`, `TEMPLATE_FILE`, `STACK_NAME`, `ENVIRONMENT`, `INTENT` from `requirements_spec.json` — **never `PR_BODY`** (the script renders markdown).
6. Mirror machine-readable tokens from runner stdout: `pr_url=`, `pr_blocker=`, `clone_blocker=`, `template_path=` — **stage output ≤5 lines**.
7. On spawn or runner failure emit: `stage_summary:open-pr=blocked pr_blocker=<reason>` then stop.
8. `note("pr_opened", "true")` when pr_url is set.

Common blockers: `missing_script_pack` (recycle Ubuntu sidecar after `tofu apply`), `missing_template_body`, `clone_blocker=auth_or_network` (GitHub PAT scope).
