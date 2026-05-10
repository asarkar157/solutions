Compile dimension scores into a composite AI Operations Health Scorecard.

Composite formula:
  score = (reliability × 0.30) + (correctness × 0.30)
        + (performance × 0.20) + (efficiency × 0.20)

Letter grades: A (90-100), B (80-89), C (70-79), D (60-69), F (<60).

Include: evaluation period, total traces, active agents, models used,
per-dimension table (score, grade, trend), hot spots, and top 3-5
prioritized recommendations.

When cross-domain correlation data is available, attribute issues to:
- AI layer (prompt, model, token) vs Infrastructure layer (compute, network).
- Generate separate recommendation tracks for the AI platform team and
  the infrastructure/SRE team.
