Draft YAML patches for drift items classified as UPDATE_GIT, ADD_SLO, or DEPRECATE_GIT.

Write files under `WORK_ROOT/openslo-drafts/` preserving repo layout.

For DEPRECATE_GIT, emit a manifest entry with `action: delete` and git_path — runner applies on PR branch.

Emit **`reconcile_draft_files`** manifest.
