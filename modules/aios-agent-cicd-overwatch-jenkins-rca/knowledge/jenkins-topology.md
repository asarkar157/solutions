# CICD Overwatch Jenkins Topology

The CICD Overwatch demo uses one public Jenkins controller and a set of demo jobs that simulate a release path.

## Public Endpoint

The Jenkins base URL is:

```text
https://d2ehvcgcjcyalf.cloudfront.net
```

The controller is fronted by CloudFront/WAF. A public 502 or unreachable endpoint can indicate a controller or upstream availability problem, not necessarily an authentication problem.

## Jobs

The release demo uses:

- `00-release-pipeline`: parent pipeline view that calls the child jobs as stages.
- `01-build-backend-services`: backend build and backend API contract evidence.
- `02-build-frontend-ui`: frontend build and frontend API requirement evidence.
- `03-package-release-compatibility-review`: compatibility gate and release manifest packaging.
- `04-build-push-image-ecr-scan`: container image build/push and scan evidence.
- `05-predeploy-db-environment-review`: environment, DB, and predeploy checks.
- `06-deploy-smoke-test-evidence`: deploy and smoke-test evidence.

The parent pipeline is useful for a single stage-based timeline. Child job logs are usually better for exact `KEY=value` outputs and failure details.

## Investigation Tips

- Start from the job and build number named in the Linear ticket when present.
- If the parent pipeline failed, inspect the child job corresponding to the failed stage.
- Record both parent and child build numbers if both exist.
- Console logs often contain Git repository URL, ref, commit, release version, image URI, image digest, contract versions, and explicit failure messages.
- If Jenkins is unreachable, verify public endpoint behavior and then use AWS or remote-runner access to inspect the controller host or service state.
