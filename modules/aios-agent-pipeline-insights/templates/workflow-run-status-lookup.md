Look up the current CI/CD status for a repository (or a single ref / PR).

## Steps

1. Resolve the target — accept any of:
   - `repository` (`owner/name`) — show latest run per workflow.
   - `repository` + `branch` — show latest run per workflow on that branch.
   - `repository` + `pull_number` — show check runs on the PR head SHA.
   - `repository` + `commit_sha` — show check runs for that SHA.
2. Call `GET /repos/{owner}/{repo}/actions/runs` (or
   `GET /repos/{owner}/{repo}/commits/{sha}/check-runs` for SHA / PR head).
3. For each workflow / check, capture:
   - `name`, `status`, `conclusion`, `run_number`, `event`,
   - `actor.login`, `created_at`, `updated_at`, `run_attempt`,
   - `html_url` (always include).
4. For any run with `conclusion in (failure, timed_out, cancelled)`:
   - `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` to list jobs.
   - For the first failing job, fetch the last 50 log lines of the failing
     step via `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`.
5. Render a Markdown table grouped by workflow:
   `workflow | status | conclusion | run # | actor | started | duration | url`
6. Append a "Failure context" section for each failed run with the failing
   step name and trimmed log excerpt.
