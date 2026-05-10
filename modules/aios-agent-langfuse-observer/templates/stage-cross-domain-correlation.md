%{ if has_grafana ~}
Correlate Langfuse LLM trace data with Grafana infrastructure metrics to
produce a unified AI operations health assessment.

This is the cross-domain synthesis stage. Real-world scenario: an AI platform
team notices agents are producing lower quality outputs. Is it a prompt problem
(visible only in Langfuse) or an infrastructure problem (visible in Grafana)?
This stage answers that question by joining both data sources.

Steps:
1) Pull Grafana metrics for the evaluation window: CPU utilization, memory
   pressure, pod restart counts, and API error rates for the Guild service.
2) Overlay Langfuse error spikes onto the Grafana timeline. Check if Langfuse
   error rate increases correlate with infrastructure events (deployments,
   node scaling, OOM kills).
3) Compare Langfuse latency P95 against Grafana request latency P95 for the
   Guild API. If Langfuse latency spiked but Grafana latency was flat, the
   bottleneck is upstream (LLM provider). If both spiked, it is infrastructure.
4) Check Grafana for recent deployment events in the ±2 hour window around any
   Langfuse quality score regressions. A deploy that introduced a prompt change
   or model swap is the most common cause of quality drops.
5) Cross-reference Langfuse cost spikes with Grafana compute utilization. If
   cost spiked but compute stayed flat, the cost driver is LLM token usage, not
   infrastructure. If both spiked, a traffic surge may be the root cause.
6) Synthesize findings into a unified health assessment:
   - AI-layer issues (prompt quality, model selection, token waste)
   - Infrastructure-layer issues (resource pressure, deployment regressions)
   - External issues (LLM provider rate limits, API outages)
7) Output: cross-domain correlation report with root cause attribution,
   timeline overlay, and recommendations split by AI-layer vs infra-layer.
%{ else ~}
Synthesize Langfuse-only signals into a unified AI operations health assessment.

Grafana is not attached to this agent, so this stage stays within Langfuse:
trace errors, latency percentiles, quality scores, token/cost trends, and
session-level patterns. Use any other attached integrations (for example
Slack, Linear, GitHub, or a cloud integration) only when they add verifiable
context—such as linking a trace spike window to a release commit or an incident
ticket—without mutating Langfuse data.

Steps:
1) Segment the evaluation window by agent, model, and environment metadata from
   Langfuse (use optional_inputs when provided).
2) Identify error and latency regressions versus the prior window; classify
   errors (timeout, rate limit, context overflow, tool failure).
3) Relate quality-score drops to model or prompt/version metadata when present
   in trace attributes.
4) Attribute cost spikes to token mix (input vs output) and model selection;
   flag likely inefficiencies (retry storms, oversized prompts).
5) Output: correlation-style report with AI-layer root cause hypotheses and
   recommended next checks. Clearly state that infrastructure correlation was
   not performed because Grafana was not configured.
%{ endif ~}
