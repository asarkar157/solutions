---
layout: page
title: Monorepo services split
permalink: monorepo-services-splitter/
nav_order: 5
---

# Monorepo services split (`aios-agent-monorepo-services-splitter`)

Application monolith → microservices guidance and optional extraction for **Go, Java, JavaScript, and TypeScript** monorepos. The module provisions Guild agents, **two workflows**, evidence checklists, and deterministic Ubuntu script runners that clone the target repo and open PRs back to the **same GitHub repository** (never push to the default branch).

**Module source:** [`modules/aios-agent-monorepo-services-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-monorepo-services-splitter)

**Runnable demo:** [`examples/scenarios/monorepo-services-split`]({{ site.github.repository_url }}/tree/main/examples/scenarios/monorepo-services-split) — `make demo SCENARIO=monorepo-services-split`

---

## When to use it

| Customer situation | Use this module |
|--------------------|-----------------|
| "We have a monolith — how should we split it into services?" | **Analysis workflow** first |
| "We approved a split plan — scaffold `services/<name>/` and open an extract PR" | **Extract workflow** (after analysis) |
| "Split our Terraform state **and** our application code" | Pair with [`aios-agent-db-state-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-db-state-splitter) — IaC grouping vs. application boundaries |

---

## Two workflows (analysis before extract)

The split is intentionally **two phases**. Extract refuses to cold-start without an approved plan.

```mermaid
flowchart LR
  subgraph analysis["monorepo-services-split-analysis"]
    A1[clone-and-boundary-scan] --> A2[analyze-coupling-and-contexts]
    A2 --> A3[synthesize-split-plan]
    A3 --> A4[open-guidance-pr]
    A4 --> A5[final-evidence-gate]
  end

  subgraph extract["monorepo-services-split-extract"]
    E1[load-approved-plan] --> E2{plan-blocked-gate}
    E2 -->|plan missing| E6[extract-evidence-gate]
    E2 -->|plan loaded| E3[scaffold-service-layout]
    E3 --> E4[cursor-refactor-services]
    E4 --> E5[open-extract-pr]
    E5 --> E6
  end

  analysis -->|"guidance PR + service-catalog.yaml"| extract
```

### 1. `monorepo-services-split-analysis`

**Purpose:** Facts before judgment — clone, deterministic boundary scan, DDD-informed synthesis, guidance PR.

**Typical chat prompt:**

```text
Analyze https://github.com/org/monorepo for microservices split — DDD bounded contexts
```

**Stages:**

| Stage | What happens |
|-------|----------------|
| `clone-and-boundary-scan` | Ubuntu runner clones repo, emits `boundary_scan.json`, provisions JDK/Go/Node via apt, runs baseline tests from `test_inventory` |
| `analyze-coupling-and-contexts` | Domain analyst interprets scan facts (bounded contexts, coupling heat) |
| `synthesize-split-plan` | Service catalog, migration phases, per-service test strategy |
| `open-guidance-pr` | Commits `docs/architecture/` artifacts + repo-root [`AGENTS.md`](https://agents.md/) |
| `final-evidence-gate` | Submits analysis evidence checklist |

**Guidance PR artifacts (under `docs/architecture/`):**

- `service-catalog.yaml` — proposed services with rationale
- `bounded-context-map.mermaid`
- `coupling-matrix.json`
- `migration-phases.md`
- Repo-root **`AGENTS.md`** — setup, tests, conventions for IDE agents

### 2. `monorepo-services-split-extract`

**Purpose:** Load an **approved** plan, scaffold `services/<name>/`, optionally delegate refactor to Cursor, open extract PR.

**Typical chat prompt (after analysis):**

```text
Extract services from approved plan at docs/architecture/service-catalog.yaml
```

**Required notes / inputs:**

- `github_repo_url`
- **`plan_artifact_path`** (e.g. `docs/architecture/service-catalog.yaml`) **or** `prior_workflow_run_id` from a completed analysis run

**Plan gate:** If neither plan path nor prior run id exists, `load-approved-plan` sets `blocked:missing_plan_artifact` and `plan-blocked-gate` skips scaffold, Cursor, and extract PR. This is **expected** when someone asks to "break down" a repo but triggers extract instead of analysis.

---

## Agents

| Agent | Role |
|-------|------|
| `monorepo-split-architect` | Coordinator — spawns Ubuntu script runners only; never inline shell on embed stages |
| `split-domain-analyst` | LLM synthesis on `boundary_scan.json` — no clone/shell |
| `cursor-split-executor` | Optional — when `enable_cursor_integration = true` |

---

## Script pack and runners

Deterministic work lives in `scripts/` (version **20260602.8**), delivered via **spawn-context decode command** + **one execute_series** (no LLM `create_files` paste). Ubuntu sidecars are shared — per-run state under `/home/integration/.<workflow_run_id>/` only.

| Script | Stage |
|--------|-------|
| `stage-runner.sh` + `boundary-scan.sh` | Analysis — clone + scan |
| `runtime-deps-provision.sh` | Installs OpenJDK, Go, Node; runs baseline tests |
| `agents-md-scaffold.sh` | Repo-root `AGENTS.md` from scan |
| `scaffold-services.sh` | Extract — validated `services/<name>/` skeletons |
| `clone-and-pr.sh` | Guidance and extract PR bodies from committed diff |

Extract scaffold must set `scaffold_layout_validated=true` before an extract PR is opened.

---

## Unit tests as confidence gates

`boundary_scan.json` includes `test_inventory`, `test_frameworks`, `packages_without_tests`, and `test_confidence_score`. Analysts must not recommend cuts through high-coupling, untested packages without a tests-first strangler phase.

| Language | Gate |
|----------|------|
| Go | `go test ./... -race -count=1`; table-driven `*_test.go` |
| Java | JUnit 5 under `src/test/java`; Gradle/Maven `test` task |
| JS/TS | Vitest/Jest/Mocha from `package.json`; per-package coverage in monorepos |

---

## Terraform wiring

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
  enable_github_webhook                = false # targets analysis workflow when true
}
```

**Requirements:** StackGen provider `>= 0.1.23`, `aios-foundation`, `aios-policies` (`dangerous_ops`), GitHub + Ubuntu integrations.

**Key outputs:** `workflow_names`, `agent_names`, `github_integration_name`, `ubuntu_integration_name`, optional `webhook_id` / `webhook_token`.

---

## SE talk track (5 minutes)

1. Open Guild → find **`monorepo-split-architect`** and the two workflows.
2. Run **`monorepo-services-split-analysis`** with a public monorepo URL.
3. Show **`clone-and-boundary-scan`** — Ubuntu runner, `boundary_scan.json`, runtime provisioning (not ad-hoc chat).
4. Show analyst output — bounded contexts, service catalog, migration phases.
5. Show the **guidance PR** on the same repo. Mention extract only after the customer approves the plan.

Full scenario script: [`examples/scenarios/monorepo-services-split/README.md`]({{ site.github.repository_url }}/blob/main/examples/scenarios/monorepo-services-split/README.md).

---

## Operational checklist

1. Run **`monorepo-services-split-analysis`** on the target repo URL.
2. Review and merge (or approve) the **guidance PR**.
3. Seed notes for extract: `plan_artifact_path` or `prior_workflow_run_id`, plus `github_repo_url`.
4. Run **`monorepo-services-split-extract`**.
5. Verify extract PR includes validated scaffold layout and per-service test stubs.

**Common mistake:** Chat message like "break this repo down" routed to **extract** → blocked at `load-approved-plan`. Re-run with **analysis** first.

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [SE Playbook — monorepo-services-split]({% include doc_url.html path="se-playbook.md" %}) | One-command demo |
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Filter `monorepo`, `microservices`, `ddd` |
| [DB state split module]({{ site.github.repository_url }}/tree/main/modules/aios-agent-db-state-splitter) | Terraform/OpenTofu state grouping (complementary) |
