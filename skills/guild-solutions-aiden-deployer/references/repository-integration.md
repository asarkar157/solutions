# Integrate appcd-dev/solutions Tools and Guidance

Reviewed against [appcd-dev/solutions at 0da416be8bd9d5de8dfdc1ef366de827f4d72d1e](https://github.com/appcd-dev/solutions/tree/0da416be8bd9d5de8dfdc1ef366de827f4d72d1e). Paths below are relative to the selected repository root. Inspect that revision's actual files and module contracts; this reference does not imply a stale local checkout contains newer tools. Use an isolated checkout when a newer version is required and the user's checkout must be preserved. Pin Git module sources for deployments.

Read the sections relevant to the current operation. Capture uses discovery, export, and ownership guidance. New module authoring and post-deployment testing are separate modes; their mutation recipes do not belong in an initialization/import job.

## Workspace Discovery Through MCP or HTTP

The repository's `tools/aiden-mcp-server` exposes direct Aiden HTTP API access with PAT authentication. When these tools are already available, inspect `aiden_server_info` to verify its endpoint and scope, then prefer the read tools below. Client-specific tool prefixes may vary; use the exposed equivalents.

| Tool | Use during capture |
| --- | --- |
| `aiden_list_collection` | List a documented collection with explicit workspace scope and pagination parameters. |
| `aiden_get_object` | Retrieve full details by actual object ID/name. |
| `aiden_get_subresource` | Retrieve documented nested definitions, app integrations/resources, or agent overview. |
| `aiden_agent_snapshot` | Retrieve one agent, overview, and health; this is not a workspace export. |
| `aiden_app_snapshot` | Retrieve one installed app, integration bindings, and resources; reconcile app ownership. |
| `aiden_request` with `method: "GET"` | Read a documented endpoint not covered by a convenience tool. |

For example, after resolving the workspace UUID, call `aiden_list_collection` with `collection: "agents"`, `org_id: <resolved UUID>`, and `query_json: "{\"limit\":200}"`. Inspect the response's actual pagination contract and continue until exhausted. The server performs one request per list call; neither `limit: 200` nor a snapshot tool guarantees full coverage. Retrieve details for objects whose list entries are summaries. Discover collection names from documentation/API responses rather than assuming every Terraform type has a same-named list endpoint.

Use the same verified scope on every call. The server adds `orgId` from `org_id` or `STACKGEN_PROJECT`, but extra `query_json` parameters can override it; avoid conflicting `orgId` fields and verify returned request URLs. Unscoped empty results do not establish an empty workspace.

Read `.cursor/skills/use-stackgen-guild-api/SKILL.md` for the API conventions. Tenant-edge calls normally use `<StackGen URL>/guild/api/v1/...` with bearer PAT authentication and `orgId`. Some raw API endpoints accept a known workspace slug; this does not make that slug valid for Terraform's provider `project_id`. Keep using the resolved UUID for Terraform and explicitly record any verified endpoint-specific scope mapping.

If no MCP connection is available, use those documented read-only HTTP APIs with a secret-aware HTTP client, keeping authentication out of echoed commands, logs, and command-line arguments. Map the already supplied PAT into the chosen client's credential environment; do not ask for another token merely because a helper uses a different variable name.

A missing MCP connection does not block the HTTP fallback. When local MCP setup is within the task, read `tools/aiden-mcp-server/README.md`, build its reviewed source, and use local stdio with `STACKGEN_URL`, `STACKGEN_TOKEN`, and `STACKGEN_PROJECT=<resolved UUID>`. Use the host's supported registration mechanism. Do not invent an available tool, a deployed HTTP endpoint, or a globally installed server. Do not expose a new HTTP service merely to perform capture. This skill remains usable without MCP and requires no particular IDE.

### Read-Only Boundaries

`STACKGEN_ALLOW_MUTATIONS=false` guards non-GET calls only through the generic `aiden_request` tool in the reviewed implementation. Dedicated `aiden_start_agent_chat` and model/integration test tools issue POST requests without that guard. During capture, use the listed read tools and GET requests only; do not start chats, trigger workflows, test integrations/models, or enable mutation tools. Starting an agent can cause downstream actions even when described as a test.

The MCP server provides discovery data. It does not synthesize native TFstate, exhaust all pagination, generate matching HCL, or run Terraform plans. Continue through [workspace-baseline.md](workspace-baseline.md) after collecting evidence.

## Resource Ownership Beyond Terraform Roots

Include each controller in the coverage manifest; the presence of an object in an API list is not proof that it is unmanaged.

- **Installed apps:** Read app definitions, integrations, and resources. `sg_app`, as used by `modules/aios-sre-app-bindings`, manages install integration bindings and configurable app settings, not every manifest field or app-generated agent setting. Preserve app-owned model wiring; do not rewire child agents independently to make Terraform agree. Capture supported app configuration, alert registrations, and references. Report unsupported in-scope configuration as a gap.
- **YAML packs:** `stackgen ai apply` configurations are another controller. Follow `docs/ai-apply/` and `AGENTS.md`; do not manage the same named objects independently through Terraform and YAML. Capture their authoritative definitions and identify any explicit ownership migration needed for the user's IaC scope.
- **Skill catalog content:** A checked-in Markdown file, a workflow's `skill_refs`, the live skill body, and the publisher are distinct. Read selected module code and live catalog metadata to identify whether `sg_skill` or a skill-source sync job owns the body. Preserve names, text, source revisions, and bindings without invoking a sync during capture. If that ownership/configuration cannot be represented faithfully, retain evidence and report a coverage gap instead of treating the name alone as full capture.

Use the installed provider schema/importer for each supported authoritative resource. The baseline's one-owner rule applies across all controllers, and its completeness gate still applies to explicitly reported unsupported configuration.

## Module Selection and New Package Authoring

Read these repository skills as Markdown, regardless of the executing agent/IDE. They need not be installed as separate host skills. Load their supporting references when the selected task requires them.

| Operation | Repository guidance |
| --- | --- |
| Select/reuse modules and compose workflow definitions | `.cursor/skills/build-aios-solution/SKILL.md` and its `reference.md` |
| Create a new reusable module/scenario from requirements | `.cursor/skills/author-aios-module-scenario/SKILL.md` and relevant references/examples |
| Wire integrations and choose cloud versus private-network runner access | `.cursor/skills/wire-integration-and-reachability/SKILL.md` |
| Publish externally synced skill cards | `.cursor/skills/sync-aios-skills/SKILL.md`, `docs/guides/skills-sync.md` |
| Diagnose an applied but silent/tool-less agent | `.cursor/skills/troubleshoot-agent-silence/SKILL.md` |
| Debug an authorized multi-stage deployment incrementally | `.cursor/skills/incremental-workflow-bring-up/SKILL.md` and its relevant reference |

Prefer existing modules, thin wrappers, or scenario composition before authoring a new module. For new reusable packages, prepare the repository's customer-neutral Horizontal Brief and keep module/scenario identifiers generic. This is an authoring convention, not an instruction to rename or redact live values in reconstructed private IaC. Preserve captured names/settings and protect sensitive artifacts.

Honor the actual workflow contract: matching `stages` and `stage_bindings`, stable stage IDs, declared dependencies, and correct skill/runbook references. `approve = true` on a workflow definition does not bypass runtime human approvals. Respect persona size guards and the repository's documentation/catalog/demo registration requirements for new packages.

Provider baseline in the reviewed `AGENTS.md` is `>= 0.1.33, != 0.1.35, != 0.1.36, < 0.2.0`. Modules can require more: `aios-agent-stackgen-expert` declares `>= 0.1.37`. Intersect root/module constraints and preserve exclusions; inspect actual code when an older README or generated HCL disagrees. Handle incompatibility with an existing lockfile explicitly rather than silently running `init -upgrade` in a managing root.

## Complete an Authorized Deployment

Separate Terraform convergence from operational readiness. After the reviewed deployment plan is applied, verify the changed resources and run a fresh normal plan. Then perform only the applicable completion steps within the user's request:

1. **Skill publication:** For modules with `sg_skill`, let Terraform remain the publisher and verify the resulting catalog content. The reviewed `modules/aios-agent-stackgen-expert/main.tf` uploads skill bodies through `sg_skill.skill_md`; it does not require a duplicate skill-source registration. For modules that only reference files/skill names, follow `sync-aios-skills`: register/reuse the intended source, pin the source revision, run the sync, and verify `search_skill`/`load_skill` results or equivalent read APIs against the source. Do not apply the documentation's broad "apply never uploads bodies" statement to a module that explicitly manages `sg_skill`.
2. **Reachability:** Reuse existing integration names/secret references. Follow the repository's Mode 1 (worker-reachable integration) versus Mode 2 (runner in the private network) guidance. A runner attachment alone does not create a Grafana, SigNoz, database, or other tool integration. Report missing prerequisites without asking for unrelated credentials.
3. **Runtime checks:** Use read-only configuration/health checks first. Use agent-silence guidance to identify the failed layer. Trigger chats, workflow runs, or service probes only when their effects are within the authorized deployment/test request; do not conflate a successful apply with a tested workflow.
4. **Incremental bring-up:** Apply this procedure only to an authorized test/deployment scope. Its examples trim stages, replace agents, restart runners, and trigger runs. Do not use them to reconstruct an existing workspace or automatically replace a production agent. Review every changed plan, preserve unrelated live workflows, and restore the intended final stage graph before declaring completion.

During initialization/import, these are facts to capture and prerequisites to report, not actions to execute. If a selected repository skill is missing in an older checkout, inspect an available reviewed revision or use the specific guidance above with verified APIs/contracts; do not assume that missing code is installed.
