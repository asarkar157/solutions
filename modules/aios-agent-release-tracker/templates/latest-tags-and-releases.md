Fetch the latest tags / GitHub Releases for one or more repositories.

## Steps

1. Resolve the target — accept any of:
   - `repository` (`owner/name`) — single repo.
   - `repositories` (list of `owner/name`) — batch.
   - `service_name` — translate via the operator-configured service catalog
     (`service_catalog` workflow input) to one or more repositories.
2. For each repository, call:
   - `GET /repos/{owner}/{repo}/tags?per_page={{tag_limit}}` (default 10)
   - `GET /repos/{owner}/{repo}/releases?per_page={{release_limit}}` (default 5)
3. Filter by semver class — separate stable (`vX.Y.Z`) from pre-release
   (`-rc`, `-beta`, `-alpha`, `-dev`). Honor `include_prereleases` (default
   `false`).
4. For each release, capture: `name`, `tag_name`, `published_at`,
   `prerelease`, `draft`, `author.login`, `html_url`, and the first 500
   characters of `body` (release notes).
5. For each tag, also fetch `GET /repos/{owner}/{repo}/git/tags/{sha}` if
   the tag is annotated, to capture the tagger and message.
6. Render Markdown grouped by repository:
   ```
   <owner>/<repo>
   • Latest stable: <vX.Y.Z>  released <UTC> (<relative>)  by @<login>
     <release_html_url>
   • Latest prerelease: <vX.Y.Z-rc.N>  released <UTC> (<relative>)
   • Recent tags: <tag1>, <tag2>, <tag3>
   ```
