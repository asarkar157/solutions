Diff INCORPORATE_VIA_PR drift against templates in ${cfn_template_path_prefix}.

1. Clone IaC repo; locate stack template files.
2. Draft template/parameter updates reflecting valid drift.
3. Write reconcile artifact to WORK_ROOT/reconcile/template.yaml.
4. Note `actionable_reconcile_diff: "true"` when updates exist.
