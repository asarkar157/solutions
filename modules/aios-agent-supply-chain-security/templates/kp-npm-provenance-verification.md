Technical details of npm provenance verification using OIDC, SLSA, and sigstore.

NPM PROVENANCE OVERVIEW:
- npm provenance links a published package version to its source repository
  and build instructions via a signed attestation.
- Publishers use 'npm publish --provenance' which generates a SLSA build
  provenance attestation signed by sigstore's Fulcio CA.

VERIFICATION COMMANDS:
1. Check all packages: npm audit signatures
2. Manual Rekor lookup: rekor-cli search --sha <package-sha256>
3. Verify sigstore bundle: cosign verify-blob --bundle <attestation.json>

SLSA LEVELS:
- SLSA 1: Documentation of build process (minimum)
- SLSA 2: Hosted build platform + authenticated provenance (recommended)
- SLSA 3: Hardened build platform + non-falsifiable provenance
- SLSA 4: Two-party review + hermetic builds (highest)

RED FLAGS:
- Package published without provenance when previous versions had it
- Provenance source repo doesn't match package README/homepage
- Build identity doesn't match expected CI/CD platform
- Attestation timestamp doesn't align with GitHub release timestamp
