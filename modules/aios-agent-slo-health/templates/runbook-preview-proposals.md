Preview bootstrap proposals before opening a PR.

## Steps

1. Summarize each validated proposal in plain English.
2. Show proposed file paths under `openslo/slos/`.
3. Require workflow input **`confirm_pr=true`** (or HITL approval) before downstream open-slo-pr stage proceeds.
4. `note("preview_ready", "true")` and `note("confirm_pr_required", "true")`.

If operator did not confirm, emit `stage_summary:preview=awaiting_confirm` and stop.
