# Scenario: `repo-to-iac`

## Pitch (read this on the call)

> "Hand me any GitHub URL. Aiden reads the repo, infers the runtime + dependencies + cloud resources, and emits the Terraform that would deploy it on your platform — using the StackGen MCP to keep the output aligned with your conventions."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — minimal set (no Azure / GCP / Langfuse policies)
- `aios-integration-github` — read access to the source repo
- One inline `sg_secret` + `sg_guild_integration` for the **StackGen Consumer MCP** (so the agent can drive StackGen platform tooling)
- `aios-agent-repo-to-iac` — the `repository-iac-architect` agent + two workflows

> For a richer root with toggles (optional MCP wiring, alternative workflow inputs), see [`examples/repo-to-iac/`](../../repo-to-iac/) and [`examples/agentic-infrastructure/`](../../agentic-infrastructure/).

## Run

```bash
make demo SCENARIO=repo-to-iac
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and find the `repository-iac-architect` agent.** "One agent, two workflows — `repository-to-iac` (discovery + synthesis) and `repo-scan-appstack-github-export` (synthesis + push back to GitHub)."
2. **Run the workflow with a public repo** (the `github_repo_url` you set, or any URL the prospect names on the call).
3. **Pause at the discovery stage.** Show how the agent calls the GitHub MCP to enumerate files, dependencies, and entry points before writing any code.
4. **Show the synthesis stage.** The agent uses the StackGen MCP to align the generated IaC with the prospect's existing conventions (modules, providers, naming).
5. **Show the deliverable.** Either the workflow output in Guild, or — for the export workflow — the PR opened against a target repo.

## Reset for the next prospect

```bash
make demo-reset SCENARIO=repo-to-iac
```
