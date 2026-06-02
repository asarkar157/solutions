# CCE × AIOS agent integration map

Maps [CCE usage guides](https://github.com/appcd-dev/cce/tree/main/docs/usages) to **AIOS modules** and the Guild integrations that run them.

Shared scripts live in [`modules/aios-cce-scripts/`](../modules/aios-cce-scripts/). Ubuntu sidecars need `cce` in `install_tools` (or script self-install).

Lenses are downloaded from **`https://releases.stackgen.com/cce/lenses/<use-case>/latest/`** (public; see [index.json](https://releases.stackgen.com/cce/lenses/index.json)). Override with `CCE_LENS_CHANNEL` or `CCE_MAPPER_FILE`. Built-in mappers (`change-control`, `cloud-entitlements`, `pre-deploy-iam-review`) skip lens download and use `-filter cloud`.

## Integration patterns

| Pattern | Integrations | CCE role |
|---------|--------------|----------|
| **GitHub + Ubuntu** | Clone repo on Ubuntu; GitHub for PR/issue comments | PR delta, audit scans, regression gates |
| **Linear + GitHub + Ubuntu (+ Cursor)** | Linear ticket → Ubuntu CCE → Cursor implements | Migration / tech-debt lenses |
| **StackGen MCP + GitHub + Ubuntu** | GitHub discovery + CCE facts + MCP appStack | IaC alignment, llm-code-context |
| **Observability + GitHub + Ubuntu** | Alert → clone default repos → CCE scope | incident-scoping, blast-radius |

## Module matrix

| AIOS module | CCE use cases (`CCE_USE_CASE`) | Integrations |
|-------------|-------------------------------|--------------|
| [`aios-agent-monorepo-services-splitter`](../modules/aios-agent-monorepo-services-splitter/) | `cloud-entitlements`, `monorepo-intelligence`, `microservice-decomposition` | GitHub, Ubuntu |
| [`aios-agent-terraform-bot`](../modules/aios-agent-terraform-bot/) | `change-control`, `pre-deploy-iam-review` | GitHub, Ubuntu |
| [`aios-agent-compliance-auditor`](../modules/aios-agent-compliance-auditor/) | `audit-evidence`, `regulatory-scope`, `landing-zone-governance` | GitHub, Ubuntu (optional), AWS |
| [`aios-agent-software-engineering`](../modules/aios-agent-software-engineering/) | `sdk-uplift`, `tech-debt-inventory`, `golden-path-enforcement`, `platform-adoption` | Linear, GitHub, Ubuntu, Cursor |
| [`aios-agent-repo-to-iac`](../modules/aios-agent-repo-to-iac/) | `cloud-entitlements`, `llm-code-context`, `iac-alignment` | GitHub, StackGen MCP, Ubuntu |
| [`aios-agent-db-state-splitter`](../modules/aios-agent-db-state-splitter/) | `iac-alignment`, `cloud-entitlements` (optional app repo) | GitHub, Ubuntu, StackGen MCP |
| [`aios-agent-multitenant-sre-rca`](../modules/aios-agent-multitenant-sre-rca/) | `incident-scoping`, `blast-radius-analysis`, `change-impact-analysis` | Datadog, GitHub, Ubuntu |
| [`aios-agent-predictive-sre`](../modules/aios-agent-predictive-sre/) | `change-impact-analysis`, `incident-scoping` | GitHub, Grafana, AWS, Ubuntu |

## Operator checklist

1. `tofu apply` the agent module with `enable_cce = true` (where variable exists).
2. Recycle Ubuntu sidecar after script/env changes.
3. Set `SKIP_CCE=1` on the integration env to disable scans for a tenant.
4. For custom wrappers (e.g. Prowler), set `CCE_MAPPER_FILE` to `https://releases.stackgen.com/cce/lenses/prowler/latest/prowler.yaml` or a local path.
5. After script changes, bump `cce_pack_version` in `aios-cce-scripts/pack.tf` and re-apply the agent module (new `CCE_PACK_B64`).

## Related

- CCE usage index: [appcd-dev/cce `docs/usages/README.md`](https://github.com/appcd-dev/cce/blob/main/docs/usages/README.md)
- Monorepo splitter detail: [`cce-powers.md`](../modules/aios-agent-monorepo-services-splitter/docs/cce-powers.md)
