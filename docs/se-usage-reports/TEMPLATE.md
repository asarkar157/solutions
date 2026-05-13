---
layout: page
title: "Usage report — YYYY-MM"
permalink: se-usage-reports/TEMPLATE/
nav_exclude: true
---

<!--
Copy this file to YYYY-MM.md (e.g. 2026-05.md), update the front matter
(title, permalink), fill in the sections below, and open a PR. Keep it short —
the bullet count, not the prose, is what matters.

The "Decisions for next month" section is the one that must not be empty.
-->

# Usage report — &lt;Month YYYY&gt;

**Compiled by:** &lt;engineer&gt; &nbsp; **Reviewed by:** &lt;list of SEs who left comments on the PR&gt;

## At a glance

- Total `make demo` invocations: &lt;n&gt;
- Distinct SEs running scenarios: &lt;n&gt;
- Prospect calls where a scenario was used live (SE-reported): &lt;n&gt;
- Scenario requests opened / closed / open at end of month: &lt;n / n / n&gt;
- `tools/aios-export/` runs: &lt;n&gt;

## Scenarios by usage

| Scenario | Demos | Prospects | Notable wins | Notable falls-flat |
|----------|-------|-----------|--------------|--------------------|
| `aws-sre-demo` | &lt;n&gt; | &lt;n&gt; | | |
| `finops-weekly` | &lt;n&gt; | &lt;n&gt; | | |
| `pipeline-insights` | &lt;n&gt; | &lt;n&gt; | | |
| `incident-triage` | &lt;n&gt; | &lt;n&gt; | | |
| `repo-to-iac` | &lt;n&gt; | &lt;n&gt; | | |
| `clean-tenant-reset` | &lt;n&gt; | &lt;n&gt; | | |

## What landed

- &lt;Bullet — which talk-track moments actually moved a prospect.&gt;

## What did not

- &lt;Bullet — scenarios started but abandoned mid-call; why.&gt;

## New scenario requests

- &lt;#issue — one-line summary.&gt;

## UI-export tool

- &lt;Tenants exported, common failures, missing data sources we hit.&gt;

## Decisions for next month

- &lt;Concrete commitments. e.g. "ship X scenario", "kill Y scenario", "add Z field to scenario-request template".&gt;
