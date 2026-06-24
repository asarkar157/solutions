# Engineering Constitution

This repository uses Spec-Driven Development. All feature work must be traceable to specification artifacts.

## Quality and testing

- Features are isolated, testable units with clear boundaries.
- Code changes include unit tests; target ≥ 85% coverage on touched packages.
- TypeScript projects use strict compiler settings.

## Security

- Never commit credentials, tokens, or private keys.
- Validate and sanitize external input.
- Follow least-privilege for IAM and service accounts.

## SDD traceability

- Every PR linking code changes must reference `specs/`, `openspec/changes/`, or `aidlc-docs/`.
- Constitution rules apply to agent-generated code as well as human-authored code.
