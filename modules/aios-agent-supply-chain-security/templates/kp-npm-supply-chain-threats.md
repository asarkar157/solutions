Comprehensive knowledge of npm supply chain attack patterns, detection techniques,
and defense strategies.

KNOWN ATTACK PATTERNS:
1. Axios (2025) — Malicious versions published without OIDC/SLSA provenance.
   Injected 'plain-crypto-js' phantom dependency for data exfiltration via
   postinstall script. Detection: missing provenance + phantom dependency.
2. event-stream (2018) — Maintainer handoff attack. New maintainer added
   'flatmap-stream' dependency targeting cryptocurrency wallet theft.
   Detection: new maintainer + new transitive dependency.
3. ua-parser-js (2021) — Account takeover. Cryptominer and credential
   stealer injected via postinstall script. Detection: unexpected binary
   download in postinstall.
4. node-ipc (2022) — Protestware. Geo-targeted file deletion payload in
   postinstall hook. Detection: geolocation API calls + filesystem writes.
5. colors/faker (2022) — Maintainer sabotage. Infinite loop injected.
   Detection: CPU spike during import, no network activity.

DETECTION SIGNALS:
- Missing npm provenance (OIDC/SLSA attestation absent from Rekor log)
- Phantom dependencies (declared in package.json but never imported)
- New/changed maintainer on popular package within last 7 days
- Postinstall scripts that download binaries or access non-registry URLs
- Typosquatting: package names within edit distance 1 of popular packages

DEFENSE TOOLS:
- npm audit signatures — verify provenance attestations
- npm audit — check for known vulnerabilities (CVE database)
- socket.dev — real-time supply chain threat detection
- depcheck — detect unused/phantom dependencies
- lockfile-lint — enforce lockfile integrity policies
