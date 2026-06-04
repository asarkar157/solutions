#!/usr/bin/env python3
"""Unit tests for allocate_manifest.py deterministic split logic."""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import allocate_manifest as am  # noqa: E402


def _minimal_state(resources: list) -> dict:
    return {
        "version": 4,
        "terraform_version": "1.5.0",
        "resources": resources,
    }


def _managed(rtype: str, name: str, deps: list | None = None, tags: dict | None = None) -> dict:
    attrs = {"tags": tags or {}}
    return {
        "mode": "managed",
        "type": rtype,
        "name": name,
        "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
        "instances": [{"attributes": attrs, "dependencies": deps or []}],
    }


class BuildAdjacencyTests(unittest.TestCase):
    def test_skips_deps_outside_vertex_set(self) -> None:
        vertices = {"aws_vpc.main", "aws_subnet.a"}
        deps = {
            "aws_subnet.a": {"aws_vpc.main", "aws_db_instance.missing"},
        }
        adj = am.build_adjacency(vertices, deps)
        self.assertEqual(adj["aws_subnet.a"], {"aws_vpc.main"})
        self.assertEqual(adj["aws_vpc.main"], {"aws_subnet.a"})


class MergeSmallBySeedTests(unittest.TestCase):
    def test_merges_singletons_by_seed_key(self) -> None:
        seed_keys = {
            "a": "tag:app=one",
            "b": "tag:app=one",
            "c": "tag:app=two",
        }
        work_sets = [{"a"}, {"b"}, {"c"}]
        merged = am.merge_small_by_seed(work_sets, cap=120, seed_keys=seed_keys)
        self.assertEqual(len(merged), 2)
        sizes = sorted(len(s) for s in merged)
        self.assertEqual(sizes, [1, 2])

    def test_preserves_multi_node_connected_component(self) -> None:
        seed_keys = {"aws_vpc.main": "type:vpc", "aws_subnet.a": "type:subnet"}
        work_sets = [{"aws_vpc.main", "aws_subnet.a"}]
        merged = am.merge_small_by_seed(work_sets, cap=120, seed_keys=seed_keys)
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0], {"aws_vpc.main", "aws_subnet.a"})

    def test_chunks_large_seed_bucket_by_cap(self) -> None:
        seed_keys = {f"r{i}": "tag:app=bulk" for i in range(250)}
        work_sets = [{f"r{i}"} for i in range(250)]
        merged = am.merge_small_by_seed(work_sets, cap=120, seed_keys=seed_keys)
        self.assertEqual(len(merged), 3)
        self.assertEqual(sum(len(s) for s in merged), 250)


class AllocateIntegrationTests(unittest.TestCase):
    def test_reconcile_ok_for_disconnected_singletons(self) -> None:
        resources = [
            _managed("aws_glue_job", f"job{i}", tags={"app": "glue"})
            for i in range(50)
        ]
        state = _minimal_state(resources)
        with tempfile.TemporaryDirectory() as td:
            state_path = os.path.join(td, "terraform.tfstate")
            with open(state_path, "w", encoding="utf-8") as fh:
                json.dump(state, fh)
            manifest, _, _ = am.allocate(state_path, "tag_seeded_connectivity_capped", 120)
            result = am.reconcile(state_path, manifest)
            self.assertTrue(result["count_reconciliation_ok"])
            self.assertLess(len(manifest), 50)

    def test_connected_pair_stays_together(self) -> None:
        resources = [
            _managed("aws_vpc", "main"),
            _managed("aws_subnet", "a", deps=["aws_vpc.main"]),
        ]
        state = _minimal_state(resources)
        with tempfile.TemporaryDirectory() as td:
            state_path = os.path.join(td, "terraform.tfstate")
            with open(state_path, "w", encoding="utf-8") as fh:
                json.dump(state, fh)
            manifest, _, _ = am.allocate(state_path, "tag_seeded_connectivity_capped", 120)
            workload_groups = [
                g for g, e in manifest.items() if e.get("notes", {}).get("partition") != "shared-hub"
            ]
            self.assertEqual(len(workload_groups), 1)
            addrs = manifest[workload_groups[0]]["resource_addresses"]
            self.assertEqual(set(addrs), {"aws_vpc.main", "aws_subnet.a"})


class UnlimitedCapTests(unittest.TestCase):
    def test_cap_zero_keeps_connected_pair_single_group(self) -> None:
        resources = [
            _managed("aws_vpc", "main"),
            _managed("aws_subnet", "a", deps=["aws_vpc.main"]),
        ]
        state = _minimal_state(resources)
        with tempfile.TemporaryDirectory() as td:
            state_path = os.path.join(td, "terraform.tfstate")
            with open(state_path, "w", encoding="utf-8") as fh:
                json.dump(state, fh)
            manifest, _, _ = am.allocate(state_path, "tag_seeded_connectivity", 0)
            workload = [
                g for g, e in manifest.items() if e.get("notes", {}).get("partition") != "shared-hub"
            ]
            self.assertEqual(len(workload), 1)

    def test_cap_label_unlimited(self) -> None:
        self.assertEqual(am.cap_label(0), "unlimited")
        self.assertEqual(am.cap_label(120), "120")

    def test_infer_aws_region_from_state(self) -> None:
        state = _minimal_state([
            _managed("aws_s3_bucket", "a", tags={}),
        ])
        state["resources"][0]["provider"] = "provider[\"registry.terraform.io/hashicorp/aws\"]"
        state["resources"][0]["instances"][0]["attributes"]["region"] = "eu-west-1"
        self.assertEqual(am.infer_aws_region_from_state(state), "eu-west-1")

        state["resources"][0]["instances"][0]["attributes"].pop("region", None)
        state["resources"][0]["instances"][0]["attributes"]["availability_zone"] = "eu-west-1a"
        self.assertEqual(am.infer_aws_region_from_state(state), "eu-west-1")


class BigStateSmokeTest(unittest.TestCase):
    BIG_STATE = Path("/Users/sabithks/Downloads/big_terraform.tfstate")

    @unittest.skipUnless(BIG_STATE.is_file(), "big_terraform.tfstate fixture not present")
    def test_big_monolith_group_count_bounded(self) -> None:
        manifest, _, stats = am.allocate(
            str(self.BIG_STATE), "tag_seeded_connectivity_capped", 120
        )
        result = am.reconcile(str(self.BIG_STATE), manifest)
        self.assertTrue(result["count_reconciliation_ok"])
        self.assertEqual(stats["monolith_resource_count"], 12726)
        group_count = len(manifest)
        # Monolith has ~1k multi-seed connected components that cannot merge safely.
        self.assertGreater(group_count, 200)
        self.assertLess(group_count, 1500, f"expected <1500 groups, got {group_count}")


class BatchPayloadTests(unittest.TestCase):
    def test_sanitize_identifier_strips_module_path(self) -> None:
        ident = am.sanitize_identifier('module.network.aws_vpc.main')
        self.assertTrue(ident.startswith("module_network") or ident.startswith("aws_vpc"))

    def test_terraform_type_from_address(self) -> None:
        self.assertEqual(am.terraform_type_from_address("aws_vpc.main"), "aws_vpc")
        self.assertEqual(
            am.terraform_type_from_address("module.network.aws_vpc.main"), "aws_vpc"
        )

    def test_build_batch_payloads_includes_resources(self) -> None:
        manifest = {
            "aws-group-001": {
                "cloud_hint": "aws",
                "resource_addresses": ["aws_vpc.main", "aws_subnet.a"],
            }
        }
        id_map = {"aws_vpc.main": "main_vpc"}
        payloads = am.build_batch_payloads(manifest, ["aws-group-001"], id_map)
        self.assertEqual(len(payloads), 1)
        entry = payloads[0]
        self.assertEqual(entry["group_id"], "aws-group-001")
        self.assertEqual(len(entry["resources"]), 2)
        by_addr = {r["terraform_address"]: r for r in entry["resources"]}
        self.assertEqual(by_addr["aws_vpc.main"]["identifier"], "main_vpc")
        self.assertEqual(by_addr["aws_vpc.main"]["resource_type"], "aws_vpc")
        self.assertEqual(by_addr["aws_subnet.a"]["resource_type"], "aws_subnet")

    def test_prepare_parallel_artifacts_writes_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = {
                "g1": {"cloud_hint": "aws", "resource_addresses": ["aws_s3_bucket.data"]},
            }
            with open(os.path.join(tmp, "logical_group_manifest.json"), "w", encoding="utf-8") as fh:
                json.dump(manifest, fh)
            rc = am.cmd_prepare_parallel_artifacts(tmp)
            self.assertEqual(rc, 0)
            with open(os.path.join(tmp, "batch_payloads.json"), encoding="utf-8") as fh:
                payloads = json.load(fh)
            self.assertEqual(len(payloads), 1)
            self.assertIn("resources", payloads[0])
            self.assertEqual(payloads[0]["resources"][0]["resource_type"], "aws_s3_bucket")


if __name__ == "__main__":
    unittest.main()
