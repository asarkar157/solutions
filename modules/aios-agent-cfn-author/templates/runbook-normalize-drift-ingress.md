Normalize drift management ingress from webhook JSON, scheduled prompt, or chat.

## Default workspace

- workspace_id: `${workspace_id}`
- source_type: `${workspace_source_type}`
- repository: `${workspace_repository}` (branch `${workspace_base_branch}`, path `${workspace_path_prefix}`)
- primary_iac: `${workspace_primary_iac}`
- self_healing_allowed: ${workspace_self_healing_allowed}

## Steps

1. Parse payload for `drifted_stacks` (array of objects with `stack_name`, optional `region`, `environment`, `workspace_id`).
2. When `drifted_stacks` is present, flatten to comma-separated `stack_names` and distinct `region` list for downstream scope parsing.
3. Resolve `workspace_id` from payload or default `${workspace_id}`; `note("workspace_id", …)`.
4. When `correlation_id` is present, `note("correlation_id", …)`.
5. When `confirm_deploy` is `"false"`, set `note("confirm_deploy", "false")` — reconcile PR path only, no stack execution.
6. When payload lacks stack names and regions, pass through for chat/scheduled scope parsing (do not emit `blocked:missing_drift_scope` here).
7. Emit `drift_ingress_normalized: "true"`.

## Guardrails

- Read-only — no AWS mutations in this stage.
- Preserve raw payload in notes for audit.
