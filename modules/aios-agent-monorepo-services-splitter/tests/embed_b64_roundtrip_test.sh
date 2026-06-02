#!/usr/bin/env bash
# Validates Terraform-rendered bootstrap shell: $$ → $ after templatefile, spawn-context B64, bash syntax.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT="$ROOT" python3 << 'PY'
import base64, hashlib, os, pathlib, re, shutil, subprocess, sys, tempfile

root = pathlib.Path(os.environ["ROOT"])
max_b64 = 12000

def read(p):
    return (root / p).read_text()

def tf_render(content, vars_dict):
    """Mirror Terraform templatefile: ${var} substitution; $${ -> ${ only."""
    for k, v in sorted(vars_dict.items(), key=lambda x: -len(str(x[0]))):
        if isinstance(v, str):
            content = content.replace("${%s}" % k, v)
        elif isinstance(v, (int, float)):
            content = content.replace("${%s}" % k, str(v))
    content = re.sub(r"\$\$\{", "${", content)
    return content

def bash_syntax_ok(name, body):
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as f:
        f.write(body)
        path = f.name
    try:
        r = subprocess.run(["bash", "-n", path], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"FAIL: {name} bash -n: {r.stderr.strip()}", file=sys.stderr)
            sys.exit(1)
    finally:
        os.unlink(path)

def assert_no_bad_dollars(name, body):
    if "$$" in body:
        print(f"FAIL: {name} still contains $$ after render", file=sys.stderr)
        sys.exit(1)
    if re.search(r"\d+WORK_ROOT", body):
        print(f"FAIL: {name} has PID+WORK_ROOT corruption pattern", file=sys.stderr)
        sys.exit(1)
    if ".$WORKFLOW_RUN_ID" in body:
        print(f"FAIL: {name} has broken WORKFLOW_RUN_ID path (missing braces)", file=sys.stderr)
        sys.exit(1)

def script_bytes(name):
    return (root / "scripts" / name).read_bytes()


scripts = {
    "stage_runner": read("scripts/stage-runner.sh").strip(),
    "boundary_scan": read("scripts/boundary-scan.sh").strip(),
    "clone_and_pr": read("scripts/clone-and-pr.sh").strip(),
    "scaffold_services": read("scripts/scaffold-services.sh").strip(),
    "agents_md": read("scripts/agents-md-scaffold.sh").strip(),
    "runtime_deps": read("scripts/runtime-deps-provision.sh").strip(),
}
script_sha256 = {
    "stage_runner": hashlib.sha256(script_bytes("stage-runner.sh")).hexdigest(),
    "boundary_scan": hashlib.sha256(script_bytes("boundary-scan.sh")).hexdigest(),
    "clone_and_pr": hashlib.sha256(script_bytes("clone-and-pr.sh")).hexdigest(),
    "scaffold_services": hashlib.sha256(script_bytes("scaffold-services.sh")).hexdigest(),
    "agents_md": hashlib.sha256(script_bytes("agents-md-scaffold.sh")).hexdigest(),
    "runtime_deps": hashlib.sha256(script_bytes("runtime-deps-provision.sh")).hexdigest(),
}

pack_version = re.search(r'script_pack_version\s*=\s*"([^"]+)"', read("main.tf")).group(1)
runner_version = re.search(r'SCRIPT_PACK_VERSION="([^"]+)"', read("scripts/stage-runner.sh")).group(1)
if pack_version != runner_version:
    print(
        f"FAIL: script_pack_version mismatch main.tf={pack_version} stage-runner.sh={runner_version}",
        file=sys.stderr,
    )
    sys.exit(1)

resolve_tpl = read("templates/monosplit-resolve-env.sh.tftpl")
if "monosplit-work" in resolve_tpl:
    print("FAIL: resolve-env must not use shared .monosplit-work fallback", file=sys.stderr)
    sys.exit(1)

vars_base = {
    "ubuntu_integration_home": "/home/integration",
    "script_pack_version": pack_version,
    "script_pack_runner_sha256": script_sha256["stage_runner"],
    "script_pack_boundary_scan_sha256": script_sha256["boundary_scan"],
    "script_pack_clone_and_pr_sha256": script_sha256["clone_and_pr"],
    "script_pack_scaffold_services_sha256": script_sha256["scaffold_services"],
    "script_pack_agents_md_scaffold_sha256": script_sha256["agents_md"],
    "script_pack_runtime_deps_sha256": script_sha256["runtime_deps"],
    "default_branch": "main",
}

resolve = tf_render(resolve_tpl, vars_base)
install_pack = tf_render(read("templates/monosplit-install-script-pack.sh.tftpl"), vars_base)
assert_no_bad_dollars("monosplit-resolve-env", resolve)
bash_syntax_ok("monosplit-resolve-env", resolve)
assert_no_bad_dollars("monosplit-install-script-pack", install_pack)
bash_syntax_ok("monosplit-install-script-pack", install_pack)

vars = {
    **vars_base,
    "monosplit_resolve_env_body": resolve,
    "monosplit_install_script_pack_body": install_pack,
}

embeds = [
    "monosplit-scan-execute-series-embedded.sh.tftpl",
    "monosplit-guidance-pr-execute-series-embedded.sh.tftpl",
    "monosplit-scaffold-execute-series-embedded.sh.tftpl",
    "monosplit-extract-pr-execute-series-embedded.sh.tftpl",
]

main_tf = read("main.tf")
env_block = main_tf.split("env_vars = {", 1)[1].split("}", 1)[0]
if "MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2" not in env_block:
    print("FAIL: ubuntu integration env_vars must set MONOSPLIT_*_EXECUTE_SERIES_B64_V2", file=sys.stderr)
    sys.exit(1)
if "MONOSPLIT_B64=" in main_tf:
    print("FAIL: decode commands must not assign inline MONOSPLIT_B64=", file=sys.stderr)
    sys.exit(1)

decode_suffix = "tr -d '[:space:]' | base64 -d | bash"
if decode_suffix not in main_tf:
    print("FAIL: decode suffix must strip whitespace before base64 -d", file=sys.stderr)
    sys.exit(1)

for name in embeds:
    body = tf_render(read(f"templates/{name}"), vars)
    assert_no_bad_dollars(name, body)
    bash_syntax_ok(name, body)
    if 'WORK_ROOT="$(monosplit_resolve_work_root)" || exit 1' not in body:
        print(f"FAIL: {name} must assign WORK_ROOT via monosplit_resolve_work_root", file=sys.stderr)
        sys.exit(1)
    if 'mkdir -p "$WORK_ROOT/.work"' not in body:
        print(f"FAIL: {name} must mkdir under $WORK_ROOT not corrupted path", file=sys.stderr)
        sys.exit(1)
    b64 = base64.b64encode(body.encode()).decode()
    if "'" in b64:
        print(f"FAIL: {name} B64 must not contain single quotes (decode command wraps in '...')", file=sys.stderr)
        sys.exit(1)
    decoded = base64.b64decode(b64).decode()
    if decoded != body:
        print(f"FAIL: {name} base64 roundtrip failed", file=sys.stderr)
        sys.exit(1)
    if len(b64) > max_b64:
        print(f"FAIL: {name} spawn-context B64 too large ({len(b64)} bytes > {max_b64})", file=sys.stderr)
        sys.exit(1)

    wf = "wf-monorepo-services-split-analysis-dollar-escape-test"
    decode_cmd = (
        f"export WORK_ROOT='/home/integration/.{wf}' WORKFLOW_RUN_ID='{wf}' "
        f"MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2='{b64}' "
        f"&& printf %s \"$MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2\" | {decode_suffix}"
    )
    if "MONOSPLIT_B64=" in decode_cmd:
        print(f"FAIL: {name} must not use inline MONOSPLIT_B64 assignment", file=sys.stderr)
        sys.exit(1)
    if not re.fullmatch(r"[A-Za-z0-9+/=]+", b64):
        print(f"FAIL: {name} B64 must be shell-safe base64 alphabet", file=sys.stderr)
        sys.exit(1)
    if "$$" in decode_cmd:
        print(f"FAIL: {name} decode command shell prefix contains $$", file=sys.stderr)
        sys.exit(1)
    r = subprocess.run(["dash", "-n", "-c", decode_cmd], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"FAIL: {name} decode command dash -n: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    print(f"OK: {name} body={len(body)} b64={len(b64)}")

if "printf %s" not in main_tf:
    print("FAIL: decode commands must read sidecar B64 via printf %s", file=sys.stderr)
    sys.exit(1)

print("OK: sidecar-env bootstrap B64 checks passed")

# Cross-check: OpenTofu templatefile output must match tf_render (no stray $$ in real B64).
if shutil.which("tofu") is not None:
    import json as _json

    subprocess.run(
        ["tofu", "init", "-backend=false", "-input=false"],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    tofu_b64 = _json.loads(
        subprocess.check_output(
            ["tofu", "console", "-input=false"],
            input="local.monosplit_scan_execute_series_b64",
            text=True,
            cwd=root,
        ).strip()
    )
    tofu_body = base64.b64decode(tofu_b64).decode()
    # Tofu console heredoc adds a trailing newline; normalize line endings for comparison.
    py_body = tf_render(read("templates/monosplit-scan-execute-series-embedded.sh.tftpl"), vars)
    if tofu_body.rstrip("\n") != py_body.rstrip("\n"):
        print("FAIL: tofu scan B64 body differs from tf_render mirror", file=sys.stderr)
        sys.exit(1)
    if "$$" in tofu_body:
        print("FAIL: tofu scan B64 body still contains $$ (templatefile escape bug)", file=sys.stderr)
        sys.exit(1)
    print("OK: tofu templatefile scan B64 matches tf_render mirror")
PY
