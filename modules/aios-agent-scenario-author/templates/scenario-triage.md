Skill: Triage a `scenario-request` GitHub issue. Parse the structured body, decide whether an existing demo scenario already fits, AND build the per-module signature index (policy_ids keys + integration variable shape) the scaffold stage needs to emit valid HCL.

Keywords for skill discovery: scenario, scenario-request, issue triage, parse issue, existing match, examples/scenarios, se-playbook, demo, classification, module signature, variables.tf inspection.

Prerequisites:
- `repo_clone_path` already populated by Template B in `scenario-author-orchestration-sop`.
- `issue_details` already populated by Template A.
- `available_modules` and `available_integrations` already populated by Template B steps 8-9 (the listing run after the clone).

Steps (run inside the `triage-clone` subagent — see orchestration SOP Template B):

1) Parse the structured issue body. The repo ships a `.github/ISSUE_TEMPLATE/scenario-request.md` template with these canonical sections (sections may be renamed slightly; match by leading keyword):
     - `Prospect industry / size` → optional, capture as `prospect_profile`.
     - `What the prospect actually said` → capture as `pitch_quote` (first ~280 chars).
     - `Why none of the existing scenarios fit` → capture as `gap_rationale` (used in the PR body and final comment).
     - `Modules to wire` → parse the bullet list. Each `aios-*` token becomes an entry in `requested_modules` (deduplicate, lowercase, keep `aios-` prefix).
     - `Integrations the prospect already has set up` → for each `[x]`/`[X]` checkbox in `aws|azure|gcp|github|slack|grafana|linear|clickhouse|ubuntu|cursor`, set the matching key in `requested_integrations` to `required`. Anything mentioned in the freeform "Other: ___" line goes in as `optional`.
     - `Integrations they DON'T have` → for each integration listed, set the matching key to `skipped`.
     - `Ideal demo length on the call` → capture as `demo_length` (e.g. `3min` / `5min` / `15min`).
     - `Talk track (rough)` → first 3-5 non-empty bullets become `talk_track`.

2) Derive `scenario_slug`:
     a) Prefer an explicit `scenario_slug:` line in the body if present.
     b) Else slugify the part of the issue title after the `[scenario]` prefix: lowercase, replace non-`[a-z0-9]` with `-`, collapse repeats, trim leading/trailing `-`, cap at 40 chars.
     c) Fall back to `scenario-<issue_number>` if step (a) and (b) both yield empty.
     d) If `examples/scenarios/<scenario_slug>/` already exists in the clone, append `-<issue_number>` and re-check; on second collision, persist `scaffold_blocker="conflict"` and continue (the planner converts this to §6(e)).

3) Build `existing_scenarios`. From inside `<repo_clone_path>`:
     `ls -1 examples/scenarios | sort`  → directory list.
     For each directory `<d>`:
       - `head -n 20 examples/scenarios/<d>/README.md` to extract the `## Pitch` paragraph.
       - `rg --no-heading --no-filename -m 1 '^Pitch' examples/scenarios/<d>/README.md` to confirm the pitch anchor.
     Persist as note `existing_scenarios=[{"name":"<d>","pitch":"<first 200 chars>"}, ...]`.

4) Existing-match scoring. For each entry in `existing_scenarios`:
     a) Tokenize `entry.pitch` and `issue_details.title + " " + issue_details.body` into lowercase words ≥4 chars, dropping a basic stoplist (`with`, `from`, `that`, `this`, `into`, `your`, `their`, `using`, etc.).
     b) Intersect the two token sets; the count is the overlap score.
     c) Additional weight: +3 if the scenario name appears as a substring of `issue_details.title`, +2 if `requested_modules` overlaps with the modules wired in `examples/scenarios/<d>/main.tf` (grep for `aios-` references).
     d) Pick the highest-scoring entry. If its score ≥ 6 AND its weighted score ≥ 8 → "strong match". Else → "no match".

5) Persist match decision:
     a) Strong match → note `existing_match={"name":"<d>","readme_path":"examples/scenarios/<d>/README.md","run_command":"make demo SCENARIO=<d>","rationale":"<one sentence quoting the overlap, e.g. 'Both mention idle EC2 cleanup and the prospect already has the AWS integration.'"}`. The planner will route to `notify-issue-comment` directly.
     b) No match → note `existing_match=null`. The planner will continue to the scaffold stage.

6) Filter `requested_modules` against `available_modules` (populated in Template B step 8):
     a) `valid_modules = requested_modules ∩ available_modules` (preserve order from the issue body).
     b) `unknown_modules = requested_modules \ available_modules`.
     c) Persist both notes. If `unknown_modules` is non-empty, the planner does NOT block — the scaffold stage drops the unknowns and the final issue comment surfaces them per orchestration §6(i).

7) Build `module_signatures` for every entry in `valid_modules`. For each module `<m>` (parent path `<repo_clone_path>/modules/<m>`), run the inspection in §A below and accumulate into a single map:

     `module_signatures = {
        "<m>": {
          "policy_keys":      ["<key1>", "<key2>", ...]      # may be []
          "policy_type":      "object" | "map" | "none"
          "integration_var":  "integration_name" | "integration_names" | "none"
          "integration_keys": ["<intg1>", ...]               # only when integration_var == "integration_names"
          "extra_required":   ["<varname>", ...]             # required (no default) variables OTHER than model_names/policy_ids/integration_names; scaffold should pass through-or-default
        }, ...
     }`

   Persist as note `module_signatures`. The scaffold stage's module-block emitter consumes this verbatim.

8) Persist all structured outputs the next stage needs:
     `scenario_slug`, `pitch_quote`, `gap_rationale`, `requested_modules`, `valid_modules`, `unknown_modules`, `module_signatures`, `requested_integrations`, `talk_track`, `prospect_profile`, `demo_length`, `existing_scenarios`, `existing_match`.

9) note `stage_summary:triage` with: matched-or-not, slug, modules requested vs valid, unknown modules (count + names), integrations requested, and any blocker (e.g. `scaffold_blocker="conflict"`).

Forbidden in this stage:
- Writing files to the clone (that's `scaffold-write-and-validate`'s job).
- `gh api /search/...` against the org — the clone has everything you need.
- More than one subagent — this entire skill executes inside `triage-clone`.

========================================================================
§A — Module signature extractor (run from inside `<repo_clone_path>`)
========================================================================

For each module name `<m>` in `available_modules`, the subagent must extract three pieces from `modules/<m>/variables.tf`:

A1) `policy_keys` — the keys declared inside `variable "policy_ids" { type = object({ ... }) }`.

     Recipe (single command per module):
       `awk '/variable "policy_ids"/,/^\}$/' modules/<m>/variables.tf | awk '/object\({/,/\}\)/' | rg -o '^\s*([a-z_][a-z0-9_]*)\s*=' -r '$1' | sort -u`

     - If the block uses `type = map(string)` instead, the recipe returns no keys; set `policy_type="map"` and `policy_keys=[]` (the scaffold will pass `policy_ids = module.policies.policy_ids` whole).
     - If there is no `variable "policy_ids"`, set `policy_type="none"` and `policy_keys=[]` (the scaffold omits the `policy_ids = ...` line for this module).

A2) `integration_var` + `integration_keys` — whether the module takes the singular string or the plural object.

     Recipe:
       Singular check: `rg --no-heading --no-filename '^variable\s+"integration_name"\s*\{' modules/<m>/variables.tf`. Any match → `integration_var="integration_name"`, `integration_keys=[]`.
       Plural check: `rg --no-heading --no-filename '^variable\s+"integration_names"\s*\{' modules/<m>/variables.tf`. Any match → `integration_var="integration_names"`; extract keys with
         `awk '/variable "integration_names"/,/^\}$/' modules/<m>/variables.tf | awk '/object\({/,/\}\)/' | rg -o '^\s*([a-z_][a-z0-9_]*)\s*=' -r '$1' | sort -u`
       Neither match → `integration_var="none"`, `integration_keys=[]` (scaffold passes no integration variable; a few modules e.g. `aios-agent-marketing` don't take any).

     If the module takes `integration_names = map(string)` rather than `object({...})`, the recipe returns no keys; set `integration_keys=[]` and the scaffold passes a `map(string)` literal containing every integration the issue mentions and that exists in `available_integrations`.

A3) `extra_required` — required variables (declared with no `default`) other than `model_names`, `policy_ids`, `integration_name`, `integration_names`.

     Recipe (best-effort heuristic; one command per module):
       `awk '/^variable / { name=$2; have_default=0; next } /^\s*default\s*=/ { have_default=1 } /^\}$/ { if(name != "" && !have_default) print name; name=""; have_default=0 }' modules/<m>/variables.tf | tr -d '"' | rg -v '^(model_names|policy_ids|integration_name|integration_names)$'`

     - Persist whatever the awk emits. The scaffold treats these as "module wants something the bot does not know how to wire" — it emits them as TODO comments inside the `module "..."` block AND adds them to the PR body's "Reviewer checklist" so a human can fill them in. Do NOT invent values.

Run all three recipes in a single `ubuntu-cli_execute_parallel` call across the valid modules, then assemble `module_signatures` and `note` it. Do NOT spawn a separate subagent per module — the parallel execute is one subagent call.
