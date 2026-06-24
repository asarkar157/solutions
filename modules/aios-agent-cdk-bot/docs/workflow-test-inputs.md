# CDK bot workflow test inputs

Manual / blackbox testing for `cdk-app-update`.

## Triggers

| Source | `event_type` | Workflow |
|--------|--------------|----------|
| GitHub issue opened | `issue.created` | `cdk-app-update` |
| GitHub PR opened | `pull_request.opened` | `cdk-app-update` |

Webhook filter: `issue.created`, `pull_request.opened`.

**Ingress:** module output `webhook_ingress_payload_url` — `POST {stackgen_url}/guild/api/v1/webhooks/trigger?apiKey=…&orgId=…` (GitHub Payload URL). Not `{stackgen_url}/api/v1/webhooks/trigger` on public StackGen hosts.

## Planner note keys

| Note key | Webhook JSON source |
|----------|---------------------|
| `repository_full_name` | `repository.full_name` |
| `repository_clone_url` | `repository.clone_url` |
| `repository_default_branch` | `repository.default_branch` |
| `issue_or_pr_number` | `issue.number` or `pull_request.number` |
| `issue_labels` | `issue.labels[].name` |
| `pr_head_ref` | `pull_request.head.ref` |

## Test matrix

| ID | Fixture | Trigger | Title | Labels | Expected |
|----|---------|---------|-------|--------|----------|
| **G1** | `generic-typescript` | issue | `G1 greenfield: VersionedArchiveBucket {token}` | — | **Preferred greenfield** — new `lib/gf-archive-bucket-{token}.ts` + matching test; no edits to `sample-stack.ts`; draft PR on `cdk-bot/gf-{token}` |
| T1 | `generic-typescript` | issue | Add S3 bucket construct with versioning | — | Greenfield → validate → draft PR (legacy; vague scope) |
| T2 | `generic-typescript` | issue | Fix encryption on SampleStack | — | Edit `lib/sample-stack.ts` |
| T3 | `catalog-typescript` | issue | `aws_s3_versioned_bucket` | `cdk-construct-request` | Template I catalog scaffold |
| T4 | `catalog-typescript` | issue | same | *(none)* | Label gate blocked |
| T5 | `generic-typescript` | PR | touches `lib/` | — | Edit from diff |
| T6 | `generic-python` | issue | Add Lambda construct | — | Python validate path |
| T7 | any + AWS | issue | vpc from lookup | — | AWS synth when `enable_aws_validation` |

## Sample payload (G1 greenfield — preferred)

Trigger via scenario script (creates GitHub issue + webhook):

```bash
cd examples/scenarios/cdk-bot
./scripts/trigger-greenfield-g1.sh --repo your-org/cdk-typescript-demo
```

Issue body uses a unique run token and explicit file paths so implement cannot no-op on an existing file.

## Sample payload (T1 — legacy)

```json
{
  "action": "opened",
  "issue": {
    "number": 42,
    "title": "Add S3 bucket construct with versioning",
    "body": "Greenfield L3 construct under lib/. Include assertion tests.",
    "labels": []
  },
  "repository": {
    "full_name": "your-org/cdk-typescript-demo",
    "clone_url": "https://github.com/your-org/cdk-typescript-demo.git",
    "default_branch": "main"
  }
}
```

## Assert (happy path)

- Workflow completes without `clone_blocker=*`
- A **single** GitHub issue comment updates through stages (look for `### cdk-bot workflow progress` table) when `enable_progress_issue_comment=true` (default)
- Issue comment includes `module_quality_summary: PASS` and draft PR URL (final progress PATCH or Template E when progress disabled)
- All six quality sentinels PASS: lint, typecheck, synth, cfn-lint, test, nag

Fixtures: `examples/fixtures/cdk-repos/`.
