Extended idle-compute and storage discovery across AWS, Azure, and GCP.

This complements the FinOps idle-resource-scan by adding longer
inactivity windows, owner attribution, and quarantine readiness.

## Steps

1. **AWS**:
   - Unattached EBS volumes idle ≥ {{inactivity_days}} days
     (`aws ec2 describe-volumes --filters Name=status,Values=available`)
   - Stopped EC2 instances with `StateTransitionReason` older than the window
   - Unassociated EIPs (`aws ec2 describe-addresses`)
   - Idle NAT gateways (CloudWatch `BytesOutToDestination` ≈ 0)
   - Orphaned snapshots (no parent volume, no AMI reference)
   - Unused load balancers (zero `RequestCount` / `ActiveFlowCount`)
2. **Azure** (when integration present):
   - Unattached managed disks (`az disk list --query "[?managedBy==null]"`)
   - Stopped (deallocated) VMs older than the window
   - Unassociated public IPs
   - Idle Application Gateways
3. **GCP** (when integration present):
   - Unattached persistent disks
   - Stopped Compute Engine instances
   - Idle reserved external IPs
4. For each finding, attach: resource id, region/zone, owner tag, last
   activity timestamp, estimated monthly cost retained.
5. Skip resources tagged `aios:cleanup:exempt=true` or `do-not-delete=true`.
6. Group output by **owner / cost-center** and emit a per-team summary so
   downstream Slack notifications can route correctly.
