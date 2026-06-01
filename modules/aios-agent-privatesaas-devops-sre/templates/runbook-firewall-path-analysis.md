Analyze Palo Alto PAN-OS firewall path for a PrivateSaaS incident (read-only).

## Steps

1. Load `normalized_alert`, `grafana_signals`, and `aws_correlation` from prior stages.
2. Extract source/destination IPs, ports, and zones from alert context and AWS correlation output.
3. Query PAN-OS traffic logs, threat logs, session tables, and policy hit counts for the incident window.
4. Identify matching security rules, NAT rules, and zone transitions for affected flows.
5. Determine whether traffic was allowed, denied, or threat-detected on the firewall path.
6. Emit `firewall_path_analysis` JSON with log excerpts, rule names, hit counts, and path verdict.

## Context hints

- `paloalto_vsys`: ${paloalto_vsys}
- `paloalto_device_group_hints`: ${paloalto_device_group_hints}

## Guardrails

- **Read-only** PAN-OS queries — no rule commits, pushes, or configuration changes.
- Scope to the vsys and device group hints when configured.
