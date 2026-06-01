# Inspect Argo CD

Read-only Argo CD application health and sync analysis.

## Hints

- Application map: ${argocd_application_hints}
- Environment: ${private_saas_environment_label}

## Steps

1. Resolve Application name from request or hints map.
2. Get sync status, health, recent events, and revision vs GitLab commit.
3. Flag OutOfSync, Degraded, or repeated sync failures.
4. Emit `argocd_inspection` JSON (no sync actions).
