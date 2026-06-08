Render a developer-facing outcome summary via **final-intent-summary-runner** (script — no LLM prose).

1. Spawn exactly one **final-intent-summary-runner** using the spawn-context **Render final summary command**.
2. When upstream input contains blocker tokens, write the last 4KB to `WORK_ROOT/final_stage_input.txt` before running the script.
3. Mirror the script markdown stdout as stage output (≤45 lines).
4. FORBIDDEN: `load_skill`, `read_notes`, LLM-generated summaries.

The script reads `WORK_ROOT/requirements_spec.json`, `WORK_ROOT/pr_url.txt`, and optional blocker signals.
