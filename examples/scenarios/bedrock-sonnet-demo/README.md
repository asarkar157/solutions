# Scenario: Bedrock Claude Sonnet 4.6 demo

Shows **AWS SRE** agents running on **Amazon Bedrock** (Claude Sonnet 4.6) instead of a direct Anthropic API key.

## Prerequisites

- StackGen / Guild tenant with Bedrock provider support
- AWS account with Bedrock access in `var.aws_region`
- Either:
  - Guild deployed on AWS with an IAM role that can invoke Bedrock (`bedrock_use_iam_role = true`, default), or
  - Static AWS keys with `bedrock:InvokeModel` and list permissions
- IAM role for the **AWS integration** (`aws_role_arn`) for MCP tooling

## Apply

```bash
cd examples/scenarios/bedrock-sonnet-demo
tofu init
tofu apply \
  -var="stackgen_url=https://YOUR_TENANT" \
  -var="stackgen_token=$STACKGEN_TOKEN" \
  -var="aws_role_arn=arn:aws:iam::123456789012:role/YourReadRole"
```

For static Bedrock keys:

```bash
tofu apply \
  -var="bedrock_use_iam_role=false" \
  -var="aws_access_key_id=AKIA..." \
  -var="aws_secret_access_key=..."
```

## Validate

1. Open the AWS SRE agent in Guild chat.
2. Confirm the agent’s `model_names` includes `claude-sonnet-bedrock` (or your `model_name` override).
3. Send a short prompt; Guild logs should show `provider=bedrock` on model resolution.

## Talk track

- **Why Bedrock:** Single AWS bill, IAM boundaries, private networking — no separate Anthropic subscription.
- **Sonnet 4.6:** Registered with the cross-region inference profile (`us.anthropic.claude-sonnet-4-6` in `us-east-1`).
- **Module:** `aios-foundation-bedrock` — compose with other agents the same way as `aios-foundation`.
