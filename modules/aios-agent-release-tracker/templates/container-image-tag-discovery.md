List the most recent OCI image tags for a service.

## Steps

1. Resolve the image reference:
   - If the operator supplied `image` (e.g. `ghcr.io/appcd-dev/payments`),
     use it directly.
   - Otherwise, derive from `service_name` using the configured
     `image_namespace` template (e.g. `ghcr.io/{{org}}/{{service}}`).
2. Choose the source registry API:
   - **GHCR**: `GET /users/{owner}/packages/container/{package}/versions`
     (or `/orgs/{owner}/packages/container/{package}/versions`).
   - **ECR / GAR / Docker Hub**: out of scope for the GitHub integration;
     refuse and tell the operator to use the cloud integration directly.
3. Capture for each version: `name` (tag list per version), `created_at`,
   `updated_at`, `metadata.container.tags` (semver / immutable digest tags),
   `html_url`, and the visibility (public / private).
4. Sort by `created_at` desc and keep `tag_limit` (default 10) entries.
5. Deduplicate digests where a single image is published under multiple
   tags (e.g. `v1.2.3`, `1.2.3`, `latest`).
6. Render Markdown:
   ```
   Image: <ref>
   • Latest tag: <vX.Y.Z>  pushed <UTC> (<relative>)  digest <sha:...>
   • Recent tags:
     - <tag>  <UTC>  <digest>
     - <tag>  <UTC>  <digest>
   ```
