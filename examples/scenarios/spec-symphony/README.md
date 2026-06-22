# Scenario: spec-symphony

Stage 5 **SDD factory** demo — GitHub (+ optional Linear) webhooks, remote runner, Spec Kit / OpenSpec.

## Quick start (recommended)

From the **solutions repo root**:

```bash
export STACKGEN_URL=https://ai.dev.stackgen.com
export STACKGEN_TOKEN=...
export GITHUB_TOKEN=...       # repo scope
export OPENAI_API_KEY=...     # or ANTHROPIC / GEMINI

make demo-doctor SCENARIO=spec-symphony
make demo SCENARIO=spec-symphony
```

## Manual apply

```bash
cd examples/scenarios/spec-symphony
cp terraform.tfvars.example terraform.tfvars
# Edit target_repository_full_name → your fork of a small app repo
tofu init && tofu apply
```

## End-to-end test

**Start the remote runner before triggering the webhook.** If the runner is offline, `execute_series` fails instantly with `context canceled` and the workflow wastes tokens on empty stages.

```bash
cd examples/scenarios/spec-symphony

# 1. Print test guide
./scripts/demo.sh

# 2. Start aiden-runner (after apply) — keep this terminal running
./scripts/start-runner.sh --run

# 3. In another terminal: fire webhook (creates GitHub issue + starts workflow)
./scripts/trigger-webhook.sh --from-tofu-output \
  --create-github-issue \
  --repo YOUR_ORG/YOUR_REPO \
  --title "CORE-101 Add /health endpoint" \
  --sdd-framework auto \
  --change-type brownfield
```

Watch the Guild UI for workflow **`spec-driven-feature`**.

## Outputs

| Output | Use |
|--------|-----|
| `github_webhook_trigger_url` | GitHub integration / manual curl |
| `linear_webhook_trigger_url` | Linear workspace webhook URL |
| `remote_runner_docker_run_command` | `scripts/start-runner.sh` |
| `workflow_name` | Guild workflow to inspect |
| `runner_docker_image` | Image built during apply |

## Prerequisites

- StackGen provider `>= 0.1.25`
- **Docker** on the apply host when `build_runner_image = true` (default)
- GitHub PAT with `repo` scope (runner `git`/`gh` + optional issue create)
- A **target repo** you can push branches to (fork recommended)

## Test matrix

| ID | `sdd_framework` | `change_type` | What to expect |
|----|-------------------|---------------|----------------|
| T1 | `spec-kit` | `greenfield` | `.specify/` + `specs/` scaffold |
| T2 | `openspec` | `brownfield` | `openspec/changes/<id>/` |
| T3 | `auto` | `bugfix` | Framework auto-detected from repo |

## Talk track (5 min)

1. **Problem:** Spec Kit / OpenSpec are Stage 4 — humans advance each phase.
2. **Factory:** GitHub → `spec-driven-feature`; Linear → two-phase (`linear-product-spec` then `linear-spec-implement`).
3. **Show:** Product ticket gets spec comment; after `spec-blessed`, runner + Cursor implement and open PR.
4. **Governance:** `ci-spec-linkage.sh` blocks code-only PRs; constitution in SDD Kit starter.
5. **Linear:** Wire `linear_product_spec_webhook_trigger_url` (create) and `linear_spec_implement_webhook_trigger_url` (update/label).

## Linear two-phase test

1. Apply with `linear_credential_provider_id` and `cursor_api_key` (for implement workflow).
2. Linear webhook **Issue create** → `linear_product_spec_webhook_trigger_url`.
3. Ticket with label `needs-spec` + product requirements.
4. Review comment; add `spec-blessed` and `repo: owner/name` in body.
5. Linear webhook **Issue update** → `linear_spec_implement_webhook_trigger_url`; start runner.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `context canceled` on first stage | Start `./scripts/start-runner.sh --run` **before** webhook; confirm runner online in Guild |
| `execute_series` returns instantly, empty notes | Runner not connected — restart container after `tofu apply` |
| Workflow runs 4+ min then errors on `retry-*` agent | Re-apply module (orchestration SOP + gates); never spawn ad-hoc subagent names |
| `docker build` fails on apply | Set `build_runner_image = false` if image already exists locally |
| Clone fails on runner | Verify `GITHUB_TOKEN` synced to runner; restart container after apply |
| Webhook 403 | Re-copy `github_webhook_trigger_url` after re-apply |
| Workflow stuck | Confirm runner online in Guild → Remote runners |

## Module docs

- [`modules/aios-agent-spec-symphony/README.md`](../../../modules/aios-agent-spec-symphony/README.md)
- [`docs/spec-driven-orchestration.md`](../../../docs/spec-driven-orchestration.md)
