#!/usr/bin/env python3
"""
Fail when sg_workflow stage_bindings would trip Guild webhook/schedule readiness.

Guild rejects targets when any workflow stage lacks agent_ref, parallel_agents,
or action_type (WORKFLOW_HAS_UNBOUND_STAGE). The OpenTofu provider allows omitting
agent_ref with a note about runtime auto-resolution; this script catches that
mismatch at commit time.

See stackgen-guild/internal/guild/service/readiness/readiness.go (WorkflowStage.HasAgent).
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = ("modules", "examples")

RESOURCE_RE = re.compile(
    r'resource\s+"(sg_workflow|sg_webhook)"\s+"([^"]+)"\s*\{',
    re.MULTILINE,
)
STAGE_ID_RE = re.compile(r'\bstage_id\s*=\s*"([^"]+)"')
TARGET_WORKFLOW_RE = re.compile(
    r'\btarget_type\s*=\s*"workflow"',
)
TARGET_NAME_WORKFLOW_RE = re.compile(
    r'\btarget_name\s*=\s*sg_workflow\.([^.]+)\.name\b',
)


@dataclass(frozen=True)
class Violation:
    path: Path
    resource_type: str
    resource_addr: str
    workflow_addr: str | None
    stage_id: str
    reason: str
    webhook_addr: str | None = None


def strip_hcl_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def find_matching_brace(text: str, open_index: int) -> int:
    """Return index of closing brace matching text[open_index] == '{'."""
    depth = 0
    in_string = False
    i = open_index
    n = len(text)
    while i < n:
        ch = text[i]
        if in_string:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unbalanced braces at offset {open_index}")


def extract_attr_array_objects(body: str, attr: str) -> list[str] | None:
    m = re.search(rf"\b{re.escape(attr)}\s*=\s*\[", body)
    if not m:
        return None
    start = m.end() - 1  # points at '['
    end = find_matching_bracket(body, start)
    inner = body[start + 1 : end]
    objects = split_top_level_objects(inner)
    return objects


def find_matching_bracket(text: str, open_index: int) -> int:
    depth = 0
    in_string = False
    i = open_index
    n = len(text)
    while i < n:
        ch = text[i]
        if in_string:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            i += 1
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unbalanced brackets at offset {open_index}")


def split_top_level_objects(array_inner: str) -> list[str] | None:
    stripped = array_inner.strip()
    if not stripped:
        return []
    if stripped[0] != "{":
        # concat(), local.*, etc. — cannot static-check
        return None
    objects: list[str] = []
    i = 0
    n = len(array_inner)
    while i < n:
        while i < n and array_inner[i] in " \t\r\n,":
            i += 1
        if i >= n:
            break
        if array_inner[i] != "{":
            return None
        end = find_matching_brace(array_inner, i)
        objects.append(array_inner[i : end + 1])
        i = end + 1
    return objects


def binding_has_agent(binding: str) -> bool:
    if re.search(r"\baction_type\s*=", binding):
        return True
    if re.search(r"\bagent_ref\s*=\s*(\"\"|null)\b", binding):
        return False
    if re.search(r"\bagent_ref\s*=", binding):
        return True
    m = re.search(r"\bparallel_agents\s*=\s*\[", binding)
    if not m:
        return False
    start = m.end() - 1
    end = find_matching_bracket(binding, start)
    inner = binding[start + 1 : end].strip()
    return bool(inner)


def stage_ids_from_objects(objects: list[str]) -> list[str]:
    ids: list[str] = []
    for obj in objects:
        m = STAGE_ID_RE.search(obj)
        if m:
            ids.append(m.group(1))
    return ids


def bindings_by_stage(bindings: list[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for b in bindings:
        m = STAGE_ID_RE.search(b)
        if m:
            out[m.group(1)] = b
    return out


def analyze_workflow(path: Path, addr: str, body: str) -> list[Violation]:
    violations: list[Violation] = []
    stages = extract_attr_array_objects(body, "stages")
    bindings = extract_attr_array_objects(body, "stage_bindings")

    if bindings is None:
        # Non-literal stage_bindings; skip static analysis for this workflow.
        return violations
    if bindings == [] and stages:
        for sid in stage_ids_from_objects(stages):
            violations.append(
                Violation(
                    path=path,
                    resource_type="sg_workflow",
                    resource_addr=addr,
                    workflow_addr=addr,
                    stage_id=sid,
                    reason="stage_bindings is empty but stages defines stages",
                )
            )
        return violations

    by_stage = bindings_by_stage(bindings)
    stage_ids = stage_ids_from_objects(stages) if stages else list(by_stage.keys())

    for sid in stage_ids:
        binding = by_stage.get(sid)
        if binding is None:
            violations.append(
                Violation(
                    path=path,
                    resource_type="sg_workflow",
                    resource_addr=addr,
                    workflow_addr=addr,
                    stage_id=sid,
                    reason="no stage_bindings entry for stage_id",
                )
            )
            continue
        if not binding_has_agent(binding):
            violations.append(
                Violation(
                    path=path,
                    resource_type="sg_workflow",
                    resource_addr=addr,
                    workflow_addr=addr,
                    stage_id=sid,
                    reason="binding has no agent_ref, parallel_agents, or action_type "
                    "(Guild WORKFLOW_HAS_UNBOUND_STAGE)",
                )
            )

    for sid, binding in by_stage.items():
        if sid in stage_ids:
            continue
        if not binding_has_agent(binding):
            violations.append(
                Violation(
                    path=path,
                    resource_type="sg_workflow",
                    resource_addr=addr,
                    workflow_addr=addr,
                    stage_id=sid,
                    reason="stage_bindings entry is not agent-bound",
                )
            )
    return violations


def analyze_file(path: Path) -> tuple[list[Violation], dict[str, list[str]]]:
    raw = path.read_text(encoding="utf-8")
    text = strip_hcl_comments(raw)
    violations: list[Violation] = []
    webhook_targets: dict[str, list[str]] = {}

    for m in RESOURCE_RE.finditer(text):
        rtype, addr = m.group(1), m.group(2)
        open_brace = text.find("{", m.end() - 1)
        close_brace = find_matching_brace(text, open_brace)
        body = text[open_brace + 1 : close_brace]

        if rtype == "sg_workflow":
            violations.extend(analyze_workflow(path, addr, body))
        elif rtype == "sg_webhook":
            if not TARGET_WORKFLOW_RE.search(body):
                continue
            tm = TARGET_NAME_WORKFLOW_RE.search(body)
            if not tm:
                continue
            wf_addr = tm.group(1)
            webhook_targets.setdefault(wf_addr, []).append(addr)

    return violations, webhook_targets


def scan_tree(root: Path) -> list[Violation]:
    all_v: list[Violation] = []
    for sub in SCAN_DIRS:
        base = root / sub
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.tf")):
            violations, webhook_targets = analyze_file(path)
            for v in violations:
                if v.workflow_addr in webhook_targets:
                    all_v.append(
                        Violation(
                            path=v.path,
                            resource_type=v.resource_type,
                            resource_addr=v.resource_addr,
                            workflow_addr=v.workflow_addr,
                            stage_id=v.stage_id,
                            reason=v.reason,
                            webhook_addr=webhook_targets[v.workflow_addr][0],
                        )
                    )
                else:
                    all_v.append(v)
    return all_v


def _self_test() -> None:
    good = """
resource "sg_workflow" "wf" {
  stages = [{ stage_id = "a", required = true }]
  stage_bindings = [{ stage_id = "a", agent_ref = sg_agent.x.name }]
}
"""
    bad = """
resource "sg_workflow" "wf" {
  stages = [{ stage_id = "cloud-triage", required = true }]
  stage_bindings = [{ stage_id = "cloud-triage", skill_refs = ["x"] }]
}
resource "sg_webhook" "wh" {
  target_type = "workflow"
  target_name = sg_workflow.wf.name
}
"""
    text = strip_hcl_comments(good)
    m = RESOURCE_RE.search(text)
    open_brace = text.find("{", m.end() - 1)
    close_brace = find_matching_brace(text, open_brace)
    assert not analyze_workflow(Path("t.tf"), "wf", text[open_brace + 1 : close_brace])

    raw_bad = strip_hcl_comments(bad)
    v2: list[Violation] = []
    wh: dict[str, list[str]] = {}
    for m in RESOURCE_RE.finditer(raw_bad):
        rtype, addr = m.group(1), m.group(2)
        open_brace = raw_bad.find("{", m.end() - 1)
        close_brace = find_matching_brace(raw_bad, open_brace)
        body = raw_bad[open_brace + 1 : close_brace]
        if rtype == "sg_workflow":
            v2.extend(analyze_workflow(Path("t.tf"), addr, body))
        elif rtype == "sg_webhook":
            tm = TARGET_NAME_WORKFLOW_RE.search(body)
            if tm:
                wh.setdefault(tm.group(1), []).append(addr)
    assert v2 and v2[0].stage_id == "cloud-triage"


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        _self_test()
        print("verify-workflow-stage-bindings: self-test ok")
        return 0

    violations = scan_tree(ROOT)
    if not violations:
        print(
            "verify-workflow-stage-bindings: ok "
            f"(scanned {', '.join(SCAN_DIRS)}/**/*.tf)"
        )
        return 0

    print(
        "verify-workflow-stage-bindings: found stage binding(s) that would fail "
        "Guild readiness (WORKFLOW_HAS_UNBOUND_STAGE):\n"
    )
    for v in violations:
        loc = f"{v.path}:{v.resource_type}.{v.resource_addr}"
        extra = ""
        if v.webhook_addr:
            extra = f" (referenced by sg_webhook.{v.webhook_addr})"
        print(f"  ✗ {loc} stage_id={v.stage_id!r}{extra}")
        print(f"      {v.reason}")
        print(
            "      fix: set stage_bindings[*].agent_ref, parallel_agents, or action_type"
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
