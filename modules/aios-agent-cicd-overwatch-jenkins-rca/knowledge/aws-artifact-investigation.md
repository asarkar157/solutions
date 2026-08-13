# CICD Overwatch AWS And Artifact Investigation

Use this document when Jenkins evidence points to an image, registry, artifact, deployment, or cloud-side dependency issue.

## Approach

Use the AWS integration to inspect relevant systems based on Jenkins evidence. The exact service may vary by failure. Follow the image URI, digest, repository, deployment target, and environment identifiers emitted by Jenkins.

Do not assume the issue is limited to one AWS service before reading the evidence. A registry-looking failure can also be caused by credentials, repository policy, tag immutability, missing image tags, network access, deployment references, or stale build parameters.

## Evidence To Collect

- Jenkins image build and push output.
- Image URI, tag, and digest when available.
- Artifact or deployment identifiers referenced by downstream jobs.
- AWS resource state for systems related to the failed artifact or deployment path.
- Any authorization, not-found, throttling, or network errors returned by Jenkins or AWS.

## Diagnosis

Explain whether the primary failure is:

- Artifact missing or mismatched.
- Push/pull authorization failure.
- Registry/repository policy problem.
- Deployment referencing an unavailable artifact.
- Jenkins or credential configuration issue.
- A different AWS-side dependency surfaced by Jenkins logs.

Recommend the smallest safe fix and list verification steps.
