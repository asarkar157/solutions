---
layout: page
title: SE interview prep
permalink: se-interview-prep/
nav_order: 95
nav_exclude: true
---

# Solutions team interview — prep & script

**Why this page exists.** Recent feedback from the solutions team was: *"I'm not really sure how this is useful for solutions engineers… you should talk to us next time before doing all this."* This page is the prep doc for the 30-minute interview that will steer the rest of the work. It is **not** end-user documentation — it lives in `docs/` only so it ships with the repo and the SE rework workstreams can cite it.

**Goal.** Replace assumptions about how SEs use this repo with first-hand evidence, then commit to a scenario shortlist + demo UX before any more building happens. The prompts are deliberately narrow because each one maps to a decision the SE rework plan still has open.

## Logistics

- **Length.** 30 minutes. Hard stop at 25 if we are running long — leave 5 minutes to confirm the next two scenarios we will ship and the cadence (see [closing](#closing)).
- **Attendees.** 2–3 SEs (mix of pre-sales and PoC), the engineer driving the rework, optional PM.
- **Format.** One-on-many call, recorded with consent. Notes captured into [`docs/se-feedback.md`]({% include doc_url.html path="se-feedback.md" %}) afterwards (see [SE outreach loop]({% include doc_url.html path="se-feedback.md" %})).
- **Pre-read for the SEs (send 24h ahead).** One paragraph:
  > "We have a Terraform modules repo at `appcd-dev/solutions` that wires up Aiden / Guild. Your last feedback was that it reads like backup / DR plumbing. Before we change anything, we want 30 min to hear what you would actually use, when, and what would unblock you in a demo. Two questions in particular: which two pre-sales scenarios should we ship first, and how do you want to launch them (Makefile target vs script vs UI)."

## Question script

Pick the questions that matter; do not run all of them. Each question is paired with the **decision it unblocks** so it is obvious when an answer is enough.

### A. Current workflow (5 min — sets the baseline)

1. Walk us through your most recent prospect demo. What did you click in Guild, in what order?
   - *Unblocks: which agents / workflows belong in the "first 5 minutes" scenarios.*
2. When you reset / re-demo for the next prospect, what do you do today? (Manual delete? New tenant?)
   - *Unblocks: whether `scenarios/clean-tenant-reset` is real or wishful thinking.*
3. How long does it take you from "prospect on Zoom" to "first agent reply in Guild"?
   - *Unblocks: target time budget for `make demo` (anything we ship must be faster than this).*

### B. Pain points (5 min — kill the wrong solutions)

4. What is the **single** thing that most often slows you down in a demo? (Credential setup? Choosing models? Persona writing? Integration auth?)
   - *Unblocks: whether the bottleneck is HCL ergonomics, doc clarity, or something else entirely.*
5. Have you ever wanted to share a working Guild configuration with another SE? How did you do it?
   - *Unblocks: the UI-export tool's actual value (vs the assumed DR value).*
6. When a prospect asks "can I have this in code?" — what do you say today?
   - *Unblocks: whether modules are blocking sales or just absent from the conversation.*

### C. Scenario picks (10 min — the most important section)

Show this list and ask SEs to **rank 1–7** and tell us which two to ship first:

- `aws-sre-demo` — incident triage on a connected AWS account
- `finops-weekly` — cost optimizer + resource janitor, weekly cron, Slack summary
- `pipeline-insights` — read-only GitHub CI / deployment intelligence (no prod creds)
- `incident-triage` — Grafana alert → cloud-routed RCA → Slack
- `repo-to-iac` — paste a GitHub URL, get IaC out
- `clean-tenant-reset` — wipe to a known baseline between demos
- *Other (write-in)*

7. Which two would you actually run on Monday morning?
8. For each of those: what is the **prospect question** that scenario answers? (We will use this as the README "Pitch" line.)
9. What integrations does the typical prospect *not yet have set up* during the demo? (i.e. which scenarios must work with mocked / dry-run credentials.)

### D. Demo UX (5 min — the launcher question)

10. Would you rather type `make demo SCENARIO=aws-sre-demo` or `./stackgen-demo.sh aws-sre-demo` or click something in Guild?
    - *Unblocks: whether Workstream C ships as a Makefile target or a standalone script.*
11. Pre-flight: do you want `make demo-doctor` to fail loudly if `STACKGEN_TOKEN` etc. are missing, or to prompt for them interactively?
12. After `apply`, what do you want printed? (Guild URLs? Agent names? A pre-filled chat starter prompt?)

### E. UI-export tool (5 min — confirms or kills Workstream D)

13. If a tool could read your current Guild tenant and spit out the equivalent HCL, would you use it?
    - *If "no" → de-prioritize Workstream D. If "yes" → continue.*
14. Would you use it (a) to share configs across SEs, (b) to hand off PoC → prod, (c) only for customer DR — or all three?
    - *Unblocks: phase-1 vs phase-2 priority.*
15. Should it emit raw `sg_*` resources or try to pattern-match into modules?

### Closing (5 min — concrete commitments)

- "Based on this, we will ship **X** and **Y** first. Sound right?"
- "We will hold a 30-min office hour every **&lt;weekday&gt;**. Will you show up?"
- "Who owns reviewing scenario PRs from the SE side?" → captured in `CONTRIBUTORS-SE.md`.

## After the call

1. Summarize answers into [`docs/se-feedback.md`]({% include doc_url.html path="se-feedback.md" %}) under a dated heading.
2. Open one tracking issue per scenario the SEs picked, using the [scenario request template]({{ site.github.repository_url }}/issues/new?template=scenario-request.md).
3. Update the rework plan's "Open questions" section with the concrete answers.
4. Schedule the recurring office hour on the team calendar before the meeting ends — it is the easiest commitment to lose.

## Anti-patterns to avoid in the interview

- **Pitching the rework plan.** Ask, do not present. The plan is a hypothesis; the call is to falsify it.
- **Defending the existing docs.** If an SE has not used a page, that page does not exist. Note it and move on.
- **Promising every scenario.** The plan has us shipping two scenarios in week 1 and three in week 2 — over-promising in the call is how this loop fails again.
