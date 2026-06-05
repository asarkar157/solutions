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
| `split-domain-analyst` | Escalation + optional open-system enrichment (deterministic scripts own the graph) |
| `cursor-split-executor` | Optional — when `enable_cursor_integration = true` |

## Workflows

| Workflow | Purpose |
|----------|---------|
| `monorepo-services-split-analysis` | Clone → scan → parallel plan prep → optional enrichment → guidance PR |
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

Deterministic analysis lives in `scripts/stage-runner.sh`, `boundary-scan.sh`, `build-coupling-matrix.sh`, `synthesize-split-plan.sh`, `monorepo-cce-scan.sh`, `runtime-deps-provision.sh`, `agents-md-scaffold.sh`, `clone-and-pr.sh`, and `scaffold-services.sh`. Version **20260604.7** — bootstrap B64 and script-pack tarball are set on the Ubuntu integration when you apply this module. After scan, **parallel-plan-prep** runs `synthesize-split-plan.sh` (real Gradle/Go edges → `coupling-matrix.json` + audience-tiered `docs/architecture/*`), `agents-md-scaffold.sh`, and `fetch-repo-context.sh`. Optional **`target_pr_repo`** clones/pushes a fork while `github_repo_url` stays the upstream reference. **`enable_os_enrichment`** (default true) adds advisory LLM prose only — never `depends_on` edits. Clone-and-scan runs **[CCE](https://github.com/appcd-dev/cce)** via [`aios-cce-scripts`](../aios-cce-scripts/). See **[docs/cce-powers.md](docs/cce-powers.md)**.

Clone-and-scan **provisions language runtimes** (OpenJDK, Go, Node via apt — runners have root/sudo) and runs baseline tests from `test_inventory` before analyst stages. Never defer Java with "not available in runner env".

### Script pack version mismatch (`runner_sha256_mismatch`)

If a run fails with `script_pack_error=runner_sha256_mismatch`, the Ubuntu integration’s `MONOSPLIT_SCRIPT_PACK_TARBALL_B64` / bootstrap B64 does not match this module’s `script_pack_version`. That cannot be fixed inside a running workflow.

**Operators (Terraform):** re-apply this module so the Ubuntu integration picks up the current script pack. Compare:

| Item | Value |
|------|--------|
| `workflow_run_id` | from stagerunner header |
| `script_pack_version` | from spawn context (e.g. `20260604.7`) |
| `enable_incremental_guidance_pr` | default `true` — one PR, commits per stage (`[stage:parallel-plan-prep]`, review, enrichment, `final`) |
| Expected SHA-256 | `stage_runner_script_sha256` in spawn context |
| Actual SHA-256 | from runner stderr (`actual=…`) |

**Workflow agents** report the mismatch only — they do not describe integration container lifecycle or Guild infrastructure. After you apply the module, start a new analysis run for the target `github_repo_url`.

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
