---
layout: page
title: Adopt the repo
permalink: adopt/
nav_order: 4
---

# Adopt the solutions repo

This page is the **single entry point** for solutions engineers adopting this repository. Pick one path below and follow the numbered steps — you do not need to read everything on the site first.

> **New here?** Gather credentials: [Prerequisites]({% include doc_url.html path="prerequisites.md" %}). Unfamiliar terms: [Glossary]({% include doc_url.html path="glossary.md" %}).

---

## Should I use this repo at all?

| Situation | Use this repo? | Why |
|-----------|----------------|-----|
| **Pre-sales demo:** you have 15–30 min on Zoom and need a working Aiden in front of a prospect. | **Yes — run a scenario** | One `make demo SCENARIO=…` gets you to "first agent reply" faster than clicking through the UI. |
| **PoC handoff:** you configured a tenant in the UI and the customer wants it in code. | **Yes — capture it** | Use [aios-export]({% include doc_url.html path="aios-export.md" %}) to snapshot the tenant to HCL the customer can own. |
| **Multi-env rollout:** the customer wants dev / staging / prod tenants from the same baseline. | **Yes — clone the scenario** | Each scenario is parameterized by `stackgen_url` / `stackgen_token`; same root, different `terraform.tfvars`. |
| **Discovery call, no Aiden yet:** the prospect wants to see what an "agent" even is. | **No — open Guild UI** | Modules add latency you do not need. Come back here once they nod at the concept. |
| **Internal eng explaining the platform to another eng team.** | **Maybe — link [Architecture]({% include doc_url.html path="architecture.md" %})** | The diagram doc is faster than reading 15 module READMEs. |

---

## Path 1 — Demo Aiden today (pre-sales)

**Best when:** you have a prospect on Zoom and need a working agent in under 30 minutes.

1. **Check credentials** — run `make demo-doctor` from the repo root. It reports missing StackGen URL/token, LLM keys, or integration secrets before the prospect sees a stack trace.
2. **Pick a scenario** — open the [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) prospect-question table, or browse the [scenario index]({{ site.github.repository_url }}/blob/main/examples/scenarios/README.md).
3. **Run the demo** — `make demo SCENARIO=<name>` (wrapper over `tofu init && apply` in `examples/scenarios/<name>/`).
4. **Walk the talk track** — each scenario README has a **Talk track** section (5 bullets). Open the Guild URL from `tofu output`.
5. **Reset between calls** — `make demo-reset SCENARIO=<name>` so the next prospect starts clean.

**Full stack fallback:** if the prospect needs every integration wired, point at [`examples/complete/`]({{ site.github.repository_url }}/tree/main/examples/complete/) — but lead with a single scenario first.

---

## Path 2 — Capture a UI-clicked tenant (PoC handoff)

**Best when:** you or the customer configured agents in the Guild UI and now need version-controlled Terraform.

1. **Export the tenant** — follow [aios-export]({% include doc_url.html path="aios-export.md" %}) (`tools/aios-export/export.sh` with `STACKGEN_URL` and `STACKGEN_TOKEN`).
2. **Review outputs** — `out/tenant-snapshot.json` (diff-friendly), `out/tenant.tf` (raw `sg_*` HCL), `out/import.sh` (import commands).
3. **Create a customer root** — copy `tenant.tf`, add `provider.tf`, run `tofu init`.
4. **Import existing resources** — `bash out/import.sh`, then `tofu plan`.
5. **Hand-merge gaps** — Phase 1 does **not** export integrations, policies, schedules, secrets, or webhooks. Add those from module READMEs or keep them in the UI until Phase 2 capture ships.
6. **Optional module rewrite** — compare `out/tenant.modules.tf` (Phase 2 pattern-matching) against raw `tenant.tf` and commit whichever representation the customer prefers.

---

## Path 3 — Compose modules in your own Terraform root

**Best when:** you are building or extending a customer stack from `aios-*` modules (not clicking through the UI).

1. **Prerequisites** — [credentials checklist]({% include doc_url.html path="prerequisites.md" %}) (StackGen PAT, provider registry token, LLM keys).
2. **Minimal pattern** — [Onboarding step 4]({% include doc_url.html path="onboarding/04-use-a-module.md" %}): foundation → policies → agent, with `provider "sg"` in your root.
3. **Plan and apply** — `tofu init`, `tofu plan`, `tofu apply`; verify agents appear in the Guild UI.
4. **Pick modules by customer shape** — [Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %}) or [Module Catalog]({% include doc_url.html path="module-catalog.md" %}).
5. **Full reference** — [`examples/complete/`]({{ site.github.repository_url }}/tree/main/examples/complete/) wires every layer; CI validates it via `make validate`.

**Contributor path:** if you are changing modules in this repo, continue with [Onboarding steps 2–5]({% include doc_url.html path="onboarding/index.md" %}) for local CI parity.

---

## Migration paths (which guide do I need?)

Two different "migrations" exist — pick the row that matches your starting point:

| Starting point | Guide | When to use |
|----------------|-------|-------------|
| Tenant built in **Guild UI** (SE-clicked demo) | [aios-export]({% include doc_url.html path="aios-export.md" %}) | PoC handoff, customer wants IaC snapshot + import |
| Existing **monolithic** `terraform/guild/main.tf` | [Migration guide]({% include doc_url.html path="migration-guide.md" %}) | Refactor inline `sg_*` into composable `aios-*` modules |
| **Fresh empty tenant** | Path 1 (scenario) or Path 3 (onboarding) above | Greenfield demo or greenfield module composition |

These guides are complementary, not interchangeable. Export captures what exists; the migration guide restructures Terraform you already maintain.

---

## Production checklist

Before handing a root to a customer for prod:

- **Pin module `ref=`** — use a tag or commit SHA, not `ref=main`, in every `module` block `source`.
- **Separate environments** — same root, different `terraform.tfvars` (or workspaces) per dev / staging / prod tenant.
- **Secrets via env vars** — prefer `TF_VAR_stackgen_token` and `TF_VAR_*` over committing `terraform.tfvars`.
- **Enterprise rollout** — see [Enterprise deployment profile]({% include doc_url.html path="enterprise-deployment-profile.md" %}) for webhooks, skills sync, LLM egress, and milestone checklist.

---

## Where to get help

- **Scenario missing for a prospect question?** — [SE feedback]({% include doc_url.html path="se-feedback.md" %}) and the `scenario-request` issue template; the [scenario-author agent]({{ site.github.repository_url }}/tree/main/modules/aios-agent-scenario-author) triages within minutes.
- **Module variable questions?** — each module's `variables.tf` and `README.md` under `modules/<name>/`.
- **IDE / agent composition rules?** — [`AGENTS.md`]({{ site.github.repository_url }}/blob/main/AGENTS.md) at the repo root.
