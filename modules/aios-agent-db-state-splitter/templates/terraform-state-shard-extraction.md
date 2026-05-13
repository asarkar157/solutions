Skill: **Logical grouping** of resources from a monolithic Terraform/OpenTofu state for **AWS, Azure, GCP** (and mixed) — not limited to RDS.

Keywords: terraform show -json, state list, jq, dependency closure, connectivity, connected components, max_resources_per_appstack, tags, default_tags, module path, for_each, workspace, aws_*, azurerm_*, google_*, azapi_*, logical_group, shard.

## Inputs

- Monolith state JSON or `terraform state list` output (paths from **`monolith_state_local_path`** in workflow notes — often under **`/tmp`** when the workspace mount is read-only).
- Optional **`grouping_policy_json`** from workflow inputs: rules such as  
  - **Tag keys** (e.g. `app`, `service`, `team`, `cost-center`) — match `values.tags` / provider `default_tags` in state.  
  - **Module address prefix** (e.g. `module.data_plane`).  
  - **Resource type regex** (e.g. `^(aws_db_|azurerm_mssql_)`).  
  - **Explicit include/exclude lists** of addresses.
- Optional **`grouping_strategy`** (workflow input string):  
  - Omitted or **`policy_first`** — follow **Steps 2–6** below (anchors + tags/modules + graph closure).  
  - **`connectivity`** — follow **§7** (connectivity components first; then optional policy refinement).  
  - **`connectivity_capped`** — **§7** then **§8** with **`max_resources_per_appstack`** (integer string, e.g. `80`; default **80** if strategy is `connectivity_capped` but the cap input is missing).
- Optional **`max_resources_per_appstack`** — hard ceiling on **managed resource instance count** per `group_id` in **`logical_group_manifest`** after allocation. Use with **`connectivity_capped`** (§7–8); with **`policy_first`**, apply **§8** split pass if any bucket exceeds the cap.

## Steps (policy-first — default)

1. **Normalize state**  
   Count resource **instances** (including `count`/`for_each` keys). Persist `monolith_resource_count`.

2. **Anchor / seed detection (multi-vendor)**  
   Prefer **user grouping policy** when present. Otherwise infer **candidate anchors** from high-fanout types across clouds, for example:  
   - **AWS:** `aws_db_instance`, `aws_rds_cluster`, `aws_dynamodb_table`, `aws_elasticache_*`, `aws_opensearch_domain`, `aws_msk_cluster`, …  
   - **Azure:** `azurerm_mssql_server`, `azurerm_postgresql_flexible_server`, `azurerm_cosmosdb_account`, `azurerm_storage_account`, `azurerm_kubernetes_cluster`, …  
   - **GCP:** `google_sql_database_instance`, `google_bigquery_dataset`, `google_spanner_instance`, `google_redis_instance`, `google_container_cluster`, …  
   Emit `logical_group_seeds` (JSON): each seed `{address, resource_type, suggested_group_key}`.

3. **Pattern-based clustering**  
   - **Tags:** build adjacency: resources sharing the same `(tag_key, tag_value)` for configured keys → same **logical_group**.  
   - **Module tree:** everything under `module.foo` shares group `foo` unless policy splits by submodule.  
   - **Provider split:** never put `aws_*` and `azurerm_*` in the same group; split on `provider["registry…"]` boundaries when tags disagree.

4. **Graph closure**  
   For each logical group, expand with dependency edges from state JSON so security groups, subnets, keys, and secrets **owned only by that group** ride along. Mark **shared** resources (NAT, org-wide KMS, hub VPC) as `shared_ambiguous` — assign to a dedicated `shared-services` group or exclude until human rule; **never double-count**.

5. **Manifest**  
   Output JSON **`logical_group_manifest`** (alias / successor to `shard_manifest`):  
   `group_id -> { cloud_hint, resource_addresses[], notes? }`.  
   Also mirror legacy key **`shard_manifest`** with the same JSON if downstream notes still expect it.

6. **Counts**  
   `per_group_resource_counts`, `aggregate_group_resource_count`; `count_reconciliation_ok` iff sum equals `monolith_resource_count` and no duplicate addresses.

## 7. Connectivity-first grouping (`grouping_strategy`: `connectivity` or `connectivity_capped`)

Use when operators want **AppStacks aligned to dependency structure** instead of broad **resource-type** buckets (e.g. “all IAM in one stack”).

1. **Build a resource graph** from `terraform show -json`: vertices = managed resource addresses (same `data.*` / deposed rules as policy mode). Add an **undirected** edge when either resource’s config references the other’s address (dependency edges, `depends_on` when visible in JSON, cross-resource attribute references).  
2. **Provider partition** — compute **connected components** **per cloud** (`aws_*` vs `azurerm_*` vs `google_*` / `azapi_*` never mixed in one `group_id`). Optional: within a giant component, merge only along **strong** edges (e.g. duplicate `depends_on` both ways) if telemetry shows hairball graphs — document the rule in `logical_group_manifest.notes`.  
3. **Shared hubs** — NAT gateways, org-wide KMS keys, default VPCs: assign to a dedicated `shared-*` `group_id` or keep in the largest attached component but **never double-count** addresses.  
4. **Optional policy blend** — if `grouping_policy_json` is present, use tag/module rules only to **subdivide** large components or **seed** partition roots, not to merge unrelated components across missing edges.  
5. **Manifest & counts** — emit **`logical_group_manifest`** / `shard_manifest` and `per_group_resource_counts` as in policy mode; use `group_id` names like `conn-aws-001` and `notes.grouping: connectivity`.

## 8. AppStack size cap (`max_resources_per_appstack`)

Apply when workflow input **`max_resources_per_appstack`** is set (typically with **`connectivity_capped`**) or when operators cap **`policy_first`** results.

Let **N** = positive integer parsed from the workflow string (default **80** if `grouping_strategy` is `connectivity_capped` and the cap input is empty).

After initial groups exist, **split** any `group_id` whose managed `resource_addresses` length **exceeds N**:

1. Work on the **induced subgraph** of that group’s addresses.  
2. **Partition** into new `group_id`s each with **≤ N** addresses, best-effort **minimizing cut edges** (fewer cross-AppStack references):  
   - Preferred: **seeded expansion** — pick high-degree or policy-tagged seed, BFS/DFS add neighbors until N, start next shard from an unvisited high-degree node.  
   - Acceptable fallback: **deterministic bin-packing** (lexicographic order into chunks of N) when time-bounded; note `notes.partition: greedy-chunk` so plans can be revisited.  
3. If a **hub** resource would need to appear in multiple shards for correctness, keep it in **one** primary shard and record dependent addresses that reference it in `notes.cross_shard_refs` (expect `connect_resources` / env wiring in StackGen or follow-up IaC). Avoid duplicating the same address in two `group_id` lists.  
4. Assign fresh **`group_id`**s (suffix `-shard-01`, incrementing counter, etc.), recompute counts, and assert **every** group has `≤ N` resources and global sum still equals `monolith_resource_count`.

## Tooling

All parsing / `jq` / heavy JSON via **Ubuntu CLI**. StackGen MCP is used **after** this manifest exists (see `stackgen-appstack-mcp-playbook-sop`).

### Large states (speed + reliability)

- **Do not** paste full state JSON into chat or into a subagent's spawn goal — use **`ubuntu-cli_create_files`** to write `*.jq` / shell scripts under **`/tmp/...`**, then **`ubuntu-cli_execute_series`** with short commands. The subagent receives only the script **path** in its goal. Per the **Execution Optimization Protocol** (see **db-state-split-orchestration-sop**), multi-step shell work is **always** batched into one `execute_series` — never N rapid-succession `ubuntu-cli_execute_command` calls.  
- **Progressive passes:** instance count → provider/module histogram → manifest build, instead of one giant `jq` that materializes everything at once (avoids OOM, timeouts, and truncated tool args).  
- Keep each **`ubuntu-cli_*`** step under typical integration time limits; split by module prefix or by cloud if the monolith is huge.

### Edge cases (addresses, deposed, data sources)

- **Addresses** must match Terraform exactly, including **`count` / `for_each` keys** (e.g. `aws_instance.foo[0]`, `module.x.aws_s3_bucket.y["a"]`). Stripping indices breaks allocation and count reconciliation.
- **`deposed`** / tainted rows and **orphan** objects: decide include vs exclude per org policy; document in `logical_group_manifest.notes` so `monolith_resource_count` stays comparable to shard sums.
- **`data.*`** entries in JSON snapshots are usually **not** managed resources — exclude from managed-instance totals unless policy says otherwise.
