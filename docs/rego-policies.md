---
layout: page
title: Writing Rego policies
permalink: rego-policies/
nav_order: 19
---

# Writing Rego policies

For **solution engineers** governing StackGen agents and tools: policies in this repository are **[Open Policy Agent (OPA)](https://www.openpolicyagent.org/)** rules written in **Rego**. You ship them with Terraform or OpenTofu using the StackGen provider’s [`sg_policy`](https://appcd-dev.github.io/terraform-provider-stackgen/resources/policy.html) resource.

## What the policy is deciding

Think of each evaluation as answering one question for a **single moment** in the agent’s work: *“Given who this is, what they are trying to do right now, and any facts we attached to the policy, should we allow it, block it, or pause for human approval?”*

The platform hands your Rego rules a **compact factsheet** (the `input` value in OPA). Your policy reads that factsheet and sets outcomes such as **`allow`**, **`approval_required`** / **`intervene`** (for human-in-the-loop), plus optional **reason** text people can read in logs or UI.

The factsheet is assembled in **stackgen-aios** from the tool call and related metadata—the shape is defined in code as `buildOPAInput` in [`internal/policy/opa/evaluator.go`](https://github.com/appcd-dev/stackgen-aios/blob/main/internal/policy/opa/evaluator.go) (search for `buildOPAInput` in that file if the link moves).

## What appears on the factsheet (field by field)

| Piece | Plain meaning |
|--------|-----------------|
| **`agent`** | Which agent is acting: internal id, display name, and optional **tags** you configured (for example “production” or team name). |
| **`timestamp`** | When the check ran (UTC, RFC3339 string). Bundled policies parse it with **`time.parse_rfc3339_ns`** plus **`time.weekday`** / **`time.clock`** for business-hours and off-hours rules; **`data-risk-pii`** also compares it to **`time.now_ns()`** for stale-input and clock-skew checks. |
| **`tool`** | The **name** of the tool the agent wants to use, plus **`arguments`**: the structured parameters for that call (always present as an object, even if empty). |
| **`reason`** | When the agent supplied a short justification for the action, it appears here so policies can insist on explanations for sensitive tools. |
| **`environment`** | Present when the request is tied to a specific **owner** in the platform (shown as `owner_id`). Lets you scope rules to a customer or workload boundary. |
| **`skill`** | Present when the call is associated with a **loaded skill** the agent is using. Includes identity and **trust** metadata so you can treat approved skills differently from experimental ones. |
| **`policy_data`** | Optional JSON **you** store on the policy in the platform. Same content every time that policy runs—ideal for allowlists, tier names, or any stable configuration your Rego should read. |
| **`context`** | **Not** emitted by the default **`buildOPAInput`** factsheet in current stackgen-aios builds. If you need situational metadata (data classification, freeze flags, blast-radius hints), put it under **`policy_data`** or derive it from **`tool`**, **`agent`**, and **`reason`**. |

Beyond the rows above, **`buildOPAInput`** may omit optional blocks entirely. If you need fields the evaluator does not send yet, add them under **`policy_data`** or derive them in Rego from **`tool`**, **`agent`**, and **`reason`**.

**Note on some `.rego` examples in this repo:** Rules that reference **`input.approver`** or **`input.principal`** are **patterns** for human-in-the-loop flows; wire those paths only if your stack populates them. Bundled policies in this repository use the default factsheet fields **`tool`**, **`agent`**, **`reason`**, and **`timestamp`** (where time-based logic applies); use **`policy_data`** for customer-specific extensions.

## Example JSON (copy into the OPA Playground)

These match the **`input`** document OPA receives (same structure as `buildOPAInput` produces).

- **[Typical tool call]({{ site.github.repository_url }}/blob/main/docs/samples/policy-evaluation-input.json)** — agent, time, tool + arguments, reason, and owner scope.
- **[With skill and `policy_data`]({{ site.github.repository_url }}/blob/main/docs/samples/policy-evaluation-input-extended.json)** — adds optional **skill** block and **`policy_data`** (example nested `context` under `policy_data` for allowlist-style config; use **`input.policy_data.context`** in Rego if you choose that shape).
- **[Top-level `context`]({{ site.github.repository_url }}/blob/main/docs/samples/policy-evaluation-input-context.json)** — **legacy / illustrative** sample only; current default evaluation input does not include a top-level **`context`** key. Prefer **`policy_data`** for custom metadata your Rego can read as **`input.policy_data.…`**.

## Try policies in the browser

Use the **[OPA Rego Playground](https://play.openpolicyagent.org/)** to edit Rego and **Input** side by side.

1. Open [play.openpolicyagent.org](https://play.openpolicyagent.org/).
2. Put your policy in the editor. Files in this repo use **`package policy`** at the top.
3. Paste one of the sample JSON objects into **Input** (that object is the entire `input` document).
4. Run **Evaluate** to see whether `allow`, `approval_required`, etc. behave as you expect.

For language reference, see the official **[Rego policy language](https://www.openpolicyagent.org/docs/latest/policy-language/)** guide.

## Authoring policies in this repository

- **Examples to learn from:** [`modules/aios-policies/policies/`]({{ site.github.repository_url }}/blob/main/modules/aios-policies/policies/) and per-module folders such as [`modules/aios-agent-aws-sre/policies/`]({{ site.github.repository_url }}/blob/main/modules/aios-agent-aws-sre/policies/).
- **Local checks:** Install **OPA** as in [Step 2 — Your machine]({% include doc_url.html path="onboarding/02-your-machine.md" %}), then run **`make opa-check`** and **`make opa-fmt`** ([Step 3 — Run checks]({% include doc_url.html path="onboarding/03-run-checks.md" %})).
- **One file at a time:** `make opa-check` validates each **`.rego` file on its own**, similar to how standalone policies are uploaded.

## Related onboarding

- [Policies (Rego) — repository layout and CI]({% include doc_url.html path="onboarding/05-go-deeper.md" anchor="policies-rego" %})
