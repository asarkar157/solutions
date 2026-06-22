# CDK bot demo scenario

Provisions `aios-agent-cdk-bot` against your Guild tenant.

## Apply

```bash
cd examples/scenarios/cdk-bot
cp terraform.tfvars.example terraform.tfvars
tofu init && tofu apply
```

## Test matrix

See [`modules/aios-agent-cdk-bot/docs/workflow-test-inputs.md`](../../../modules/aios-agent-cdk-bot/docs/workflow-test-inputs.md).

Fixture repos under `examples/fixtures/cdk-repos/` — fork `generic-typescript` or `catalog-typescript` to your org and point the webhook at the fork.

## Demo script

```bash
./scripts/demo.sh
```

Prints sample issue titles for scenarios T1 and T3.
