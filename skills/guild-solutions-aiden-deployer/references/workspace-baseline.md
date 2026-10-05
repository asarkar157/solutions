# Capture an Existing Workspace Before Changing It

Use this procedure for first contact with an existing Aiden/Guild workspace and whenever its baseline is incomplete. The order is live inventory → accurate Terraform state → matching Terraform IaC → verified zero-diff plan. Minimal configuration required for imports is scaffolding, not the completed reverse-engineered IaC.

## 1. Inventory and Establish Coverage

Confirm the StackGen URL and resolved workspace UUID on every discovery route. Read the discovery and ownership sections in [repository-integration.md](repository-integration.md) before using the Aiden MCP server or direct APIs. Default to the entire selected workspace, including disabled, unreferenced, UI-created, and draft resources. Do not extend into unrelated workspaces or organization-wide assets merely because the PAT can see them; record external dependencies as references. An Aiden workspace is not a Terraform CLI workspace.

Enumerate resource kinds using the selected provider version's schema, documentation, and the platform's documented read-only APIs. Follow pagination and retrieve object details as well as list results. Cover agents, workflows/stages/bindings, integrations, models/model providers, policies/bundles/attachments, secrets/references, schedules, webhooks, remote runners/attachments, runbooks, skill bodies/sources/references, knowledge resources, installed apps/integration bindings/alert registrations, chat subscriptions, agent budgets, and other workspace components actually exposed by the platform. This list is not a scope limit. Record nested or app-owned components under their authoritative owner when that is how the platform represents them; do not invent separate Terraform resources for each API object.

Maintain a coverage manifest containing:

- URL, workspace name/UUID, capture timestamp, selected scope, CLI/provider versions, and discovery sources.
- Each resource's kind, live ID, name, relationships, full-detail retrieval status, and import support.
- Authoritative controller (Terraform, installed app, YAML pack, skill source, or unmanaged), owning root/backend/CLI workspace where applicable, Terraform address, documented import ID, and state/configuration reconciliation status.
- Counts by kind, pagination completion, user-requested exclusions, and exact access/provider gaps.

If the user explicitly narrows capture, record the selected components and resolve dependencies. Capture dependencies within that scope and reference those outside it without taking ownership. Never delete resources from an existing owning root to make a narrower capture look clean.

Retain read-only snapshots of contents that cannot be represented in Terraform, distinguishing configuration gaps from runtime/history data that has no Terraform resource model. Snapshots supplement state; they are not managed resources or proof of a complete IaC baseline. Explain that boundary. If in-scope configuration is unreadable, undiscoverable, or unsupported, continue safe capture of the rest but block deployment and report an incomplete baseline. Do not silently narrow scope. Access errors are not evidence of an empty workspace.

### Existing Export Helper

Inspect `tools/aios-export/README.md` and its implementation in the selected clone before use. In the inspected version, `export.sh` exports agents, workflows, and remote runners; it omits integrations, policies, secrets, schedules, and webhooks. Its temporary state contains data sources, and its HCL files are stubs. Neither is a complete managed-resource state or verified baseline.

Use it only as a discovery/bootstrap aid, with the resolved UUID explicitly supplied as `STACKGEN_PROJECT_ID`. Supplement omissions with the MCP/API read tools in the integration guide and supported imports. Reassess helper coverage when the selected revision changes.

Account for these limitations in the reviewed exporter:

- `include_drafts` defaults to `false`. Supply `TF_VAR_include_drafts=true` for full-workspace capture. `latest_only` defaults to `true`; retrieve version history separately or use `TF_VAR_latest_only=false` for inventory where supported. Preserve history as evidence when multiple versions cannot be independently managed in Terraform; never import different versions onto duplicate owners of one live object.
- `emit_workflow` omits `stages` and `stage_bindings`. Retrieve full definitions and reconstruct stage graphs, bindings, and skill/runbook references before verifying convergence.
- Module matching is heuristic and can match a single resource from a larger module. The generated module block contains unresolved assumptions about foundation/policies/integrations, while `import.sh` targets raw resource addresses. Inspect exact module contracts and address mappings; neither matching mode nor `--strict-match` proves behavioral equivalence.
- `export.sh` creates data-source state, emits HCL/import commands, and leaves actual imports and planning to the operator. It does not enforce the baseline gate. Its temporary root runs `init -upgrade`; preserve existing managing-root lockfiles and verify the resulting discovery-provider version against them. Some snapshot fields use `try(..., [])`, so cross-check unexpectedly empty lists against scoped API reads.

Save generated files and raw snapshots in protected storage; the export output is not a safe-to-publish bundle by default. Treat emitted HCL as scaffolding until state capture and reconstruction are complete.

## 2. Find Ownership and Synthesize State

Search the selected repository for roots/backend configuration, including ignored local state while excluding provider caches and Git internals:

```bash
rg --files --hidden --no-ignore \
  -g '*.tf' -g '*.tofu' -g '*.tfvars' -g '*.tfvars.json' -g '*.tfstate' \
  -g '!**/.terraform/**' -g '!**/.git/**'
```

Inspect relevant roots' backends and CLI workspace selections, then use `tofu state list` and protected `tofu state pull` snapshots. The absence of a local `.tfstate` does not mean resources are unmanaged. Verify each root's actual endpoint, project UUID, provider aliases, and live IDs. Do not print tfvars or state containing credentials.

Preserve established ownership and back up state before imports/migrations. Preserve lineage, provider references, addresses, and backend locking; let the Terraform engine manage state serial increments. If multiple roots own the workspace, keep one owner per object and validate each root; record aggregate coverage without creating a duplicate managing state. Also inventory app, YAML, and skill-source ownership using the integration guide. Capture their supported authoritative parent/configuration instead of independently importing controller-generated children. Inaccessible ownership information is a gap to report. Consolidation or a change of controller requires a separately authorized ownership migration.

For unmanaged resources:

1. Choose an appropriate root or create a dedicated workspace baseline root. Configure the actual endpoint/UUID, compatible provider constraints/lockfile, sensitive variables, and `adopt_on_conflict = false`. Do not upgrade providers as an incidental capture step.
2. Inspect `tofu providers schema -json` and import documentation/source for that provider version. Verify each type's importer, exact ID format, and scope. Schema alone does not document import IDs.
3. Create minimal valid resource scaffolding for destination addresses. Derive required inputs from live evidence; never fabricate secret values or apply placeholders.
4. Use CLI `tofu import ADDRESS IMPORT_ID` for each unmanaged object, quoting addresses/IDs safely. Imports write state through the provider's read/import path without creating, updating, or deleting live resources. This is the preferred way to synthesize provider-valid state before completing HCL.
5. Preserve a protected native state snapshot and reconcile imported IDs, nested structures, relationships, and provider Read results with live inventory. `tofu show -json` is an inspection representation, not a native `.tfstate` replacement.

Existing native state or a verified provider-aware exporter can supply state where appropriate. Generic API JSON and data-source-only state are not substitutes for managed-resource state. Do not fabricate IDs, schema versions, provider-private fields, or raw state entries. An unavailable importer/export route is a provider gap, not a reason to create/adopt live resources via `apply`.

Routine imports of unmanaged in-scope resources are included in establishing the requested baseline. Avoid managed-resource applies during capture. The lookup helper's isolated data-source-only apply is a distinct read-only operation.

## 3. Reverse Engineer Matching IaC

After state capture, build complete configuration from imported state, live details, and the installed schema. Preserve live names, settings, prompts, workflow structure, policies, schedules, integrations, attachments, and relationships. Include configurable attributes affecting behavior; omit computed-only attributes. Distinguish absent values from empty collections and provider defaults; preserve meaningful list ordering. Use repository authoring patterns where they reproduce existing behavior, but do not apply new-package anonymization, suffixing, skill sync, model rewiring, or incremental stage trimming to the captured workspace.

Prefer Guild-Solutions modules only when their inputs/defaults reproduce the captured resources exactly. Otherwise retain raw `sg_*` resources for the baseline; module refactoring is a subsequent change. Preserve imported addresses. Moving resources into modules requires explicit address mapping and another zero-diff check, never remove-and-recreate behavior.

For secrets, preserve IDs/references using supported existing-secret inputs. Reuse configured secure inputs when available. Never put redacted API strings, invented placeholders, or guessed defaults into secret fields. If required write-only values are unavailable and the provider cannot represent the existing resource without changes, mark it blocked. Do not request unrelated service credentials or claim a recreatable backup of unreadable secrets.

Correct configuration to match live evidence; do not change the workspace to make generated code appear correct. Do not add blanket `ignore_changes`, remove resources from state/configuration, or replace managed resources with data sources merely to suppress a diff.

## 4. Verify the Zero-Diff Baseline

Run in every owning root with the chosen provider version:

```bash
tofu fmt
tofu init -input=false
tofu validate
baseline_exit=0
tofu plan -input=false -detailed-exitcode -out=baseline.tfplan || baseline_exit=$?
# Record baseline_exit before running another command.
# Inspect a saved plan only if this invocation succeeded (exit 0 or 2).
```

Inspect the newly produced saved plan's JSON and diagnostics. [Detailed exit codes](https://opentofu.org/docs/cli/commands/plan/) mean `0` is no changes, `1` is an error, and `2` is a nonempty diff. Exit `2` does not pass, even for output-only differences.

Pass the baseline gate only when:

- Every in-scope configurable object has reconciled live identity, managed state, and matching IaC, with one owner and no unexplained inventory gaps.
- A normal refreshed plan in every owning root exits `0` and all managed-resource actions are `no-op` (or there are none for a verified empty workspace).
- No pending import, replacement, unresolved/deferred action, output difference, or failing check remains. Review diagnostics and reported drift against the snapshot so stale state cannot conceal inaccurate capture.

Do not use `-target`, `-exclude`, `-refresh=false`, a refresh-only plan, or other narrowing options to prove convergence. A user-requested scoped baseline still needs a full normal plan for each participating root. Zero diff proves consistency only for what Terraform sees; always pair it with independent coverage evidence.

Resolve differences by correcting configuration/capture, then rerun. A reviewed refresh-only state update may persist observed drift or baseline outputs when it changes only state; it is not convergence proof and must be followed by a passing normal plan. Never apply a normal plan containing workspace changes to force zero diff. If the platform changes during capture, refresh inventory/state and report an unstable baseline instead of asserting success.

Retain native state snapshots, matching HCL, lockfiles, coverage manifest, and plan evidence (command, timestamp, exit status, action summary) in appropriate storage. Protect state/plan artifacts; JSON inspection can expose sensitive values. Only after this gate passes may requested deployment changes begin. Capture-only work ends with the baseline handoff.

## CLI References

- [OpenTofu imports and destination resource blocks](https://opentofu.org/docs/cli/import/)
- [Normal plans, targeting, and detailed exit codes](https://opentofu.org/docs/cli/commands/plan/)
- [State/plan inspection and sensitive JSON output](https://opentofu.org/docs/cli/commands/show/)

Consult the selected provider version's own documentation/source for resources, API coverage, and import formats; CLI documentation cannot establish StackGen-specific support.
