# AI-DLC project layout (spec-symphony seed)

This repository uses [AWS AI-DLC](https://github.com/awslabs/aidlc-workflows) rules fetched by spec-symphony at apply time (`aidlc_rules_version` on the module).

## Artifact directory

All AI-DLC workflow artifacts live under `aidlc-docs/<feature-id>/`:

| File | Phase | Purpose |
|------|-------|---------|
| `inception.md` | Inception | WHAT/WHY — requirements, user stories, units of work, Open Questions |
| `construction.md` | Construction | HOW — component design, **task checklist** (implement stage reads this) |
| `operations.md` | Operations | Deploy, monitoring, rollout notes (optional/future) |

## Vendored rules

- `.aidlc-rule-details/` — detailed stage rules from awslabs/aidlc-workflows
- `AGENTS.md` or `.cursor/rules/ai-dlc-workflow.mdc` — core workflow entry point

## Invocation

Start work with: **"Using AI-DLC, ..."** in agent chat.

## Human-in-the-loop

Agent proposes; humans approve via PR review and label gates (`spec-blessed` on Linear).
