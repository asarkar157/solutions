# Inspect containers (Docker / npm)

Diagnostics via Ubuntu MCP when enabled; read-only.

## Steps

1. For npm failures: inspect lockfile, registry reachability, and `npm audit` summary (no install).
2. For image errors: `docker pull` dry-run or manifest inspect when docker CLI is available.
3. Correlate image tag with GitLab CI job artifacts.
4. Emit `container_inspection` JSON with proposed fixes as text only.
