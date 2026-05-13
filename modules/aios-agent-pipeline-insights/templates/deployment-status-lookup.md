Report deployment status for a repository — succeeded or failed, by environment.

## Steps

1. Resolve the target — accept any of:
   - `repository` + `environment` (e.g. `production`) — most recent deploys.
   - `repository` + `ref` (branch/tag/sha) — deploys for that ref.
   - `repository` only — deploys grouped by environment.
2. Call `GET /repos/{owner}/{repo}/deployments` (filterable by `environment`,
   `ref`, `sha`). Page until you hit `deployments_limit` (default 10) per
   environment.
3. For each deployment, call
   `GET /repos/{owner}/{repo}/deployments/{deployment_id}/statuses`
   and use the **most recent** status as the deployment outcome.
4. For each deployment, capture:
   - `id`, `environment`, `ref`, `sha`, `creator.login`, `created_at`.
   - From the latest status: `state` (`success`, `failure`, `error`,
     `inactive`, `in_progress`, `queued`, `pending`).
   - `log_url`, `environment_url`, `description`.
5. When `state` is `failure` or `error`:
   - If `log_url` points at an Actions run, follow the run and surface the
     failing job + last 50 log lines (re-use the run-status lookup runbook).
   - If `log_url` points at an external system (ArgoCD, Spinnaker), include
     the URL and note that further drill-in must happen there.
6. Summarize per environment:
   ```
   Environment: production
   • Latest deploy: ref=<ref> sha=<short> by @<login> at <UTC> (<relative>)
   • State: <success|failure|...>     • <html_url>
   • Notes: <description trimmed to 200 chars>
   • Recent history (last <N>): <state>, <state>, ...
   ```
