---
name: Scenario request (from solutions engineer)
about: A prospect asked something we do not yet have a one-command demo for. File this so we can ship a scenario.
title: "[scenario] <one-line pitch — what the prospect asked>"
labels: ["scenario-request", "se-feedback"]
assignees: []
---

<!--
This template is for solutions engineers. If you are filing a regular bug
report, use a different template. The goal here is to add a runnable scenario
under examples/scenarios/<name>/ that a future SE can launch with one command.

See docs/se-playbook.md for the existing scenario inventory.
-->

## The conversation

**Prospect industry / size:**
<!-- e.g. mid-market fintech, ~300 engineers -->

**What the prospect actually said:**
<!-- One or two sentences, in their words if possible. This becomes the
README "Pitch" section of the new scenario. -->

**Why none of the existing scenarios fit:**
<!-- e.g. "finops-weekly is too broad; the prospect only cares about idle EC2." -->

## The demo we want

**Modules to wire (best guess — engineering can refine):**
<!-- e.g. aios-foundation, aios-policies, aios-integration-aws,
aios-agent-cost-optimizer with the resource-janitor disabled. -->

**Integrations the prospect already has set up:**
- [ ] AWS (role ARN ready?)
- [ ] Azure
- [ ] GCP
- [ ] GitHub
- [ ] Slack
- [ ] Grafana
- [ ] Other: ___

**Integrations they DON'T have — i.e. the scenario must work without them:**
<!-- This drives whether the scenario can be read-only / dry-run. -->

**Ideal demo length on the call:**
<!-- 3 min / 5 min / 15 min. Drives how many modules we wire. -->

## Talk track (rough)

<!-- 3-5 bullets the SE will read off on the call. Engineering will turn
this into the README's Talk track section. -->

1.
2.
3.

## Acceptance

- [ ] New folder under `examples/scenarios/<name>/` with `main.tf`,
      `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `README.md`
- [ ] Listed in `scripts/demo.sh` `scenario_pitch()` so `make demo-list` shows it
- [ ] Mentioned in `docs/se-playbook.md` "Prospect-question → scenario" table
- [ ] Passes `make fmt-check` + `tofu validate`
- [ ] Reviewed by the scenario owner listed in `CONTRIBUTORS-SE.md`

## Anything else
