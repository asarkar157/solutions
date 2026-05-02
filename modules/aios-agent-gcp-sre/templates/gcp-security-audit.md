GCP security audit.

## Steps

1. Check public buckets: `gsutil ls -L`
2. Audit IAM: `gcloud projects get-iam-policy`
3. Check firewall rules: `gcloud compute firewall-rules list --filter='sourceRanges:0.0.0.0/0'`
4. Service account key audit
