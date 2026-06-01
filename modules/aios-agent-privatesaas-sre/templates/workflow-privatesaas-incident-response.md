PrivateSaaS SRE incident response: FireHydrant + private Grafana ingest, GCP investigation, internal tooling enrichment, multi-source runbook matching, RCA synthesis, and prod-safe action recommendations.

- **Environment**: ${private_saas_environment_label}
- **GCP project**: ${gcp_project_id}
- **LLM**: Customer Bifrost gateway${bifrost_gateway_comment}

Stages: ingest filter → normalize → Grafana signals → GCP → FireHydrant enrich → internal tooling → runbook match → RCA → safety gate → recommend actions (document-only in prod).
