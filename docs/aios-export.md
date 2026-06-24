---
layout: page
title: aios-export
permalink: aios-export/
nav_order: 7
parent: Topic guides
---

# aios-export — capture a Guild tenant as Terraform

**Read-only SE utility** that snapshots a StackGen / Guild tenant and emits Terraform HCL plus `terraform import` commands. The killer use case is **capturing an SE-clicked demo into a version-controlled baseline** you hand to the customer or another SE.

> **Not the same as the [Migration guide]({% include doc_url.html path="migration-guide.md" %})** — export captures what exists in the UI; migration refactors monolithic Terraform you already maintain.

Full tool documentation: [`tools/aios-export/README.md`]({{ site.github.repository_url }}/blob/main/tools/aios-export/README.md)

---

## What gets exported today

| Resource kind | Exported? |
|---------------|-----------|
| `sg_agent` | Yes |
| `sg_workflow` | Yes |
| `sg_remote_runner` | Yes |
| Integrations, policies, secrets, schedules, webhooks | **No** (Phase 2 — hand-merge from modules) |

Phase 1 always produces `out/tenant.tf`. Phase 2 (on by default) also emits `out/tenant.modules.tf` with pattern-matched `module` blocks — diff both and commit whichever the customer prefers.

---

## Run

```bash
cd tools/aios-export
STACKGEN_URL="https://main.dev.stackgen.com" \
STACKGEN_TOKEN="$YOUR_PAT" \
./export.sh
```

Optional: `STACKGEN_PROJECT_ID="proj_abc123" ./export.sh`

Outputs in `out/`:

- `tenant-snapshot.json` — machine-readable dump (good for diffs across tenants)
- `tenant.tf` — HCL stubs for agents / workflows / remote runners
- `import.sh` — one `terraform import` line per emitted resource

---

## Adopt into a new root

1. Create a customer directory and copy `out/tenant.tf`.
2. Add `provider.tf` with `provider "sg"` (see [Prerequisites]({% include doc_url.html path="prerequisites.md" %})).
3. `tofu init`
4. `bash out/import.sh`
5. `tofu plan` — should show no changes once integrations and policies are hand-merged.

---

## Related

- [Adopt the repo — Path 2]({% include doc_url.html path="adopt.md" %}#path-2--capture-a-ui-clicked-tenant-poc-handoff)
- [Migration guide]({% include doc_url.html path="migration-guide.md" %}) — refactor existing Terraform, not UI capture
