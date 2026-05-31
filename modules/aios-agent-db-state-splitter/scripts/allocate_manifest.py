#!/usr/bin/env python3
"""Deterministic monolith tfstate → logical_group_manifest + per-group state shards.

Designed for brownfield splits where each group must `tofu plan` with no unexpected
changes: dependency-connected partitioning, shared-hub isolation, tag boundaries only
when the subgraph is tag-disconnected, and physical state slices under groups/<id>/.
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict, deque
from typing import Dict, Iterable, List, Optional, Set, Tuple

TAG_KEYS = (
    "adsk:moniker",
    "adsk:service",
    "app",
    "service",
    "team",
    "Application",
    "application",
    "cost-center",
    "environment",
    "env",
)

# Org-wide types often referenced across service boundaries — isolate when fan-in is high.
SHARED_TYPE_MARKERS = (
    "aws_iam_role",
    "aws_iam_policy",
    "aws_iam_instance_profile",
    "aws_kms_key",
    "aws_kms_alias",
    "aws_cloudwatch_log_group",
    "aws_s3_bucket",  # only when high fan-in; type alone is not enough
)

HUB_INDEGREE_THRESHOLD = 10
HUB_MIN_TYPE_FANIN = 5

# cap <= 0 means no artificial per-AppStack size limit (connectivity-only partitioning).
UNLIMITED_CAP_SENTINEL = 0


def normalize_cap(cap: int, resource_count: int) -> int:
    """Map operator cap to an effective ceiling used by merge/split helpers."""
    if cap <= UNLIMITED_CAP_SENTINEL:
        return max(resource_count, 1)
    return cap


def cap_label(cap: int) -> str:
    if cap <= UNLIMITED_CAP_SENTINEL:
        return "unlimited"
    return str(cap)


def cloud_hint(rtype: str) -> str:
    if rtype.startswith("aws_"):
        return "aws"
    if rtype.startswith("azurerm_") or rtype.startswith("azapi_"):
        return "azure"
    if rtype.startswith("google_"):
        return "gcp"
    return "unknown"


def instance_address(res: dict, inst: dict) -> str:
    if inst.get("address"):
        return inst["address"]
    if res.get("address"):
        base = res["address"]
        idx = inst.get("index_key")
        if idx is None:
            return base
        if isinstance(idx, int):
            return f"{base}[{idx}]"
        return f'{base}["{idx}"]'
    module = (res.get("module") or "").strip()
    base = f"{res['type']}.{res['name']}"
    if module:
        base = f"{module}.{base}"
    idx = inst.get("index_key")
    if idx is None:
        return base
    if isinstance(idx, int):
        return f"{base}[{idx}]"
    return f'{base}["{idx}"]'


def iter_managed_instances(state: dict) -> Iterable[Tuple[dict, dict, str]]:
    """Yield (resource_block, instance, canonical_address) for each managed instance."""
    for res in state.get("resources") or []:
        if res.get("mode") != "managed":
            continue
        insts = res.get("instances") or []
        if not insts:
            addr = res.get("address") or f"{res.get('type', 'unknown')}.{res.get('name', 'x')}"
            yield res, {}, addr
            continue
        for inst in insts:
            if inst.get("deposed"):
                continue
            status = inst.get("status")
            if status and status not in ("", "ready", "tainted"):
                continue
            yield res, inst, instance_address(res, inst)


def extract_tags(res: dict, inst: dict) -> dict:
    attrs = inst.get("attributes") or {}
    for key in ("tags", "tags_all", "default_tags"):
        val = attrs.get(key)
        if isinstance(val, dict) and val:
            return val
    for inst2 in res.get("instances") or [inst]:
        attrs = inst2.get("attributes") or {}
        for key in ("tags", "tags_all", "default_tags"):
            val = attrs.get(key)
            if isinstance(val, dict) and val:
                return val
    return {}


def extract_dependencies(inst: dict) -> Set[str]:
    return set(inst.get("dependencies") or [])


def seed_key(tags: dict, rtype: str) -> str:
    for tk in TAG_KEYS:
        v = tags.get(tk)
        if v:
            return f"tag:{tk}={v}"
    parts = rtype.split("_")
    return f"type:{parts[1] if len(parts) > 1 else rtype}"


def build_adjacency(addresses: Set[str], deps_map: Dict[str, Set[str]]) -> Dict[str, Set[str]]:
    """Build undirected adjacency for addresses, ignoring deps outside the vertex set."""
    adj = {a: set() for a in addresses}
    for addr, deps in deps_map.items():
        if addr not in adj:
            continue
        for d in deps:
            if d not in adj:
                continue
            adj[addr].add(d)
            adj[d].add(addr)
    return adj


def compute_indegree(addresses: Set[str], deps_map: Dict[str, Set[str]]) -> Dict[str, int]:
    indegree: Dict[str, int] = defaultdict(int)
    for addr, deps in deps_map.items():
        if addr not in addresses:
            continue
        for d in deps:
            if d in addresses:
                indegree[d] += 1
    return indegree


def is_shared_hub(addr: str, meta: dict, indegree: int) -> bool:
    rtype = meta[addr]["type"]
    if indegree >= HUB_INDEGREE_THRESHOLD:
        return True
    if rtype in SHARED_TYPE_MARKERS and indegree >= HUB_MIN_TYPE_FANIN:
        return True
    if rtype == "aws_s3_bucket" and indegree >= HUB_INDEGREE_THRESHOLD:
        return True
    return False


def connected_components(vertices: Set[str], adj: Dict[str, Set[str]]) -> List[Set[str]]:
    seen: Set[str] = set()
    out: List[Set[str]] = []
    for v in sorted(vertices):
        if v in seen:
            continue
        stack = [v]
        comp: Set[str] = set()
        while stack:
            n = stack.pop()
            if n in seen:
                continue
            seen.add(n)
            comp.add(n)
            for nb in adj.get(n, ()):
                if nb not in seen:
                    stack.append(nb)
        out.append(comp)
    return out


def can_tag_subdivide(component: Set[str], seed_keys: Dict[str, str], adj: Dict[str, Set[str]]) -> bool:
    """Only subdivide by tag when no dependency edge crosses tag boundaries."""
    tags_present = {seed_keys[a] for a in component}
    if len(tags_present) <= 1:
        return False
    for a in component:
        for nb in adj.get(a, ()):
            if nb in component and seed_keys[a] != seed_keys[nb]:
                return False
    return True


def tag_subdivide(component: Set[str], seed_keys: Dict[str, str]) -> List[Set[str]]:
    buckets: Dict[str, Set[str]] = defaultdict(set)
    for addr in component:
        buckets[seed_keys[addr]].add(addr)
    return [set(v) for v in buckets.values()]


def merge_small_by_seed(
    work_sets: List[Set[str]],
    cap: int,
    seed_keys: Dict[str, str],
) -> List[Set[str]]:
    """Merge small (<= cap) work sets into seed-key buckets without splitting connectivity.

    - Work sets larger than *cap* pass through unchanged (handled by cap_split_bfs).
    - Multi-seed connected components (e.g. vpc + subnet) stay intact.
    - Single-seed components at or under *cap* are bin-packed across disconnected
      components that share the same seed key.
    """
    large: List[Set[str]] = [ws for ws in work_sets if len(ws) > cap]
    small_sets = [ws for ws in work_sets if len(ws) <= cap]

    keep_intact: List[Set[str]] = []
    by_seed: Dict[str, List[Set[str]]] = defaultdict(list)

    for ws in small_sets:
        seeds = {seed_keys[a] for a in ws}
        if len(seeds) == 1:
            by_seed[next(iter(seeds))].append(ws)
            continue
        keep_intact.append(ws)

    merged: List[Set[str]] = list(large) + keep_intact
    for sk in sorted(by_seed.keys()):
        addrs: List[str] = []
        for ws in by_seed[sk]:
            addrs.extend(sorted(ws))
        for i in range(0, len(addrs), cap):
            merged.append(set(addrs[i : i + cap]))
    return merged


def cap_split_bfs(
    component: Set[str],
    adj: Dict[str, Set[str]],
    cap: int,
    seed_keys: Dict[str, str],
) -> List[Set[str]]:
    if len(component) <= cap:
        return [set(component)]
    remaining = set(component)
    chunks: List[Set[str]] = []

    def degree(a: str) -> int:
        return len(adj.get(a, set()) & remaining)

    while remaining:
        if len(remaining) <= cap:
            chunks.append(set(remaining))
            break
        seed = max(remaining, key=lambda a: (degree(a), a))
        target_sk = seed_keys.get(seed, "")
        chunk: Set[str] = set()
        q: deque[str] = deque([seed])
        while q and len(chunk) < cap:
            n = q.popleft()
            if n not in remaining or n in chunk:
                continue
            chunk.add(n)
            neighbors = sorted(
                adj.get(n, set()) & remaining - chunk,
                key=lambda x: (seed_keys.get(x, "") != target_sk, -degree(x), x),
            )
            q.extend(neighbors)
        remaining -= chunk
        chunks.append(chunk)
    return chunks


def type_chunk_split(addresses: List[str], cap: int, meta: Dict[str, dict]) -> List[Set[str]]:
    ordered = sorted(addresses, key=lambda a: (meta[a]["type"], a))
    return [set(ordered[i : i + cap]) for i in range(0, len(ordered), cap)]


def load_state_index(state_path: str) -> Tuple[dict, Dict[str, dict], Dict[str, Set[str]], Dict[str, dict]]:
    with open(state_path, encoding="utf-8") as fh:
        state = json.load(fh)

    meta: Dict[str, dict] = {}
    deps_map: Dict[str, Set[str]] = {}
    inst_index: Dict[str, dict] = {}  # address -> {res, inst}

    for res, inst, addr in iter_managed_instances(state):
        rtype = res.get("type") or ""
        tags = extract_tags(res, inst)
        sk = seed_key(tags, rtype)
        cloud = cloud_hint(rtype)
        meta[addr] = {
            "type": rtype,
            "cloud": cloud,
            "seed_key": sk,
            "tags": tags,
            "module": res.get("module") or "",
        }
        deps_map[addr] = extract_dependencies(inst)
        inst_index[addr] = {"res": res, "inst": inst}

    return state, meta, deps_map, inst_index


def allocate(state_path: str, strategy: str, cap: int) -> Tuple[dict, dict, dict]:
    state, meta, deps_map, _inst_index = load_state_index(state_path)
    all_addrs = set(meta.keys())
    eff_cap = normalize_cap(cap, len(all_addrs))
    seed_keys = {a: meta[a]["seed_key"] for a in all_addrs}
    by_cloud: Dict[str, Set[str]] = defaultdict(set)
    for addr, m in meta.items():
        by_cloud[m["cloud"]].add(addr)

    manifest: dict = {}
    group_idx = 0

    def next_gid(cloud: str, label: str = "group") -> str:
        nonlocal group_idx
        group_idx += 1
        return f"{cloud}-{label}-{group_idx:03d}"

    if strategy == "type_chunk":
        for cloud in ("aws", "azure", "gcp", "unknown"):
            addrs = sorted(by_cloud[cloud])
            if not addrs:
                continue
            for chunk in type_chunk_split(addrs, eff_cap, meta):
                gid = next_gid(cloud, "chunk")
                manifest[gid] = {
                    "cloud_hint": cloud,
                    "resource_addresses": sorted(chunk),
                    "notes": {"grouping": strategy, "partition": "greedy-chunk"},
                }
        per_group = {gid: len(v["resource_addresses"]) for gid, v in manifest.items()}
        return manifest, per_group, {"monolith_resource_count": len(all_addrs)}

    use_tag_seed = strategy in ("tag_seeded_connectivity_capped", "tag_seeded_connectivity")

    for cloud in ("aws", "azure", "gcp", "unknown"):
        vertices = set(by_cloud[cloud])
        if not vertices:
            continue

        indegree = compute_indegree(vertices, deps_map)
        shared: Set[str] = {a for a in vertices if is_shared_hub(a, meta, indegree.get(a, 0))}
        workload = vertices - shared

        if shared:
            gid = next_gid(cloud, "shared")
            manifest[gid] = {
                "cloud_hint": cloud,
                "resource_addresses": sorted(shared),
                "notes": {
                    "grouping": strategy,
                    "partition": "shared-hub",
                    "role": "org-wide dependencies — hydrate and plan this group before workload shards",
                },
            }

        if not workload:
            continue

        adj = build_adjacency(workload, deps_map)
        components = connected_components(workload, adj)
        work_sets: List[Set[str]] = []

        for comp in components:
            if (
                use_tag_seed
                and cap > UNLIMITED_CAP_SENTINEL
                and len(comp) > eff_cap
                and can_tag_subdivide(comp, seed_keys, adj)
            ):
                work_sets.extend(tag_subdivide(comp, seed_keys))
            else:
                work_sets.append(comp)

        if use_tag_seed:
            work_sets = merge_small_by_seed(work_sets, eff_cap, seed_keys)

        for comp in work_sets:
            if len(comp) <= eff_cap:
                gid = next_gid(cloud, "group")
                notes = {"grouping": strategy, "partition": "connectivity-component"}
                external = sorted(
                    {d for a in comp for d in deps_map.get(a, set()) if d in shared}
                )
                if external:
                    notes["cross_shard_refs"] = external[:30]
                manifest[gid] = {
                    "cloud_hint": cloud,
                    "resource_addresses": sorted(comp),
                    "notes": notes,
                }
                continue

            for chunk in cap_split_bfs(comp, adj, eff_cap, seed_keys):
                gid = next_gid(cloud, "shard")
                notes: dict = {"grouping": strategy, "partition": "bfs-cap-split"}
                cut_hubs = sorted(
                    a for a in chunk if len(adj.get(a, set()) - chunk) > 0
                )
                if cut_hubs:
                    notes["cross_shard_refs"] = cut_hubs[:30]
                external = sorted(
                    {d for a in chunk for d in deps_map.get(a, set()) if d in shared}
                )
                if external:
                    notes["shared_refs"] = external[:30]
                manifest[gid] = {
                    "cloud_hint": cloud,
                    "resource_addresses": sorted(chunk),
                    "notes": notes,
                }

    per_group = {gid: len(v["resource_addresses"]) for gid, v in manifest.items()}
    return manifest, per_group, {"monolith_resource_count": len(all_addrs)}


def reconcile(state_path: str, manifest: dict) -> dict:
    _, meta, _, _ = load_state_index(state_path)
    all_addrs = set(meta.keys())
    allocated: List[str] = []
    for entry in manifest.values():
        allocated.extend(entry.get("resource_addresses") or [])
    allocated_set = set(allocated)
    dupes = len(allocated) - len(allocated_set)
    unallocated = sorted(all_addrs - allocated_set)
    extra = sorted(set(allocated) - all_addrs)
    monolith_count = len(all_addrs)
    aggregate = len(allocated_set & all_addrs)
    ok = dupes == 0 and len(unallocated) == 0 and len(extra) == 0
    return {
        "count_reconciliation_ok": ok,
        "monolith_resource_count": monolith_count,
        "aggregate_group_resource_count": aggregate,
        "duplicate_address_count": dupes,
        "unallocated_resource_count": len(unallocated),
        "unknown_address_count": len(extra),
        "unallocated_sample": unallocated[:10],
    }


def _resource_key(res: dict) -> str:
    module = res.get("module") or ""
    return f"{module}|{res.get('type')}|{res.get('name')}|{res.get('provider')}"


def extract_group_states(state_path: str, work_root: str, manifest: dict) -> dict:
    """Write groups/<group_id>/terraform.tfstate for isolated per-group plan."""
    with open(state_path, encoding="utf-8") as fh:
        state = json.load(fh)

    addr_to_group: Dict[str, str] = {}
    for gid, entry in manifest.items():
        for addr in entry.get("resource_addresses") or []:
            addr_to_group[addr] = gid

    # group_key -> list of (res_template, instance)
    buckets: Dict[str, Dict[str, List[dict]]] = defaultdict(lambda: defaultdict(list))

    for res, inst, addr in iter_managed_instances(state):
        gid = addr_to_group.get(addr)
        if not gid:
            continue
        buckets[gid][_resource_key(res)].append((res, inst))

    paths: Dict[str, str] = {}
    base_meta = {
        k: state.get(k)
        for k in ("version", "terraform_version", "serial", "lineage")
        if k in state
    }

    for gid, res_map in buckets.items():
        out_resources: List[dict] = []
        for _rkey, pairs in res_map.items():
            template = pairs[0][0]
            new_res = {
                k: template[k]
                for k in ("module", "mode", "type", "name", "provider")
                if k in template
            }
            if "address" in template and len(pairs) == 1:
                new_res["address"] = pairs[0][1].get("address") or template.get("address")
            new_res["instances"] = [p[1] for p in pairs if p[1]]
            if new_res["instances"]:
                out_resources.append(new_res)

        shard = {**base_meta, "outputs": {}, "resources": out_resources}
        out_dir = os.path.join(work_root, "groups", gid)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "terraform.tfstate")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(shard, fh, indent=2)
        paths[gid] = out_path

    index_path = os.path.join(work_root, "group_state_paths.json")
    with open(index_path, "w", encoding="utf-8") as fh:
        json.dump(paths, fh, indent=2, sort_keys=True)
    return paths


def write_inventory(state_path: str, work_root: str) -> Tuple[str, str, int]:
    """Emit anchor inventory + seeds for discover stage handoff."""
    state, meta, _, _ = load_state_index(state_path)
    seeds_path = os.path.join(work_root, "logical_group_seeds.json")
    inventory_path = os.path.join(work_root, "db_anchor_inventory.json")

    seeds = [
        {"address": a, "type": m["type"], "group_key": m["seed_key"]}
        for a, m in sorted(meta.items())
    ]
    db_re = re.compile(
        r"aws_db_instance|aws_rds_cluster|aws_dynamodb_table|"
        r"aws_elasticache_cluster|aws_dms_replication_instance|"
        r"azurerm_mssql|azurerm_postgresql|google_sql"
    )
    inventory = [s for s in seeds if db_re.search(s["type"])]

    with open(seeds_path, "w", encoding="utf-8") as fh:
        json.dump(seeds, fh, indent=2)
    with open(inventory_path, "w", encoding="utf-8") as fh:
        json.dump(inventory, fh, indent=2)
    return seeds_path, inventory_path, len(seeds)


def cmd_allocate(work_root: str, state_path: str, strategy: str, cap: int) -> int:
    manifest, per_group, stats = allocate(state_path, strategy, cap)
    manifest_path = os.path.join(work_root, "logical_group_manifest.json")
    counts_path = os.path.join(work_root, "per_group_resource_counts.json")
    shard_path = os.path.join(work_root, "shard_manifest.json")

    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
    with open(shard_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
    with open(counts_path, "w", encoding="utf-8") as fh:
        json.dump(per_group, fh, indent=2, sort_keys=True)

    print(f"logical_group_manifest_path={manifest_path}")
    print(f"group_count={len(manifest)}")
    print(f"aggregate_group_resource_count={sum(per_group.values())}")
    print(f"monolith_resource_count={stats['monolith_resource_count']}")
    print(f"grouping_strategy={strategy}")
    print(f"max_resources_per_appstack={cap_label(cap)}")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "usage: allocate_manifest.py <allocate|reconcile|extract-states|split|inventory> ...",
            file=sys.stderr,
        )
        return 2

    cmd = sys.argv[1]
    if cmd == "allocate":
        work_root, state_path, strategy, cap_s = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
        try:
            cap = int(cap_s) if cap_s else UNLIMITED_CAP_SENTINEL
        except ValueError:
            cap = UNLIMITED_CAP_SENTINEL
        return cmd_allocate(work_root, state_path, strategy, cap)

    if cmd == "reconcile":
        state_path, manifest_path = sys.argv[2], sys.argv[3]
        with open(manifest_path, encoding="utf-8") as fh:
            manifest = json.load(fh)
        result = reconcile(state_path, manifest)
        print(json.dumps(result))
        return 0 if result["count_reconciliation_ok"] else 1

    if cmd == "extract-states":
        state_path, work_root, manifest_path = sys.argv[2], sys.argv[3], sys.argv[4]
        with open(manifest_path, encoding="utf-8") as fh:
            manifest = json.load(fh)
        paths = extract_group_states(state_path, work_root, manifest)
        print(f"group_state_count={len(paths)}")
        print(f"group_state_paths={os.path.join(work_root, 'group_state_paths.json')}")
        return 0

    if cmd == "inventory":
        state_path, work_root = sys.argv[2], sys.argv[3]
        seeds, inv, n = write_inventory(state_path, work_root)
        print(f"logical_group_seeds_path={seeds}")
        print(f"db_anchor_inventory_path={inv}")
        print(f"anchor_seeds_extracted={n}")
        return 0

    if cmd == "split":
        work_root, state_path = sys.argv[2], sys.argv[3]
        strategy = sys.argv[4] if len(sys.argv) > 4 else "tag_seeded_connectivity_capped"
        cap_s = sys.argv[5] if len(sys.argv) > 5 else str(UNLIMITED_CAP_SENTINEL)
        try:
            cap = int(cap_s)
        except ValueError:
            cap = UNLIMITED_CAP_SENTINEL
        write_inventory(state_path, work_root)
        manifest, per_group, stats = allocate(state_path, strategy, cap)
        manifest_path = os.path.join(work_root, "logical_group_manifest.json")
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)
        with open(os.path.join(work_root, "shard_manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)
        with open(os.path.join(work_root, "per_group_resource_counts.json"), "w", encoding="utf-8") as fh:
            json.dump(per_group, fh, indent=2, sort_keys=True)
        extract_group_states(state_path, work_root, manifest)
        result = reconcile(state_path, manifest)
        result_path = os.path.join(work_root, "reconcile_result.json")
        with open(result_path, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2)
        print(f"logical_group_manifest_path={manifest_path}")
        print(f"group_count={len(manifest)}")
        print(f"aggregate_group_resource_count={sum(per_group.values())}")
        print(f"monolith_resource_count={stats['monolith_resource_count']}")
        print(f"grouping_strategy={strategy}")
        print(f"max_resources_per_appstack={cap_label(cap)}")
        print(f"reconcile_result_path={result_path}")
        print(f"count_reconciliation_ok={str(result['count_reconciliation_ok']).lower()}")
        return 0 if result["count_reconciliation_ok"] else 1

    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
