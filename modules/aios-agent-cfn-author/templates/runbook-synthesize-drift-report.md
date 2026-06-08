Aggregate drift findings into an executive report.

1. Merge batch drift_findings; rank prod/production stacks first.
2. Emit `drift_report_json` and `drifted_stack_count`.
3. `note("drift_report_documented", "true")` when the report is written.
