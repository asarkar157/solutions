Skill: **Logical grouping** of resources from a monolithic Terraform/OpenTofu state for **AWS, Azure, GCP** (and mixed) — not limited to RDS.

Keywords: terraform show -json, state list, jq, dependency closure, tags, default_tags, module path, for_each, workspace, aws_*, azurerm_*, google_*, azapi_*, logical_group, shard.

## Inputs

- Monolith state JSON or `terraform state list` output (paths from **`monolith_state_local_path`** in workflow notes — often under **`/tmp`** when the workspace mount is read-only).
- Optional **`grouping_policy_json`** from workflow inputs: rules such as  
  - **Tag keys** (e.g. `app`, `service`, `team`, `cost-center`) — match `values.tags` / provider `default_tags` in state.  
  - **Module address prefix** (e.g. `module.data_plane`).  
  - **Resource type regex** (e.g. `^(aws_db_|azurerm_mssql_)`).  
  - **Explicit include/exclude lists** of addresses.

## Steps

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

## Tooling

All parsing / `jq` / heavy JSON via **Ubuntu CLI**. StackGen MCP is used **after** this manifest exists (see `stackgen-appstack-mcp-playbook-sop`).

### Large states (speed + reliability)

- **Do not** paste full state JSON into chat or into **`create_agent`** goals — use **`ubuntu-cli_create_files`** to write `*.jq` / shell scripts under **`/tmp/...`**, then **`ubuntu-cli_execute_series`** with short commands.  
- **Progressive passes:** instance count → provider/module histogram → manifest build, instead of one giant `jq` that materializes everything at once (avoids OOM, timeouts, and truncated tool args).  
- Keep each **`ubuntu-cli_*`** step under typical integration time limits; split by module prefix or by cloud if the monolith is huge.

### Edge cases (addresses, deposed, data sources)

- **Addresses** must match Terraform exactly, including **`count` / `for_each` keys** (e.g. `aws_instance.foo[0]`, `module.x.aws_s3_bucket.y["a"]`). Stripping indices breaks allocation and count reconciliation.
- **`deposed`** / tainted rows and **orphan** objects: decide include vs exclude per org policy; document in `logical_group_manifest.notes` so `monolith_resource_count` stays comparable to shard sums.
- **`data.*`** entries in JSON snapshots are usually **not** managed resources — exclude from managed-instance totals unless policy says otherwise.
