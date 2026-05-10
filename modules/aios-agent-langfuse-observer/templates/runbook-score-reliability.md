Compute reliability score (0-100) from Langfuse trace data.

Sub-metrics and weights:
- Error rate (40%): 0-1% → 100, 1-3% → 85, 3-5% → 70, 5-10% → 50, >20% → 10
- Retry storms (20%): sessions with >3 traces in 60s. 0 → 100, >10 → 15
- Timeout frequency (20%): traces >120s. 0% → 100, >5% → 20
- Error trend (20%): compare last 24h to 7-day average. Stable → 100, doubled → 10

Flag any agent with >15% individual error rate as a hot spot.
Output: reliability score with sub-metric breakdown and per-agent analysis.
