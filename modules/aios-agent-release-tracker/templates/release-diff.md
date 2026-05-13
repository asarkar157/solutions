Diff two releases / refs / tags and produce a changelog summary.

## Steps

1. Resolve the inputs — `repository` plus `from_ref` and `to_ref` (tags,
   branches, or SHAs). When the operator only supplies `service_name`,
   resolve the repo via the configured service catalog first.
2. Call `GET /repos/{owner}/{repo}/compare/{from_ref}...{to_ref}`.
3. Capture: `total_commits`, `commits[]` (author, sha, message subject),
   `files[]` (path, additions, deletions), `html_url`.
4. Group commits by:
   - **PR link** — extract `(#NNNN)` from each commit subject; resolve
     PR titles + authors; collapse multiple commits into the parent PR.
   - **Conventional Commit type** — `feat:`, `fix:`, `chore:`, `docs:`,
     `refactor:`, `test:`, `perf:`. Anything unrecognized → `other`.
5. Render Markdown changelog:
   ```
   <repo> <from_ref> → <to_ref>  (<N> commits, <M> PRs)
   • Features:
     - #1234 <title>  by @<login>
   • Fixes:
     - #1230 <title>  by @<login>
   • Other:
     - <subject>  by @<login>  <short_sha>
   <html_url of the compare view>
   ```
