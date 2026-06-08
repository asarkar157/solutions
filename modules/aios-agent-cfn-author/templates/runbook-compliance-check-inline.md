Run FedRAMP and org baseline preflight via the **compliance-check-runner** spawn contract.

1. Spawn exactly one **compliance-check-runner** using the spawn-context **Compliance check command**.
2. Mirror stdout only: `compliance_summary=`, `compliance_blocked=`.
3. **Stage output ≤8 lines** — structured key=value only. FORBIDDEN: `load_skill`, `read_notes`, FedRAMP prose.
4. Downstream stages read `WORK_ROOT/generated/compliance_report.json` when needed — never replay full predecessor markdown.
