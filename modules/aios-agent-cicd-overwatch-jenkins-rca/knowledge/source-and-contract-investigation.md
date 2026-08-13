# CICD Overwatch Source And Contract Investigation

Use this document when Jenkins evidence points to a source, build, test, or compatibility failure.

## Evidence To Collect

- Jenkins job name and build number.
- Git repository URL.
- Git ref requested by Jenkins.
- Exact Git commit resolved by Jenkins.
- Changed files at that commit.
- Relevant repository documentation at that commit.
- Build/test/compatibility output from the failed Jenkins job.

## API Contract Compatibility

The demo app repository contains API compatibility documentation. Inspect the repository at the exact Jenkins commit and read:

```text
docs/api-contract-compatibility.md
frontend/contract.json
```

Do not assume the current branch head is the same source that Jenkins built. Use the commit recorded in Jenkins evidence.

## Diagnosis

If a failure appears tied to source control:

- Identify the file or configuration that changed.
- Explain how Jenkins consumed that file.
- Compare the expected build or compatibility rule with the observed output.
- Recommend a source-control fix or rollback path rather than only changing Jenkins parameters.

Avoid hard-coding a root cause from ticket metadata. The same Jenkins stage can fail because of source changes, runtime configuration, credentials, unavailable dependencies, or controller health.
