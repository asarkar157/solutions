Discover reusable patterns from the company template catalog, generate CloudFormation YAML aligned with NFRs, and verify hardened synthesis in one pass.

1. Read `WORK_ROOT/requirements_spec.json` — especially `target_rps`, `workload_class`, `sla_availability`, `p99_latency_ms`, `environment`.
2. Read `WORK_ROOT/generated/catalog_candidates.json` when present — **compose** from the highest-scoring catalog path when score ≥ 3; cite the catalog path in stage output.
3. When no catalog match with score ≥ 3, greenfield templates are capped at **${max_template_lines} lines / 30 AWS resources** — use nested stacks or catalog references for high-throughput workloads.
4. Apply tagging, encryption, IAM least privilege, logging, and network patterns from catalog templates and `${knowledge_base_path}`.
5. Write generated template to `WORK_ROOT/generated/template.yaml` only — avoid duplicating full YAML in notes or session notes.
6. Self-review against architecture anti-patterns embedded below (and in runbook inline skills) before marking complete.
7. **FORBIDDEN:** `load_skill`, `read_notes` when `WORK_ROOT/requirements_spec.json` and `WORK_ROOT/generated/catalog_candidates.json` exist.
8. **Stage output ≤8 lines**: `template_generated=true`, `template_path=`, optional blocker keys only.
