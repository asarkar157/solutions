Compute correctness score (0-100) from Langfuse quality scores.

Sub-metrics and weights:
- Quality distribution (40%): mean score ≥0.90 → 100, <0.50 → 20
- Low-quality ratio (25%): % of scored traces with score <0.5. 0% → 100, >20% → 10
- Quality consistency (20%): standard deviation of scores. <0.05 → 100, >0.30 → 20
- Quality trend (15%): compare last 48h to 7-day mean. Stable → 100, dropped >30% → 10

If <10% of traces have scores, deduct 15 points and flag "insufficient scoring coverage".
Flag agents whose mean score is >1 StdDev below global mean as correctness hot spots.
Output: correctness score with sub-metric breakdown and per-agent quality analysis.
