# AIOS CCE scripts (shared)

Bash helpers for running [Code Context Engine (CCE)](https://github.com/appcd-dev/cce) on **Ubuntu Guild integrations**. Agent modules embed this pack at `tofu apply` time via `module "cce_scripts"`.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/cce-common.sh` | Install `cce`, lens download from releases, JSON normalization |
| `scripts/cce-scan.sh` | Full-tree scan (`scan`, `scan-use-case`) |
| `scripts/cce-pr-delta.sh` | Base vs head entitlement diff (change-control, pre-deploy-iam-review) |

## Environment

| Variable | Default | Meaning |
|----------|---------|---------|
| `CCE_USE_CASE` | — | Usage guide id (e.g. `sdk-uplift`, `iac-alignment`); also tags reports |
| `CCE_MAPPER_FILE` | — | Local path or `https://` URL passed to `cce -mapper-file` (CCE downloads remote YAML) |
| `CCE_LENS_BASE_URL` | `https://releases.stackgen.com/cce/lenses` | Lens catalog root ([index.json](https://releases.stackgen.com/cce/lenses/index.json)) |
| `CCE_LENS_CHANNEL` | `latest` | Version folder under each use case (`latest` or release tag e.g. `v0.1.0`) |
| `CCE_LANGUAGE` | `AUTO` | `GO`, `JAVA`, `JAVASCRIPT`, `PYTHON`, `AUTO` |
| `CCE_FILTER` | `cloud` (built-in) / `all` (custom lens) | CCE `-filter` |
| `SKIP_CCE` | — | Skip scan (`scan_status: skipped`) |
| `CCE_VERSION` | `0.0.4` | Binary version from StackGen releases |

Built-in mapper use cases (no lens download): `change-control`, `cloud-entitlements`, `pre-deploy-iam-review`.

## Examples

```bash
# Built-in cloud entitlements (PoLP)
bash cce-scan.sh scan /path/to/repo /tmp/cce_report.json

# Custom lens from releases (main channel)
CCE_USE_CASE=regulatory-scope bash cce-scan.sh scan-use-case /path/to/repo regulatory-scope /tmp/reg.json

# Pinned lens channel or direct mapper URL
CCE_LENS_CHANNEL=v0.1.0 CCE_USE_CASE=sdk-uplift bash cce-scan.sh scan-use-case /repo sdk-uplift /tmp/out.json
CCE_MAPPER_FILE="https://releases.stackgen.com/cce/lenses/prowler/latest/prowler.yaml" \
  bash cce-scan.sh scan /path/to/prowler /tmp/prowler.json

# PR delta (built-in mapper; CCE_USE_CASE labels the report)
bash cce-pr-delta.sh delta "$WORK_ROOT/repo" origin/main HEAD "$WORK_ROOT"
```

## Agent wiring

See [`docs/cce-agent-integrations.md`](../../docs/cce-agent-integrations.md) for which AIOS agent modules use which CCE [usage guides](https://github.com/appcd-dev/cce/tree/main/docs/usages).

After changing scripts, bump `local.cce_pack_version` in `pack.tf` and re-apply agent modules so Ubuntu receives a new `CCE_PACK_B64`.
