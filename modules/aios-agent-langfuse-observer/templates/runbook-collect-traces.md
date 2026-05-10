Harvest raw trace data from Langfuse for the evaluation window (default: 7 days).

Steps:
1) Query Langfuse for all traces within the evaluation window using pagination.
2) Extract per-trace fields: trace_id, session_id, agent_name, status (OK/ERROR),
   total_latency_ms, input_tokens, output_tokens, model_id, cost_usd, score,
   error_message (first 500 chars), observation_count.
3) Group traces by agent_name and model_id for downstream aggregation.
4) Identify anomalous traces: empty executions (0 observations), silent failures
   (ERROR status with no error_message), and no-op runs (latency <100ms, 0 output tokens).
5) Compute baseline statistics: total trace count, unique agents, unique models,
   date range, and percentage with quality scores attached.
6) Output: structured trace dataset, grouped summaries, anomalous trace list.
