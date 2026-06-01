# GitOps SRE incident response

PrivateSaaS GitOps incident workflow: Slack intake → GitLab/Argo CD/AWS/SonarQube investigation → RCA → bounded remediation notify.

Environment label: **${private_saas_environment_label}**

Triggers: `/aiden` Slack commands, deploy/npm/pipeline failure threads, optional `slack-gitops-sre` webhook.
