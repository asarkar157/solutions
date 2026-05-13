# Scenario: `clean-tenant-reset`

## Pitch (utility, not a prospect-facing demo)

Run this between back-to-back prospect calls to leave the demo tenant at a **known baseline** — `aios-foundation` + `aios-policies`, no integrations, no agents. The next scenario picks up from here.

## When to use this

- You just finished an aggressive demo (e.g. `incident-triage` with a full SRE fleet) and the next prospect wants the FinOps story instead. Reset, then apply `finops-weekly`.
- A prior demo left orphan resources after a partial `apply` failure. This scenario re-asserts the baseline so subsequent scenarios reuse the same models and policies.
- A new SE is taking over the tenant and you want it documented to a known state.

## Run

```bash
# Wipe the previous scenario first:
make demo-reset SCENARIO=<previous-scenario>

# Then re-apply this baseline:
make demo SCENARIO=clean-tenant-reset
```

## Caveats

- This does **not** purge resources created outside of Terraform (anything an SE clicked in the UI). For that, use [`tools/aios-export/`](../../../tools/aios-export/) to snapshot first, then prune in the UI with full visibility.
- The Guild data itself (chat history, evidence, schedules created in the UI) is not destroyed. This is a Terraform-state-level reset, not a tenant nuke.

## Next steps

After applying the baseline, pick a real scenario:

```bash
make demo-list
make demo SCENARIO=<one of the above>
```
