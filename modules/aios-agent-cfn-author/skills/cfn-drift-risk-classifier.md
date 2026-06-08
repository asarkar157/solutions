---
name: cfn-drift-risk-classifier
description: Classify each drifted resource as FIX_DRIFT, INCORPORATE_VIA_PR, or IGNORE.
---

# CFN drift risk classifier

1. Review aggregated drift findings per stack and resource.
2. **FIX_DRIFT** — security, compliance, or operational risk from unmanaged drift.
3. **INCORPORATE_VIA_PR** — valid desired-state change that should update IaC templates.
4. **IGNORE** — cosmetic or low-risk differences with no policy impact.
5. Emit counts per classification for downstream gates.
