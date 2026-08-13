---
name: cicd-overwatch-diagnose-recommend
description: Classify a CICD Overwatch failure and recommend the smallest safe fix, using AWS/artifact and source/contract playbooks.
---

# CICD Overwatch diagnose and recommend

Use during `diagnose-and-recommend`. Load `aws-artifact-investigation` and `source-and-contract-investigation` from the `cicd-overwatch-jenkins-rca` knowledge base for the full playbooks.

1. From the evidence bundle, decide which failure class is primary:
   - **Jenkins/controller health** — public endpoint, controller availability, queue/build state, plugin or runtime errors.
   - **Source/contract** — the Git ref/commit Jenkins built, changed files, `docs/api-contract-compatibility.md`, `frontend/contract.json`, build/test/compatibility output. Always use the exact commit Jenkins resolved, never the current branch head.
   - **Artifact/registry/AWS** — image URI/tag/digest, push/pull authorization, registry/repository policy, deployment referencing an unavailable artifact.
2. Do not assume the class from ticket text alone — the same Jenkins stage can fail for any of these reasons. Check at least one alternative explanation and explain why it is less likely.
3. If AWS or GitHub integrations are not attached and the evidence points that direction, say so as an explicit evidence gap rather than fabricating a conclusion.
4. Recommend the smallest safe fix (source-control fix/rollback, credential/config correction, registry/deployment correction, or controller recovery) and list concrete verification steps.
5. Emit a `diagnosis` block: failure class, evidence chain, alternatives ruled out, recommended fix, verification steps, and whether the fix requires remediation approval.
