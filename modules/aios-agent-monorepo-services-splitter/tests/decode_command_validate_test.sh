#!/usr/bin/env bash
# Validates tofu-rendered *_EXECUTE_SERIES_DECODE_COMMAND strings parse under dash/sh,
# read B64 from sidecar env (not inline paste), and round-trip decode.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v tofu >/dev/null 2>&1; then
  echo "SKIP: decode_command_validate_test requires OpenTofu (tofu) in PATH" >&2
  exit 0
fi

tofu init -backend=false -input=false >/dev/null 2>&1 || true

WF="wf-decode-command-validate-test"

ROOT="${ROOT}" WF="${WF}" python3 << 'PY'
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(os.environ["ROOT"])
wf = os.environ["WF"]

decode_specs = [
    ("scan", "local.monosplit_scan_execute_series_decode_command", "MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2", "local.monosplit_scan_execute_series_b64"),
    ("guidance_pr", "local.monosplit_guidance_pr_execute_series_decode_command", "MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64_V2", "local.monosplit_guidance_pr_execute_series_b64"),
    ("scaffold", "local.monosplit_scaffold_execute_series_decode_command", "MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64_V2", "local.monosplit_scaffold_execute_series_b64"),
    ("extract_pr", "local.monosplit_extract_pr_execute_series_decode_command", "MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64_V2", "local.monosplit_extract_pr_execute_series_b64"),
]

main_tf = (root / "main.tf").read_text()
if "MONOSPLIT_B64=" in main_tf:
    print("FAIL: decode commands must not assign inline MONOSPLIT_B64= (use sidecar env)", file=sys.stderr)
    sys.exit(1)
if "MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2" not in main_tf.split("env_vars = {", 1)[1].split("}", 1)[0]:
    print("FAIL: ubuntu integration env_vars must set MONOSPLIT_*_EXECUTE_SERIES_B64_V2", file=sys.stderr)
    sys.exit(1)

has_shellcheck = shutil.which("shellcheck") is not None


def tofu_render(expr: str) -> str:
    query = f'replace({expr}, "{{{{workflow_run_id}}}}", "{wf}")'
    raw = subprocess.check_output(
        ["tofu", "console", "-input=false"],
        input=query,
        text=True,
        cwd=root,
    ).strip()
    return json.loads(raw)


def shell_syntax_ok(shell: str, cmd: str) -> None:
    r = subprocess.run([shell, "-n", "-c", cmd], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"FAIL: {shell} -n: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(1)


def decode_body(cmd: str, env_name: str, b64: str) -> str:
    decode_only = cmd.rsplit("| bash", 1)[0]
    env = os.environ.copy()
    env[env_name] = b64
    r = subprocess.run(["bash", "-c", decode_only], capture_output=True, text=True, env=env)
    if r.returncode != 0:
        print(f"FAIL: base64 decode pipeline: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return r.stdout


def shellcheck_ok(name: str, body: str) -> None:
    if not has_shellcheck:
        return
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as f:
        f.write(body)
        path = f.name
    try:
        r = subprocess.run(
            ["shellcheck", "-s", "bash", "-e", "SC2034,SC2154", path],
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            print(f"FAIL: shellcheck {name}:\n{r.stdout}{r.stderr}", file=sys.stderr)
            sys.exit(1)
    finally:
        os.unlink(path)


for label, decode_expr, env_name, b64_expr in decode_specs:
    cmd = tofu_render(decode_expr)
    b64 = tofu_render(b64_expr)

    if len(cmd) > 600:
        print(f"FAIL: {label} decode command too long ({len(cmd)} chars) — must stay short for LLM paste", file=sys.stderr)
        sys.exit(1)
    if re.search(r"MONOSPLIT_B64=[A-Za-z0-9+/=]{100,}", cmd):
        print(f"FAIL: {label} must not embed inline B64 in decode command", file=sys.stderr)
        sys.exit(1)
    if env_name not in cmd:
        print(f"FAIL: {label} must read {env_name} from sidecar env", file=sys.stderr)
        sys.exit(1)
    if "$$" in cmd:
        print(f"FAIL: {label} decode command contains $$ (PID expansion corrupts shell vars)", file=sys.stderr)
        sys.exit(1)
    if f'printf %s "${env_name}"' not in cmd and f"printf %s \"${env_name}\"" not in cmd:
        print(f"FAIL: {label} must pipe {env_name} through printf", file=sys.stderr)
        sys.exit(1)
    if "missing_b64_env" not in cmd:
        print(f"FAIL: {label} must guard missing sidecar env with missing_b64_env sentinel", file=sys.stderr)
        sys.exit(1)

    if len(b64) > 12000:
        print(f"FAIL: {label} sidecar B64 too large ({len(b64)} bytes)", file=sys.stderr)
        sys.exit(1)

    for shell in ("dash", "sh", "bash"):
        shell_syntax_ok(shell, cmd)

    body = decode_body(cmd, env_name, b64)
    subprocess.run(["bash", "-n"], input=body, text=True, check=True)
    shellcheck_ok(label, body)

    print(f"OK: {label} cmd_len={len(cmd)} b64_len={len(b64)} body_len={len(body)}")

if has_shellcheck:
    print("OK: shellcheck passed on all decoded bootstrap scripts")
else:
    print("WARN: shellcheck not installed; skipped SC checks")

print("OK: tofu-rendered decode commands validated (short paste, sidecar env B64, decode roundtrip)")
PY
