---
name: guild-solutions-aiden-deployer
description: Use when Codex needs to use the local Guild-Solutions Terraform/OpenTofu module repository as a framework to deploy, update, or configure Aiden/Guild agent workflows in StackGen. Covers selecting/composing a Terraform root, resolving a workspace/project UUID from a human workspace name, wiring provider project_id, preserving existing tenant resources and state, planning safely, and applying additive workflow deployments. The only user-provided inputs should be StackGen URL, StackGen PAT token, and workspace name; infer the workspace UUID before using Terraform.
---

# Guild Solutions Aiden Deployer

## Core Contract

Use `/Users/arunav/Documents/GitHub/Guild-Solutions` as the module framework unless the user gives another clone path.

Ask the user only for:

- StackGen URL
- StackGen PAT token
- Workspace name

Do not ask for a workspace UUID. Resolve it from the workspace name before planning.

Do not delete or replace existing Aiden/Guild resources unless the user explicitly requests that destructive change. Treat every deployment as additive by default.

## Workspace UUID Lookup

Prefer the bundled helper:

```bash
python3 skills/guild-solutions-aiden-deployer/scripts/resolve_workspace_uuid.py \
  --stackgen-url "$STACKGEN_URL" \
  --stackgen-token "$STACKGEN_TOKEN" \
  --workspace-name "$WORKSPACE_NAME"
```

The helper performs a read-only Terraform query using `data.sg_organizations` and `data.sg_me`, then returns matching workspace names and UUIDs as JSON.

Selection rules:

1. If there is exactly one case-insensitive exact match, use its `id` as `stackgen_project_id` / provider `project_id`.
2. If there are multiple exact matches or only fuzzy matches, show the matches and ask the user to choose by name. Do not guess.
3. If there are no matches, stop and report that the token cannot see a workspace with that name.

Never pass the human workspace name where Terraform expects `project_id`. Some modules also accept a human `stackgen_project_name`; only use that field when the module documentation says the MCP tool requires a human-readable project name.

## Deployment Workflow

1. **Read repo instructions first.** Open `AGENTS.md`, the target module `variables.tf`, `outputs.tf`, and README when present.
2. **Find existing state.** Search for Terraform roots and local states:

   ```bash
   rg --files -g 'main.tf' -g 'terraform.tfstate' -g '*.tfvars'
   tofu -chdir=<candidate-root> state list
   ```

   Prefer extending the root that already targets the resolved workspace UUID and owns related resources. If no suitable root exists, create a new scenario/root under `examples/scenarios/<purpose>/`.

3. **Use existing modules.** Compose with modules under `modules/`; do not hand-roll `sg_*` resources unless there is no module for the desired workflow.
4. **Wire the provider.** Every root must configure:

   ```hcl
   provider "sg" {
     stackgen_url      = var.stackgen_url
     stackgen_token    = var.stackgen_token
     project_id        = var.stackgen_project_id
     adopt_on_conflict = true
   }
   ```

   Use the resolved UUID for `var.stackgen_project_id`.

5. **Respect layers.** Foundation/policies first, integrations next, agents/workflows last.
6. **Prefer existing workspace assets.** If a module can accept `existing_*_integration_name` or an existing secret ID and the root already manages or outputs one, reuse it. Do not ask the user for GitHub/AWS/Slack/etc. credentials; if a requested module cannot deploy without extra external credentials and none already exist in state/config, report the exact blocker.
7. **Make names collision-safe.** Use `name_suffix` or module-specific naming variables when deploying multiple copies into one workspace.
8. **Plan before apply.** Run `tofu fmt`, `tofu init`, then `tofu plan -out=tfplan`. Inspect the plan. Abort if it contains deletes, unexpected replacements, provider/project drift, or changes outside the requested workflows.
9. **Apply only a clean additive plan.** Use the saved plan:

   ```bash
   tofu apply tfplan
   ```

10. **Report outputs.** Include workflow names, agent names, webhook endpoints/tokens as sensitive notes when appropriate, remote runner install commands when created, and any runner or integration prerequisites.

## Safe Plan Checks

After `tofu plan -out=tfplan`, inspect JSON:

```bash
tofu show -json tfplan \
  | jq -r '.resource_changes[] | [.address, (.change.actions | join(","))] | @tsv'
```

Proceed only when actions are expected and additive, usually `create`, `update`, or `no-op`.

Abort and explain if any action includes:

- `delete`
- `delete,create`
- large unrelated `update`s
- resources from an unrelated scenario root
- provider/project UUID changes

## Common Module Choices

- Terraform module author/reviewer workflows: `modules/aios-agent-terraform-bot`
- Terraform state monolith demo splitter: `modules/aios-agent-tfstate-monolith-splitter`
- Advanced multi-cloud state/AppStack splitter: `modules/aios-agent-db-state-splitter`
- Repo-to-IaC: `modules/aios-agent-repo-to-iac`
- Application monorepo splitting: `modules/aios-agent-monorepo-services-splitter`
- Remote runner registration: `modules/aios-remote-runner`
- Shared policies: `modules/aios-policies`
- Foundation/models/secrets: `modules/aios-foundation`

Always verify the current variable contract in the target module before wiring it. Some README snippets can lag behind `variables.tf`.

## Handling Existing Resources

Use `adopt_on_conflict = true` on the provider for additive deployments into an already-used workspace.

If Terraform state already has the desired resource in another root:

- Prefer using that existing root for related additions.
- Do not recreate the same named agent/workflow in a second root.
- If migration/import is needed, stop and propose the import/move commands rather than applying.

If the live workspace has unmanaged resources with the same names:

- Prefer module suffixes to avoid collisions, or
- Use Terraform import only after the user confirms adoption.

## Validation

Run at least:

```bash
tofu fmt
tofu validate
```

When workflow structure changes in this repository, also run:

```bash
make verify-workflow-stage-bindings
```

For db-state-splitter template changes:

```bash
make validate-db-state-split-templates
```

## Output Style

Summarize:

- Resolved workspace name and UUID
- Terraform root used
- Modules added or updated
- Plan summary with assurance that no deletes were present
- Apply result and key outputs
- Any blocked prerequisites that could not be satisfied from existing state/config
