Preview infrastructure changes via CloudFormation change set (never execute).

1. Spawn exactly one **preview-changes-runner** using the spawn-context **Change-set preview command**.
2. Read `stack_name` from `WORK_ROOT/requirements_spec.json` and template from `WORK_ROOT/generated/template.yaml`.
3. Mirror stdout: `change_set_preview_documented=`, optional `change_set_preview_blocked=`.
4. **Stage output ≤5 lines**. FORBIDDEN: `open-pr-runner`, AWS MCP, `github-integration`, `load_skill`, `read_notes`.

Parent stage may add a PR comment separately when `pr_url` is in workflow context.
