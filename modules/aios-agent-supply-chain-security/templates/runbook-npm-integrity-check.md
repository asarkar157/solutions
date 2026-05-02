Verify OIDC/SLSA provenance for all npm packages in a repository.

## Steps

1. Clone repository: `git clone --depth 1 https://github.com/<org>/<repo>.git`
2. Run npm audit signatures: `npm audit signatures 2>&1`
3. List unverified packages: `npm audit signatures 2>&1 | grep -i "missing"`
4. Check Rekor transparency log for each unverified package
5. Check if package was recently published: `npm view <package>@<version> time --json`
6. Check maintainer history: `npm view <package> maintainers --json`
7. **Flag:** missing provenance, recently published by new maintainer, mismatched source repo
8. **Output:** package name, version, provenance status, risk level
