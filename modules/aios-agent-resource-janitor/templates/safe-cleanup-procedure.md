Safe two-phase cleanup procedure: tag-and-quarantine followed by deletion.

## Mandatory order — no skipping

1. **Pre-flight gate**
   - Reload findings from the most recent detection run; abort if older than
     7 days (re-detect first).
   - Refuse to operate on any resource that:
     - Is missing both `Owner` and `Team` tags (require attribution first)
     - Carries `aios:cleanup:exempt=true` or `do-not-delete=true`
     - Is referenced as a target in any active replication, deployment,
       CloudFront origin, route53 alias, or load-balancer target group.
2. **Quarantine phase** (this run)
   - Tag the resource with:
     - `aios:cleanup:scheduled-deletion = <ISO date = today + dwell_days>`
     - `aios:cleanup:detected-by = resource-janitor`
     - `aios:cleanup:run-id = <execution id>`
   - Where the resource type supports rename (Lambda, S3 bucket prefix on
     CloudFront origin labels, EBS volume Name tag, etc.) prefix the name
     with `aios-quarantine-<YYYYMMDD>-`.
   - For S3 buckets, also enable **Object Lock retention notification** by
     setting a lifecycle rule that suspends multi-part uploads.
   - Notify the resource owner via Slack with: resource id, estimated
     monthly cost, planned deletion date, override instructions
     (`add tag aios:cleanup:exempt=true`), and a link to the run note.
   - Stop after **`max_resources_per_run`** resources OR when accumulated
     savings reach **`cleanup_dollar_cap`**, whichever first.
3. **Deletion phase** (a later run, dwell window expired)
   - Re-confirm the `aios:cleanup:scheduled-deletion` date is in the past.
   - Re-confirm the resource still has zero activity (Lambda invocations,
     S3 reads/writes, EBS attachments) since quarantine.
   - Execute deletion through the dangerous-ops policy; the action MUST be
     approved by an operator (HITL). Capture the API response and the final
     resource manifest into the run note for audit.
   - Post a confirmation summary (resource, owner, savings realized) to
     the configured Slack channel.

## Rollback

- For S3 buckets, restore by removing quarantine tags + lifecycle rules.
- For EBS / disks / snapshots, recreate from the most recent backup if a
  rollback is requested **before** the deletion phase.
- Once the deletion phase completes, rollback is **not** possible from
  this agent; redirect the operator to the cloud provider's recycle bin
  (AWS Recycle Bin for snapshots, Azure Soft Delete, GCS soft delete) if
  available.
