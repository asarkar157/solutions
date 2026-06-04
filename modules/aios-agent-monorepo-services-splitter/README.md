# aios-agent-monorepo-services-splitter

Guild agents and **two workflows** for analyzing Java / Go / JavaScript / TypeScript monorepos, producing DDD-informed split guidance, opening PRs to the **same GitHub repo**, and optionally scaffolding service extractions with Cursor delegation.

## Requirements

- StackGen provider `>= 0.1.25`
- `module.foundation.model_names` and `module.policies.policy_ids.dangerous_ops`
- GitHub + Ubuntu Guild integrations (provisioned via `github_secret_id` or pass `integration_names` / `existing_*`)

## Agents

| Agent | Role |
|-------|------|
| `monorepo-split-architect` | Coordinator — spawns Ubuntu runners only |
| `split-domain-analyst` | LLM synthesis on `boundary_scan.json` |
| `cursor-split-executor` | Optional — when `enable_cursor_integration = true` |

## Workflows

| Workflow | Purpose |
|----------|---------|
| `monorepo-services-split-analysis` | Clone → scan → analyze → guidance PR |
| `monorepo-services-split-extract` | Load plan → plan-blocked-gate → scaffold → optional Cursor → extract PR |

Both workflows set Guild execution metadata:

| Key | Value | Purpose |
|-----|-------|---------|
| `halguard_skip_subagent_task_types` | `terminal_calling` | Skip HalGuard **PreCheck** on Ubuntu script runners (cost control) |
| `terminal_calling_halguard_mode` | `paste_only_minimal_planner` | Paste-only runner discipline — short goals, verbatim decode command, no `load_skill` on embed stages |
| `planner_max_tool_iterations` | `12` | Cap orchestrator tool loops per stage |

PostCheck still runs on runner stdout and architect/analyst synthesis.

## Usage

```hcl
module "monorepo_services_splitter" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-monorepo-services-splitter?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  github_secret_id = module.github_integration.secret_id

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
  }

  enable_cursor_integration            = false
  existing_cursor_mcp_integration_name = "" # required when enable_cursor_integration = true

  enable_github_webhook = false
}
```

## Demo scenario

```bash
make demo SCENARIO=monorepo-services-split
```

See [`examples/scenarios/monorepo-services-split/`](../../examples/scenarios/monorepo-services-split/).

## Script pack

Deterministic analysis lives in `scripts/stage-runner.sh`, `boundary-scan.sh`, `cce-cloud-scan.sh`, `runtime-deps-provision.sh`, `agents-md-scaffold.sh`, `clone-and-pr.sh`, and `scaffold-services.sh`. Version **20260602.14** — bootstrap B64 and script-pack tarball are baked into the Ubuntu **sidecar env** at `tofu apply` (no runtime clone of tooling repos). Clone-and-scan runs **[CCE](https://github.com/appcd-dev/cce)** (`cce` v0.0.4 on the Ubuntu sidecar via `install_tools`) to attach `cloud_entitlements` (AWS/GCP/Azure API usage) into `boundary_scan.json` for unknown-repo reconnaissance. See **[docs/cce-powers.md](docs/cce-powers.md)** for what that adds to split analysis. Spawn context carries a short decode command (~300 chars); runners prepend `export GITHUB_REPO_URL=…` from `read_notes`, then paste decode. Only the **user's target repo** (workflow `github_repo_url`) is cloned for analysis.

Clone-and-scan **provisions language runtimes** (OpenJDK, Go, Node via apt — runners have root/sudo) and runs baseline tests from `test_inventory` before analyst stages. Never defer Java with "not available in runner env".

### Sidecar env drift (`runner_sha256_mismatch`)

If a run fails with `script_pack_error=runner_sha256_mismatch`, the **Ubuntu sidecar env** (`MONOSPLIT_SCRIPT_PACK_TARBALL_B64` / bootstrap B64) does not match this module’s `script_pack_version` at apply time. That is **not** fixed inside a running workflow.

**Workflow agents must not** tell end users to recycle sidecars or re-apply tofu manually. Escalate to the **platform/infra team** that provisions the Ubuntu integration with:

| Item | Value |
|------|--------|
| `workflow_run_id` | from stagerunner header |
| `script_pack_version` | from spawn context (e.g. `20260602.10`) |
| Expected SHA-256 | `stage_runner_script_sha256` in spawn context |
| Actual SHA-256 | from runner stderr (`actual=…`) |

After the sidecar is re-provisioned with matching env, start a **new** `monorepo-services-split-analysis` workflow run (new `workflow_run_id`) for the target `github_repo_url`.

Guidance PRs add repo-root **[AGENTS.md](https://agents.md/)** (setup, tests, conventions from scan + analyst notes) alongside `docs/architecture/`.

## Unit testing confidence gates

Monorepo split decisions use **existing language-specific unit tests** as confidence gates before recommending or extracting services.

### Go

- Table-driven tests with `t.Run` ([Go wiki: TableDrivenTests](https://go.dev/wiki/TableDrivenTests))
- Co-located `*_test.go`; run `go test ./... -race -count=1` before PR
- Coverage baseline: `go test ./... -coverprofile=coverage.out` (use `-coverpkg=./...` when tests span packages)
- Interface-based dependencies for test doubles (no production code without failing tests first)

### Java

- JUnit 5 unit tests under `src/test/java`; Maven Surefire or Gradle `test` task
- Whitebox unit tests at module level; **Testcontainers** reserved for integration at module boundaries ([Gradle JVM testing guide](https://docs.gradle.org/current/userguide/java_testing.html))
- JPMS: separate test modules or Surefire JPMS examples ([Maven Surefire JPMS](https://maven.apache.org/surefire/maven-surefire-plugin/examples/jpms.html))

### JavaScript / TypeScript

- Detect Vitest, Jest, or Mocha from config and `package.json` scripts
- Monorepo: per-package `pnpm test` / `npm test -w <pkg>`; Vitest **projects** for merged coverage ([Vitest projects guide](https://vitest.dev/guide/projects))
- Coverage thresholds during extraction — maintain or improve per-package LCOV

### Cross-cutting (split confidence)

| Layer | Role in decomposition |
|-------|------------------------|
| Unit tests | **Primary gate** — must pass per extracted service before PR |
| Contract tests | Pact / OpenAPI at new boundaries ([Spotify honeycomb](https://engineering.atspotify.com/2018/01/testing-of-microservices)) |
| Integration | Testcontainers sparingly at cut lines |
| E2E | Minimal — critical journeys only |

`boundary_scan.json` exposes `test_inventory`, `test_frameworks`, `packages_without_tests`, and `test_confidence_score` (0–1). Analysts must not recommend cuts through high-coupling, untested packages without a tests-first strangler phase.

## Policies

- `dangerous_ops` from `aios-policies`
- Module-local `monorepo-split-readonly-default` — blocks push to default branch
