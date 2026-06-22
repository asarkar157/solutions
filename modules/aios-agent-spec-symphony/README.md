# aios-agent-spec-symphony

Stage 5 **spec-driven factory** for StackGen Guild: GitHub factory, plus **Linear two-phase** workflows (`linear-product-spec` → comment, `linear-spec-implement` → Cursor + PR).

## What it does

- **linear-product-spec:** Product Linear ticket → golden-template spec + engineering subgoals → Linear comment (MCP, no runner)
- **linear-spec-implement:** Label `spec-blessed` → fetch spec comment → clone → materialize `specs/` → Cursor CLI → validate → PR → Linear comment
- **spec-driven-feature (legacy):** Full GitHub/Linear monolithic factory on remote runner

## Requirements

- StackGen provider `>= 0.1.25`
- `aios-foundation`, `aios-policies`, `aios-remote-runner`
- `aios-integration-linear` (OAuth) for Linear MCP workflows
- GitHub PAT (`github_token` or `github_secret_id`) for implement/PR path
- Docker on apply host when `build_runner_image = true`

## Quick start

```hcl
module "spec_symphony" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-spec-symphony?ref=main"

  model_names  = module.foundation.model_names
  policy_ids   = {
    dangerous_ops     = module.policies.policy_ids.dangerous_ops
    spec_traceability = module.policies.policy_ids.spec_traceability
  }
  github_token = var.github_token

  sdd_framework = "auto"
  change_type   = "brownfield"

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

See [`examples/scenarios/spec-symphony`](../../examples/scenarios/spec-symphony/).

## Webhooks

| Webhook | Output | Workflow |
|---------|--------|----------|
| GitHub | `github_webhook_trigger_url` | `spec-driven-feature` |
| Linear product spec | `linear_product_spec_webhook_trigger_url` | `linear-product-spec` |
| Linear implement | `linear_spec_implement_webhook_trigger_url` | `linear-spec-implement` |
| Linear (legacy) | `linear_webhook_trigger_url` | `spec-driven-feature` when `enable_legacy_linear_factory_webhook=true` |

Labels: `needs-spec` (product spec), `spec-blessed` (implement). See `templates/sdd-kit-starter/SPEC_SYMPHONY.md`.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sdd_framework` | `auto` | `spec-kit`, `openspec`, or `auto` |
| `change_type` | `brownfield` | SDD Kit preset: greenfield, brownfield, bugfix, refactor, migration |
| `power_pack_refs` | `{}` | Map `stage_id` → Guild `skill_ref` for optional MCP packs |
| `quality_max_iterations` | `2` | `validate-loop-gate` GO_BACK cap (Guild visit cap: keep ≤3; implement visits = 1 + this) |
| `implement_engine` | `shell` | `shell` (Guild LLM + runner) or `cursor_cli` (headless `agent --yolo` on runner) |
| `cursor_api_key` | `""` | Required when `implement_engine=cursor_cli` (or use `cursor_secret_id`) |
| `linear_implement_engine` | `cursor_cli` | Engine for `linear-spec-implement` only |
| `linear_product_spec_label` | `needs-spec` | Gate label for product-spec workflow |
| `linear_implement_label` | `spec-blessed` | Trigger label for implement workflow |
| `enable_linear_product_spec_workflow` | `true` | Deploy linear-product-spec when Linear integration set |
| `enable_linear_implement_workflow` | `true` | Deploy linear-spec-implement when Linear integration set |
| `existing_linear_integration_name` | `""` | Required for Linear workflows (`aios-integration-linear`) |
| `create_remote_runner` | `true` | Register `sg_remote_runner` |
| `build_runner_image` | `true` | `docker build` on apply |

## Runner image

Base: `ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main`  
Adds: Node 22, `specify-cli` (uv), `openspec` (npm), script pack at `$HOME/.spec-symphony/pack/<version>/`.

After apply, run `remote_runner_docker_run_command` or `remote_runner_cli_start_command_with_secrets` from outputs.

## SDD Kit starter

Shipped under `templates/sdd-kit-starter/` and copied into target repos by `spec-bootstrap.sh`:

- `constitution.md`, change-type presets, agent prompts
- `.github/workflows/sdd-spec-linkage.yml`, PR template
- `SPEC_SYMPHONY.md` repo contract

## Tests

```bash
cd modules/aios-agent-spec-symphony/tests
chmod +x *.sh
./workflow_structure_test.sh
./script_integration_test.sh
```

## Troubleshooting

### `implement` exceeded visit cap (5)

Guild allows at most **5 visits per stage**. Common causes:

1. **`validate-and-test` wrongly deployed as `loop_stage`** (0ms step, `Loop stage "validate-and-test": GO_BACK` in execution export) **in addition to** `validate-loop-gate` — doubles implement loops. Terraform HCL must keep validate on an **agent** binding only; if state still shows `action_type = "loop_stage"` on `validate-and-test`, run:

   ```bash
   tofu apply -replace='module.spec_symphony.sg_workflow.spec_driven_feature'
   ```

2. **`validate-loop-gate` exit_condition** must be `output_matches_regex` so `module_quality_summary=PASS|BLOCKED` exits the loop (BLOCKED no longer needs a separate gate).

3. Keep `quality_max_iterations` ≤ 3 (default `2`): implement visits ≈ `1 + quality_max_iterations`.

## Explicitly not included

- Ubuntu / Cursor integrations
- `run_workflow` on agents
- Linear poll dispatcher
