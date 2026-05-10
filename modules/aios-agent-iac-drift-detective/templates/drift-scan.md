# Drift Scan SOP

1. **Plan Generation**: Trigger `terraform plan` to detect any discrepancies between state and remote resources.
2. **Analysis**: For each modified resource, fetch CloudTrail logs to identify WHO made the change.
3. **Reconciliation**: If the change was an unauthorized manual edit, prepare a PR to either:
   - Revert the change via Terraform apply.
   - Update the HCL configuration to match the new remote state.
