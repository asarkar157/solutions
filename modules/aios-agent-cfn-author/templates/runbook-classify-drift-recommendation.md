Classify each drifted resource for remediation strategy.

For each drift entry assign one of:
- **FIX_DRIFT** — operational outage risk, compliance violation (encryption, public exposure), or security misconfiguration.
- **INCORPORATE_VIA_PR** — intentional valid change that should become template desired state.
- **IGNORE** — cosmetic or low-risk drift with no policy impact.

Emit `drift_recommendations` JSON with counts: `fix_drift_count`, `incorporate_count`, `ignore_count`.
Document FIX_DRIFT items with plain-English remediation steps (no AWS mutations).
