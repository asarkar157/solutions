# Scenario: `jenkins-sre-demo`

## Pitch (read this on the call)

> "Aiden connects directly to your Jenkins controller as a Remote MCP. Operators can list jobs, inspect run history, read logs, and trigger pipelines using natural language. To ensure secure operations, we enforce policy-as-code: routine staging builds execute instantly, but any production-bound triggers are automatically intercepted by a Human-in-the-Loop approval gate. Let me show you."

## What this scenario wires

- `aios-foundation` — LLM secrets + a Guild-registered model
- `aios-policies` — `dangerous_ops` guardrail (other policies are turned off to keep the demo small)
- `jenkins-trigger-safety-gate` — a custom OPA policy defining production pipelines as sensitive
- `aios-integration-jenkins` — creates the Jenkins integration and vault credential
- `aios-integration-slack` — *optional* (only created if `slack_bot_token` is set)
- `sg_agent.jenkins_sre` — the custom Jenkins-SRE agent itself

## Run

```bash
# Option A: from the repo root, one command
make demo SCENARIO=jenkins-sre-demo

# Option B: directly in this folder
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars     # fill in stackgen_token, jenkins_base_url, jenkins_username, jenkins_token
tofu init
tofu apply
```

`tofu apply` finishes in ~2–3 minutes against an empty Guild tenant. The `next_steps` output prints the Guild URL, the agent name, and a starter prompt — paste that prompt into Guild chat to begin the demo.

## Talk track (5 bullets, ~5 minutes)

1. **Show the agent in Guild.** Point at the registered agent (`jenkins-sre-agent` or the custom name). Explain: "this is our SRE assistant, equipped with the Jenkins integration tools."
2. **List pipelines.** Type: *"Show me the available pipelines in Jenkins."* Point out that Aiden invokes the `cicd_list_pipelines` tool, presenting the list of jobs clearly.
3. **Inspect build history.** Ask: *"What is the status of the last few builds for the staging-smoke-tests pipeline?"* Aiden runs `cicd_list_builds` and shows statuses, runtimes, and links.
4. **Trigger a safe pipeline.** Ask: *"Trigger the staging-smoke-tests pipeline."* Aiden triggers the pipeline via `cicd_trigger_pipeline`. Since this is a safe, non-prod environment, the build executes immediately without prompts.
5. **Demonstrate the Security Gate.** Ask: *"Trigger the production-deploy pipeline."* This matches our custom Rego policy rules. Show that the tool call is blocked, displaying a **Human-in-the-Loop (HITL) approval prompt** in the chat window. Explain: *"Our policy-as-code ensures that even if an agent determines a prod deploy is needed, it cannot bypass human authorization."*

## Reset for the next prospect

```bash
make demo-reset SCENARIO=jenkins-sre-demo
```

Tears down and re-applies. Useful between back-to-back calls.
