# `tools/aios-export` — Aiden tenant → HCL exporter

**Read-only.** Captures a snapshot of a StackGen / Guild tenant and emits
Terraform HCL plus `terraform import` commands so a customer (or another SE)
can adopt the same tenant configuration into IaC.

The killer use case is **not** disaster recovery — it is **capturing an
SE-clicked demo into a sharable, version-controlled baseline**, then handing
it to the customer or to another SE who needs the same starting point.

## Status

- **Phase 1 (default emit):** raw `sg_agent` / `sg_workflow` /
  `sg_remote_runner` HCL plus a JSON snapshot. Always produced as
  `out/tenant.tf`. Useful immediately. Caveats below.
- **Phase 2 (opt-in, on by default in `export.sh`):** module pattern-matching.
  The exporter parses every `modules/aios-agent-*/main.tf` for canonical agent
  + workflow names; groups of snapshot resources that match those names get
  rewritten as `module "sre_agents" { source = ".../aios-agent-sre" }` etc.
  Phase 2 output is emitted as `out/tenant.modules.tf` so the operator can
  diff Phase 1 vs Phase 2 and commit whichever representation they prefer.

## What gets exported today

| Resource kind        | Exported? | Source data            |
|----------------------|-----------|------------------------|
| `sg_agent`           | yes       | `data.sg_agents`       |
| `sg_workflow`        | yes       | `data.sg_workflows`    |
| `sg_remote_runner`   | yes       | `data.sg_remote_runners` |
| `sg_guild_integration` | **no**  | provider has no list data source for this — Phase 2 will add a manual capture step |
| `sg_policy` / `sg_policy_bundle` | **no** | same — Phase 2 |
| `sg_secret`          | **no**    | values are deliberately not exposed by the provider; hand-merge from Vault |
| `sg_agent_schedule`  | **no**    | not currently a data source — Phase 2 |
| `sg_webhook`         | **no**    | not currently a data source — Phase 2 |

> The exporter is honest about what it captures. The `out/tenant.tf` it
> produces will refuse to apply cleanly without integrations and policies
> in place — the file header tells you exactly that.

## Run

```bash
# From this directory:
STACKGEN_URL="https://main.dev.stackgen.com"   \
STACKGEN_TOKEN="$YOUR_PAT"                    \
./export.sh
```

Optional scoping:

```bash
STACKGEN_PROJECT_ID="proj_abc123" ./export.sh
```

After the run, `out/` contains:

- `tenant-snapshot.json` — machine-readable dump (good for diffs across customers).
- `tenant.tf` — HCL stubs for agents / workflows / remote runners.
- `import.sh` — one `terraform import` line per emitted resource.

## Adopt the exported HCL into a new root

```bash
mkdir customer-aiden && cd customer-aiden
cp /path/to/solutions/tools/aios-export/out/tenant.tf .
cat > provider.tf <<'EOF'
terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}
provider "sg" {
  stackgen_url   = "..."
  stackgen_token = "..."
}
EOF
tofu init
bash /path/to/solutions/tools/aios-export/out/import.sh
tofu plan      # should show 'no changes' if integrations / policies were hand-merged
```

## Sharing exports across SEs

The `tenant-snapshot.json` is the canonical artifact for sharing — it is
deterministic given a tenant, so two SEs can diff their tenants by diffing
JSON. `tenant.tf` is the human-readable representation of the same data.

## Limitations

- Provider data sources are read-only and **computed-only** for most
  attributes. The emitted HCL deliberately omits anything that does not
  round-trip cleanly — that is why each emitted resource has a `# Import:`
  comment. Run the import first, then `plan`, and Terraform will tell you
  about any drift.
- Phase 1 does not capture integrations, policies, schedules, secrets, or
  webhooks (the provider does not expose them as data sources). Phase 2 will
  add a manual capture step that prompts the operator to paste those.
- Diary entries (`sg_agent_diaries`) are intentionally skipped — Phase 1 is
  about configuration, not history.

## Feedback

This tool ships under `tools/` and not `modules/` because it is an SE
utility, not a customer-facing module. Open a `scenario-request` issue
([template](../../.github/ISSUE_TEMPLATE/scenario-request.md)) for
enhancements, or ping the owners listed in
[`CONTRIBUTORS-SE.md`](../../CONTRIBUTORS-SE.md).
