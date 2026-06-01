Read-only CloudFormation pre-deploy review: validate template intent and policy sanity before stack creation or update.

## Stages

1. **validate-template-intent** — Parse template, verify deploy intent, optional cfn-lint.
2. **policy-sanity-check** — IAM, security group, encryption, and exposure policy review.

## Environment

Self-hosted environment label: `${self_hosted_environment_label}`
