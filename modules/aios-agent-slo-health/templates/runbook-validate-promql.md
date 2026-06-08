Validate proposed SLO PromQL with live Grafana queries.

## Coordinator duties (slo-health ONLY)

You are the **coordinator** for this stage. Do **not** run deep PromQL loops inline when parallel batches are enabled (spawn contracts on this stage binding).

### When parallel batches enabled (spawn contracts present)

1. `read_notes` — load `slo_proposals`.
2. Split proposals round-robin into up to **4** batches (skip empty batches). For each non-empty batch, `note()`:
   - `validate_batch_a_ids`, `validate_batch_b_ids`, … — JSON array of proposal `id` or `name` strings.
3. Spawn **one** parallel fan-out via `create_agent` with `flow_type: "parallel"` for **only non-empty** batches:
   - `validate-promql-batch-a` … `validate-promql-batch-d` (match spawn contract names exactly).
4. After sub-agents return, merge `validate_batch_*_result` arrays into **`slo_proposals_validated`** JSON.
5. `note()` `validated_count=<N>` and full `slo_proposals_validated`.

**Limits:** max **1** create_agent fan-out message; do not spawn ad-hoc sub-agents without spawn contracts.

### When parallel batches disabled (no spawn contracts)

1. Read `slo_proposals`.
2. For each proposal run good and total (or threshold) queries via `query_metric`.
3. Drop candidates with empty/error results.
4. Emit **`slo_proposals_validated`** JSON with `validation_status` per item and `validated_count`.

No YAML files until validation passes.
