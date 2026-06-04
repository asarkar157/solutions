# AIOS Foundation — Amazon Bedrock (Claude Sonnet 4.6)

Registers a Guild **Bedrock** model provider and **Claude Sonnet 4.6** using the cross-region inference profile ID (e.g. `us.anthropic.claude-sonnet-4-6`). Use this when agents should call Anthropic through **AWS Bedrock** instead of a direct Anthropic API key from [`aios-foundation`](../aios-foundation/).

Requires Guild with Bedrock provider support (StackGen provider `>= 0.1.25`).

## Usage

### IAM role on Guild (no static keys)

When Guild runs on EKS/ECS/EC2 with a task role that has `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`, `bedrock:ListFoundationModels`, and `bedrock:ListInferenceProfiles`:

```hcl
module "foundation_bedrock" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation-bedrock?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  aws_region     = "us-east-1"

  bedrock_auth = {
    use_iam_role = true
  }
}

module "aws_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-aws-sre?ref=main"

  model_names = module.foundation_bedrock.model_names
  # ...
}
```

### Static AWS access keys (Vault secret)

```hcl
module "foundation_bedrock" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation-bedrock?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  aws_region     = var.aws_region

  bedrock_auth = {
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    aws_session_token     = var.aws_session_token # optional STS
  }
}
```

### Bedrock first, then direct API fallbacks

```hcl
model_names = concat(
  module.foundation_bedrock.model_names,
  module.foundation.model_names,
)
```

## What it creates

| Resource | When | Description |
|----------|------|-------------|
| `sg_secret` | Static keys | Vault secret (`LLM` / `bedrock`) with `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`, `AWS_REGION` |
| `sg_guild_model_provider` | Always (when enabled) | `provider_type = bedrock`, `host = aws_region` |
| `sg_guild_model` | Always (when enabled) | Claude Sonnet 4.6 inference profile |

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | Bedrock region (provider `host`) | `us-east-1` |
| `inference_profile_id` | Override model_id (e.g. `eu.anthropic.claude-sonnet-4-6`) | Derived from region |
| `provider_name` | Guild provider name | `bedrock` |
| `model_name` | Guild model name for agents | `claude-sonnet-bedrock` |
| `good_for_task` | Guild task hint | `planning` |
| `bedrock_auth` | `use_iam_role` or static AWS keys | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `model_names` | `[claude-sonnet-bedrock]` when configured |
| `model_names_by_provider` | `{ bedrock = "..." }` |
| `inference_profile_id` | Resolved Bedrock model_id |
| `bedrock_enabled` | Whether auth was configured |

## Region → inference profile prefix

| AWS region (examples) | Default profile prefix |
|-----------------------|-------------------------|
| `us-east-1`, `us-west-2` | `us` |
| `eu-west-1`, `eu-central-1` | `eu` |
| `ap-southeast-1`, `ap-northeast-1` | `apac` |

Set `inference_profile_id` explicitly if your account uses a different profile ID than the default.

## Example

See [`examples/scenarios/bedrock-sonnet-demo/`](../../examples/scenarios/bedrock-sonnet-demo/).
