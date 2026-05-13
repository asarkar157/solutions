Report who merged a PR (or batch of recent PRs) and when.

## Steps

1. Resolve the target — accept any of:
   - `repository` + `pull_number` — single PR detail.
   - `repository` + `merged_after` (ISO timestamp) — recent merges.
   - `repository` + `branch` — latest merges into that branch.
2. Call `GET /repos/{owner}/{repo}/pulls/{pull_number}` for a single PR.
   For batch lookups, query
   `GET /repos/{owner}/{repo}/pulls?state=closed&base=<branch>&sort=updated&direction=desc`
   and filter to `merged_at != null`.
3. Capture the **merge metadata**:
   - `merged_by.login` — who clicked the button (or the bot service).
   - `merged_at` — UTC timestamp.
   - `merge_commit_sha`.
   - Detect merge mode: squash (single commit on base ahead of PR head),
     rebase (PR commits replayed on base), or merge commit (when
     `merge_commit_sha` parents include both base and head).
4. Capture the **change scope**:
   - `additions`, `deletions`, `changed_files`.
   - File list via `GET /repos/{owner}/{repo}/pulls/{pull_number}/files`.
5. Capture **review state**:
   - Authors, reviewers, approvers, change-requesters.
   - `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews`.
6. Capture **linked work**:
   - Closing references (`Fixes #123`, `Closes ENG-1234`) parsed from PR
     body and merge commit message.
   - `Co-authored-by` and `Signed-off-by` trailers from the merge commit.
7. Render Markdown:
   ```
   PR #<n> — <title>
   • Author: @<login>     • Merged by: @<login> at <UTC> (<relative>)
   • Mode: <squash|merge|rebase>     • SHA: <short>
   • Changes: +<add> / -<del> across <files> files
   • Reviewers: <approved>, <pending>
   • Closes: <issue / ticket links>
   • <html_url>
   ```
