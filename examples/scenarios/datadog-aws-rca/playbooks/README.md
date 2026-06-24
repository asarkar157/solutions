# Datadog playbooks for `datadog-aws-rca`

Markdown playbooks in this folder are **source content** for Datadog Notebooks and Guild RunbookSOP sync via **stackgen-sre-app** discovery.

## aiden-demo service reference

| File | Use |
|------|-----|
| [`aiden-demo-datadog-playbook.md`](./aiden-demo-datadog-playbook.md) | Full service topology, log/trace queries, fault modes, chaos monkey, and agent investigation steps |

### Create a Datadog notebook (US3)

1. Open [Datadog Notebooks](https://us3.datadoghq.com/notebooks) → **New notebook**.
2. Title: **AI SRE Demo — aiden-demo service reference** (or similar).
3. Add **Markdown** cells — paste one major `##` section per cell (Overview, Service topology, each service, Observability queries, Chaos monkey, Investigation playbook, Pause and operations).
4. For query sections, add optional **Timeseries** or **Log** cells with the fenced queries from the markdown file.
5. Save and note the **notebook ID** from the URL (`…/notebook/<ID>/…`).

### Sync into Guild (optional)

1. Run **Discovery** for the Datadog integration in the SRE app → **Available playbooks** lists the notebook ID.
2. Set on the `datadog` Guild integration `env`:

   ```hcl
   runbook_sync_enabled      = "true"
   runbook_sync_notebook_ids = "<notebook-id>"
   ```

3. Run Discovery again — content ingests as RunbookSOP under `{integration_name}-playbooks`.

See [stackgen-sre-app `docs/runbook-sync.md`](https://github.com/appcd-dev/guild-apps/stackgen-sre-app/blob/main/docs/runbook-sync.md).

### Why agents need this

Investigations on `env:demo` alerts need **stable facts**: which service depends on which, which `@error.kind` values map to which faults, how chaos monkey timing works, and which log/trace queries to run first. Without this playbook, agents may treat leaf errors as root cause or chase the wrong GitHub repo when monitor tags are mis-scoped.
