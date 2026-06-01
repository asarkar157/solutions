# Normalize Slack SRE request

Parse `/aiden` or thread text into `normalized_request` JSON.

## Inputs

- Slack event payload (channel, user, text, thread_ts).
- Optional GitLab project paths: ${gitlab_default_project_paths}

## Steps

1. Classify intent (`npm_failure`, `deploy_failure`, `pipeline_failure`, `argocd_sync`, `general_sre`).
2. Extract GitLab pipeline/MR references and Argo CD app hints.
3. Capture environment label for ${private_saas_environment_label}.
4. Redact secrets before emitting JSON.
