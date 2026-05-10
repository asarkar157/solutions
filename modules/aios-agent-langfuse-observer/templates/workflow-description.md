%{ if has_grafana ~}
Cross-domain AI operations health assessment combining Langfuse LLM trace
analytics with Grafana infrastructure metrics. Scores reliability, correctness,
performance, and efficiency, then correlates AI-layer issues with infrastructure
events to produce a unified scorecard with root cause attribution.
%{ else ~}
AI operations health assessment driven by Langfuse LLM trace analytics.
Scores reliability and correctness, analyzes cost and latency trends, and
produces a unified scorecard. Attach Grafana (and other integrations) on the
module if you need infrastructure-side correlation.
%{ endif ~}
