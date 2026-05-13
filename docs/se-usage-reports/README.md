---
layout: page
title: SE usage reports
permalink: se-usage-reports/
nav_order: 6
---

# SE scenario usage reports

A short report at the end of each month: which scenarios got demoed, what worked, what got rewritten, what we wish we had. Engineering maintains the directory; SEs review during office hours. The point is to close the loop — if a scenario is never used, we kill it; if a request comes up repeatedly, we promote it from "issue" to "shipped scenario".

## Cadence

- **First Wednesday of each month**, the engineering lead drafts the report for the previous month using [`TEMPLATE.md`](TEMPLATE.md) and opens it as a PR.
- The PR sits open for **5 business days**; SEs comment with usage data they have.
- After review, merge. The report becomes the historical record.

## Past reports

<!--
Add new rows at the top as reports merge.
Filename format: YYYY-MM.md (e.g. 2026-05.md).
-->

| Month | Report | Highlights |
|-------|--------|------------|
| _none yet — first report lands after the kickoff interview_ | | |

## Why this exists

The original feedback that started the SE rework was *"this is more useful for customers when they get their aiden setup ready"* — i.e. solutions engineers did not see how the repo helped them in pre-sales. The usage report is the metric we use to falsify that perception over time. If three months in, the reports show that pre-sales SEs are not running `make demo`, we have not actually fixed the problem and need to rethink.

## What each report should answer

1. **Demos run**: number of `make demo SCENARIO=...` invocations across the team, by scenario.
2. **Prospects shown**: rough count (SE-reported) of prospect calls where a scenario was used live.
3. **What landed**: which talk-track bullets actually moved the prospect.
4. **What did not**: scenarios that were started but abandoned mid-call.
5. **Scenario requests**: GitHub issues opened, closed, still open.
6. **UI-export usage**: how many times `tools/aios-export/` got run, against which tenants.
7. **Decisions for next month**: what we will change as a result.
