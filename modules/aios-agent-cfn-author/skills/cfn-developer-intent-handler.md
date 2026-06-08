---
name: cfn-developer-intent-handler
description: Parse natural-language or webhook infrastructure intent into a structured requirements spec.
---

# CFN developer intent handler

Use when the workflow stage needs to turn chat or webhook JSON into `requirements_spec`.

1. Read `intent`, `request`, or `description` from the prompt or webhook body.
2. Copy optional fields: `stack_name`, `environment`, `workspace_id`, `correlation_id`, `confirm_deploy`.
3. Resolve repository and template path from workspace defaults when not overridden.
4. Emit `blocked:missing_intent` when no actionable infrastructure change is described.
