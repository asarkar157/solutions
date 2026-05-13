Identify S3 buckets that have not been written to recently.

## Steps

1. List every bucket in the account (`aws s3api list-buckets`).
2. For each bucket, fetch the **most recent object** `LastModified` (use
   `aws s3api list-objects-v2 --max-items 1 --query 'sort_by(Contents, &LastModified)[-1]'`)
   and the CloudWatch `AWS/S3` `BucketSizeBytes` trend over
   **{{inactivity_days}}** days (default 30).
3. Flag buckets where the newest object is older than the inactivity window
   AND the size trend is flat OR shrinking.
4. Annotate with: bucket name, region, current size, object count, owner tag,
   storage class mix, public-access status, replication target (if any), and
   estimated monthly cost.
5. Always **EXCLUDE** buckets that:
   - Carry `aios:cleanup:exempt=true` or `do-not-delete=true`
   - Are the target of an active S3 replication rule
   - Host CloudTrail, Config, or other compliance log destinations
   - Are referenced by a CloudFront distribution as an origin
6. Output a structured table: `bucket | region | last_object_modified |
   size_bytes | owner | est_monthly_usd | replication_role | recommendation`.

## Notes

- Some buckets receive writes only via lifecycle transitions; check
  `LifecycleConfiguration` before recommending deletion.
- For **versioned** buckets, also check the newest **noncurrent** version
  date; a bucket can appear stale at the current-version layer while still
  retaining costly noncurrent objects.
