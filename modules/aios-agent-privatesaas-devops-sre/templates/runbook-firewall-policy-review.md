Review Palo Alto PAN-OS firewall policies for PrivateSaaS connectivity audit (read-only).

## Steps

1. List security policy rules for the configured vsys and device group hints.
2. Identify shadowed, unused, or overly permissive rules.
3. Cross-reference rule hit counts with expected traffic patterns.
4. Flag rules with zero hits or deny-all gaps affecting PrivateSaaS zones.
5. Emit `firewall_policy_review` JSON with rule inventory, hit statistics, and hygiene findings.

## Context hints

- `paloalto_vsys`: ${paloalto_vsys}
- `paloalto_device_group_hints`: ${paloalto_device_group_hints}

## Guardrails

- **Read-only** — no rule commits or configuration pushes.
