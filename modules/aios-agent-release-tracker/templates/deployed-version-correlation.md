Correlate "what version is deployed in `<env>`?" by combining GitHub deployments
and (optionally) Kubernetes manifest references.

## Steps

1. Resolve the target — `service_name` (mapped via the catalog) or
   `repository`, plus an `environment` (e.g. `production`, `staging`).
2. Pull the most recent **deployment** for that environment via
   `GET /repos/{owner}/{repo}/deployments?environment=<env>` (latest first,
   `per_page = 1`). Capture `ref`, `sha`, `creator.login`, `created_at`.
3. Pull its latest **deployment_status** via
   `GET /repos/{owner}/{repo}/deployments/{id}/statuses` (latest first,
   `per_page = 1`); record `state`, `environment_url`, `log_url`.
4. **Reverse-resolve the version label** from the deployed `sha`:
   - `GET /repos/{owner}/{repo}/git/refs/tags` and find any tag pointing at
     the `sha` (or its merge-base when squash-merge was used).
   - If no tag matches, fall back to "deployed sha `<short>` from branch
     `<ref>`; nearest tag is `<vX.Y.Z>` (Δ +N commits)" using
     `GET /repos/{owner}/{repo}/compare/<tag>...<sha>`.
5. **Optional manifest cross-check** — when
   `manifest_repo` + `manifest_path` are supplied (e.g. ArgoCD Application
   YAML, Kustomize overlay, Helm values):
   - `GET /repos/{owner}/{manifest_repo}/contents/{manifest_path}`
   - Extract the `image:` reference; compare its tag with the version
     resolved in step 4 and report any drift.
6. Render Markdown:
   ```
   Service: <service> — Environment: <env>
   • Deployed: <vX.Y.Z>  (sha <short>)  by @<login> at <UTC> (<relative>)
   • Deployment status: <success|failure|in_progress>  <log_url>
   • Manifest in <manifest_repo>:<manifest_path>:
     image=<ref>:<tag>  (drift: <none|<diff>>)
   ```
