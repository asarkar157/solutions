---
name: guild-solutions-aiden-deployer
description: Use when asked to initialize, import, capture, or bring an existing StackGen Aiden/Guild workspace into Terraform/OpenTofu, or deploy/update its workflows using Guild-Solutions modules. Requests such as "initialize the workspace" or "import the current workspace" trigger live inventory, TFstate synthesis, matching IaC generation, and zero-diff verification. Resolve workspace UUIDs from names. Capture the entire workspace by default; narrow capture only when explicitly requested. Works with any coding agent or IDE.
---

# Guild Solutions Aiden Deployer

## Initialization and Import Triggers

When the user asks to initialize, import, capture, or bring an existing workspace under Terraform management in a StackGen/Aiden/Guild context, execute the same workspace baseline job. Match the user's intent, not just an exact phrase. Examples include:

- "Initialize the workspace", "initialize my Aiden workspace", or "initialise the workspace".
- "Import the current workspace", "import my existing workspace", or "import this workspace into Terraform".
- "Capture the workspace as IaC", "generate Terraform for what's already there", or "bring the current workspace under Terraform management".

For "current", "this", or "my" workspace, use the workspace already established in the task context. If no unambiguous workspace is established, ask for its name and resolve its UUID; never guess from the PAT's visible workspaces. These trigger rules apply to capturing a live Aiden/Guild workspace; follow any explicit request for a narrower operation, such as importing one named resource or importing a supplied file.

Execute:

1. Collect any missing StackGen URL, PAT, and workspace name, then resolve the workspace UUID.
2. Inventory the entire workspace unless the user explicitly scopes IaC capture to specific components.
3. Synthesize accurate TFstate through supported imports or a verified exporter, preserving existing state ownership.
4. Generate matching Terraform IaC from the captured state and live configuration.
5. Verify coverage and a normal, refresh-enabled zero-diff plan, then hand off the state, IaC, coverage manifest, and verification evidence.

Read and follow [references/workspace-baseline.md](references/workspace-baseline.md) for this job. Workspace initialization/import is complete only when its coverage and zero-diff gates pass; otherwise report the specific blocker and partial artifacts. Running `tofu init` / `terraform init`, or importing resources into state without generating matching IaC and verifying it, does not fulfill the request.

Initialization/import by itself ends with the baseline handoff. Continue to deployment only if the user also requested deployment changes. Repeated initialization/import reconciles and refreshes the existing baseline, filling capture gaps without resetting state, duplicating resource ownership, or overwriting user-authored IaC.

## Core Contract

Use [appcd-dev/solutions](https://github.com/appcd-dev/solutions) as the module framework, from the user's supplied clone or a suitable clone in the current environment. When this skill is loaded from the repository, prefer that enclosing clone. Verify contracts against the selected clone and record the revision used. Preserve uncommitted work; if newer tools are needed, use an isolated checkout of the selected revision rather than replacing the user's checkout.

This skill requires no particular agent, IDE, or agent-specific API. Resolve bundled paths relative to the directory containing this `SKILL.md`. Examples use `tofu`; use `terraform` if that is the available engine and keep the same engine throughout a baseline/deployment.

For an actual workspace operation, ask for missing connection inputs using these labels:

```text
StackGen URL: ___
StackGen PAT: ___
Workspace name: ___
```

Reuse inputs already supplied in the task or available through the environment's credential mechanism. Request the PAT through secure input when available. Do not request credentials merely to edit this skill or explain its workflow.

Do not ask for a workspace UUID; resolve it from the name. Do not request GitHub/AWS/Slack/etc. credentials; reuse existing workspace integrations and secrets, or report the exact blocker. Clarifying an ambiguous workspace or an explicitly requested scope is allowed.

Pass the PAT through `STACKGEN_TOKEN` or `TF_VAR_stackgen_token`; never commit or echo it, embed it in generated HCL, or put it in command-line arguments. State, snapshots, and saved plans may contain secrets; keep them in restricted storage outside version control and redact reports.

Before modifying an existing workspace, establish this baseline in order:

1. Inventory the entire workspace, unless the user explicitly limits IaC capture to named components.
2. Synthesize accurate Terraform state from live resources using provider-supported imports or a verified provider-aware exporter, preserving existing ownership.
3. Reverse engineer Terraform IaC matching that state and the live workspace.
4. Prove complete capture and a normal, refresh-enabled zero-diff plan.
5. Only then implement and plan the requested deployment changes.

A request to add one workflow does **not** implicitly limit baseline capture to that workflow. Never silently omit resources because they are unrelated, difficult to import, or unsupported by a helper. Do not delete or replace existing resources unless the user explicitly requests that destructive change. Deployments are additive by default.

## Use the Repository's Tools and Guidance

Read [references/repository-integration.md](references/repository-integration.md) for the operation being performed. It maps the repository's MCP tools, API guidance, authoring skills, and deployment checks to this skill. These are ordinary repository files and optional tools, not a dependency on a particular IDE.

- **Capture:** Use the Aiden MCP server's read tools when available, or documented read-only HTTP APIs, to supplement `tools/aios-export`. Follow pagination and verify workspace scoping. Raw API snapshots are discovery evidence, not managed TFstate.
- **New solutions:** Read `.cursor/skills/build-aios-solution/SKILL.md` and its relevant references before choosing modules; use `author-aios-module-scenario` when creating new reusable packages. Preserve live names during capture; authoring guidance about generic customer-neutral names applies to new reusable artifacts.
- **Deployment completion:** Use integration/reachability and skill-publishing guidance for the changed modules. Inspect whether skill bodies are owned by `sg_skill` or an external skill source/sync job. A no-op Terraform plan alone does not prove runtime readiness.
- **Troubleshooting:** Use agent-silence and incremental bring-up guidance only for a requested diagnosis or authorized deployment/testing task. Repository examples involving replacement, stage trimming, restarts, or workflow triggers do not authorize those actions during initialization/import.

## Workspace UUID Lookup

Use the bundled helper, with the PAT supplied through the environment:

```bash
# SKILL_DIR is the actual directory containing this SKILL.md.
python3 "$SKILL_DIR/scripts/resolve_workspace_uuid.py" \
  --stackgen-url "$STACKGEN_URL" \
  --workspace-name "$WORKSPACE_NAME"
```

The helper queries `data.sg_organizations` and `data.sg_me`, then returns matching workspace names and UUIDs as JSON. Its temporary root contains only data sources; its `apply` records lookup results locally without changing live resources. It uses the reviewed repository constraint `>= 0.1.33, != 0.1.35, != 0.1.36, < 0.2.0`; deployment roots must also satisfy their selected modules' constraints and lockfiles.

Selection rules:

1. If there is exactly one case-insensitive exact match, use its `id` as `stackgen_project_id` / provider `project_id`.
2. If there are multiple exact matches or only fuzzy matches, show names and available distinguishing metadata, then ask the user to select a workspace. Do not guess or require them to find a UUID.
3. If there are no matches, stop and report that the token cannot see a workspace with that name.

Never pass the human workspace name where Terraform expects `project_id`. Some modules also accept a human `stackgen_project_name`; only use that field when the module documentation says the MCP tool requires a human-readable project name.

## Establish the Workspace Baseline

On a workspace initialization/import/capture request, first contact with a populated workspace, or when the completeness of existing state/configuration is unproven, read and follow [references/workspace-baseline.md](references/workspace-baseline.md). Complete this job even when no deployment changes were requested.

The baseline requires both coverage and convergence evidence. A zero-diff plan against partial state is not complete capture. An existing scenario state file or successful exporter run is not sufficient evidence by itself.

Keep a coverage manifest mapping live resource identities to their owning roots, addresses, import IDs, and capture status. Record exclusions only when the user requested them and identify dependencies retained as references. Report unsupported or unreadable contents as gaps; do not declare full capture or proceed with deployment while in-scope configuration remains uncaptured.

For later operations, reuse the recorded baseline, reconcile current inventory with its manifest, and run a fresh normal plan before changes. If the workspace is empty, record evidence of that inventory result and establish an empty zero-diff root first.

## Deployment Workflow

1. **Read repo instructions first.** Open `AGENTS.md`, relevant repository skills from the integration guide, and the target module's `main.tf`, `variables.tf`, `outputs.tf`, and README when present. Inspect resource ownership and publishing behavior in code when prose differs.
2. **Complete or revalidate the baseline.** Follow the baseline procedure above, including ownership discovery in local and remote state. Keep baseline artifacts separate from requested deployment changes. Prefer extending the root that already targets the resolved UUID and owns related resources. If needed, create a root under `examples/scenarios/<purpose>/` and reference assets owned elsewhere.

3. **Use existing modules.** Compose with `modules/` for new workflows. During baseline reconstruction, raw `sg_*` resources are permitted when modules cannot reproduce the live configuration exactly; accurate capture takes precedence over module refactoring.
4. **Wire the provider.** Use the selected root's compatible provider constraints and lockfile. The reviewed repository baseline excludes provider `0.1.35` and `0.1.36` and requires at least `0.1.33`; some modules, such as `aios-agent-stackgen-expert`, require `>= 0.1.37`. Check the actual module before initialization and do not silently upgrade an existing root. Every managing root must configure:

   ```hcl
   provider "sg" {
     stackgen_url      = var.stackgen_url
     stackgen_token    = var.stackgen_token
     project_id        = var.stackgen_project_id
     adopt_on_conflict = false
   }
   ```

   Use the resolved UUID for `var.stackgen_project_id` and declare `stackgen_token` as a sensitive string with no embedded default. Keep `adopt_on_conflict = false` during capture. It may be enabled for a requested additive deployment where supported, but never substitutes for inventory/import or permits adopting another root's resources. Recheck ownership and rebaseline after an unexpected name conflict.

5. **Respect layers.** Foundation/policies first, integrations next, agents/workflows last.
6. **Prefer existing workspace assets.** If a module can accept `existing_*_integration_name` or an existing secret ID and the root already manages or outputs one, reuse it. Apply the repository's integration/reachability guidance: a runner attachment does not supply unrelated integrations. Preserve app-managed, YAML-managed, and skill-source ownership as described in the integration guide. Do not ask for GitHub/AWS/Slack/etc. credentials; report the exact blocker if existing assets are insufficient.
7. **Make new names collision-safe.** Use `name_suffix` or module-specific naming variables for intentionally new copies, never to bypass capture of existing resources.
8. **Plan before apply.** Run `tofu fmt`, `tofu init`, `tofu validate`, then `tofu plan -input=false -out=tfplan`. Inspect the entire saved plan. Stop on unexpected deletes/replacements, provider/project drift, or changes outside the request. Baseline and deployment plans are separate artifacts.
9. **Apply only within the request's authority.** Capture-only and plan-only requests end with their artifacts. For an authorized deployment, apply the reviewed saved plan:

   ```bash
   tofu apply tfplan
   ```

10. **Verify and report outputs.** Run a fresh normal plan after deployment to confirm convergence. For changed skill cards, use their actual owner: verify `sg_skill`-managed content after apply, or perform the required skill-source sync for an authorized deployment and verify catalog content. Check stage bindings, skill references, and integration/runner reachability; distinguish configuration convergence from runtime tests actually performed. Report workflow/agent names, endpoints, and remaining prerequisites. Deliver tokens or secret-bearing runner commands only through the environment's protected mechanism.

## Safe Plan Checks

After `tofu plan -out=tfplan`, inspect JSON:

```bash
tofu show -json tfplan \
  | jq -r '.resource_changes[]? | [.address, (.change.actions | join(","))] | @tsv'
```

These checks apply to deployment plans; the baseline must pass the stricter zero-diff gate in the linked procedure. Proceed only when every action is expected and within the requested change. `create`, `update`, and `no-op` alone do not establish that a plan is in scope.

Stop and explain unexpected:

- `delete`
- replacements in either action ordering (`delete,create` or `create,delete`)
- unrelated `update`s
- resources owned by another root
- provider/project UUID changes

An explicitly requested destructive change must match that exact request. Baseline capture itself must never mutate live resources.

## Common Module Choices

- Terraform module author/reviewer workflows: `modules/aios-agent-terraform-bot`
- Terraform state monolith demo splitter: `modules/aios-agent-tfstate-monolith-splitter`
- Advanced multi-cloud state/AppStack splitter: `modules/aios-agent-db-state-splitter`
- Repo-to-IaC: `modules/aios-agent-repo-to-iac`
- Application monorepo splitting: `modules/aios-agent-monorepo-services-splitter`
- Remote runner registration: `modules/aios-remote-runner`
- Shared policies: `modules/aios-policies`
- Foundation/models/secrets: `modules/aios-foundation`
- Installed SRE app integration bindings and alert registrations: `modules/aios-sre-app-bindings`
- StackGen expert agent with directly managed `sg_skill` cards: `modules/aios-agent-stackgen-expert`

Always verify the current variable contract in the target module before wiring it. Some README snippets can lag behind `variables.tf`.

## Handling Existing Resources

Preserve resources already managed in another root. Prefer that root for related changes and validate the baseline across all owning roots. Never import the same live object into a second managing state or remove it from an existing root to narrow scope.

Routine imports of unmanaged, in-scope resources are part of establishing the requested baseline/deployment; no separate adoption confirmation is needed. If consolidation requires changing established state ownership, prepare a concrete migration plan and obtain authorization for that migration. Missing access to an owning backend is a blocker, not permission to duplicate ownership.

Ownership also includes installed apps, `stackgen ai apply` YAML packs, and skill-source sync jobs. Do not put their resources under a second independent controller. Capture the authoritative configuration and references; if the requested TFstate cannot represent that ownership faithfully, report the coverage gap and the migration needed. Do not silently exclude those resources or change their ownership to pass the baseline.

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

When new or changed modules include persona files, also run `make verify-persona-length` and honor their persona guards. For new reusable packages, follow the repository authoring checks for module/scenario documentation, demo registration, and catalog updates.

For db-state-splitter template changes:

```bash
make validate-db-state-split-templates
```

## Output Style

Summarize:

- Resolved workspace name/UUID and full-workspace or explicitly narrowed capture scope
- Terraform roots/backends used and protected locations of state snapshots, matching IaC, and coverage manifest
- Live inventory versus captured resources, existing ownership, explicit exclusions, and unresolved gaps
- Baseline plan command, timestamp, exit code, and zero create/update/delete evidence; resolve output-only differences before declaring success
- Modules added or updated
- Deployment plan summary, authorized apply result, post-deployment convergence, and key outputs
- Repository revision/provider versions, discovery route, skill-content ownership/publication status, and runtime checks actually performed
- Exact blocked prerequisites or provider limitations; do not claim completion when coverage or zero-diff verification failed
