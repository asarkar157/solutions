# SPEC_SYMPHONY.md — Guild factory contract

## Labels / triggers (Linear two-phase)

| Label | Workflow | Purpose |
|-------|----------|---------|
| `needs-spec` | `linear-product-spec` | Product ticket → golden spec + subgoals → Linear comment |
| `spec-blessed` | `linear-spec-implement` | Blessed spec → Cursor implement → PR |
| `spec-symphony` | `spec-driven-feature` | Legacy monolithic factory (optional) |

## GitHub

- Label: `spec-symphony` (optional gate on legacy factory)

## Variables

- `sdd_framework`: `spec-kit` | `openspec` | `ai-dlc` | `auto`
- `change_type`: `greenfield` | `brownfield` | `bugfix` | `refactor` | `migration`

## Linear product ticket body

Include GitHub repo for implement phase:

```
repo: owner/name
```

## Validate profile

Default: npm lint+test, go test, cargo test, or pytest when detected.

## PR requirements

PR description must link `specs/<id>/`, `openspec/changes/<id>/`, or `aidlc-docs/<id>/`.
