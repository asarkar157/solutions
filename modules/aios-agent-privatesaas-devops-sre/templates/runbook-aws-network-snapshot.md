Capture a read-only AWS network topology snapshot for PrivateSaaS connectivity audit.

## Steps

1. Enumerate VPCs, subnets, route tables, NAT gateways, and transit gateway attachments for the PrivateSaaS environment.
2. Review security group rules and NACLs for cross-zone connectivity patterns.
3. Check ECS/EKS cluster networking (service endpoints, load balancers, target group health).
4. Emit `aws_network_snapshot` JSON with topology summary, connectivity gaps, and unhealthy endpoints.

## Guardrails

- Read-only AWS queries only.
- Scope to the PrivateSaaS environment label (`${private_saas_environment_label}`).
