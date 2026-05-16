Cross-reference integrity, sandbox, and manifest findings into a single risk narrative.

## Steps

1. Collect outputs from the integrity-check, behavioral-sandbox, and manifest-anomaly stages.
2. For each flagged package or repo, note: provenance status, sandbox signals (network/files/process), and declared-vs-actual import deltas.
3. Deduplicate: merge duplicate package ids; prefer highest severity signal per package.
4. Map findings to GitHub advisories or maintainer anomalies where applicable (link evidence).
5. **Output:** a ranked table (package → combined risk → evidence pointers → confidence).
