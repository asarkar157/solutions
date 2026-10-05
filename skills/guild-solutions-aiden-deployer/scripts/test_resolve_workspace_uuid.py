"""Offline tests: python3 -B -m unittest discover -s <skill>/scripts -v."""

import contextlib
import io
import json
import os
import sys
import unittest
from unittest.mock import patch

import resolve_workspace_uuid as lookup


class WorkspaceLookupTests(unittest.TestCase):
    def run_lookup(self, query, organizations, *, credentials=None, executables=("tofu",)):
        calls = []
        credentials = credentials if credentials is not None else {
            "STACKGEN_URL": "https://example.invalid",
            "STACKGEN_TOKEN": "test-pat-not-real",
        }

        def fake_run(cmd, cwd, env):
            self.assertEqual(env["TF_VAR_stackgen_url"], "https://example.invalid")
            self.assertEqual(env["TF_VAR_stackgen_token"], "test-pat-not-real")
            self.assertNotIn("test-pat-not-real", " ".join(cmd))
            self.assertTrue((cwd / "main.tf").is_file())
            calls.append(cmd)
            if cmd[1] == "output":
                return json.dumps({"organizations": organizations})
            return ""

        output = io.StringIO()
        with (
            patch.dict(os.environ, credentials, clear=True),
            patch.object(sys, "argv", ["lookup", "--workspace-name", query]),
            patch.object(lookup.shutil, "which", side_effect=lambda name: f"/mock/{name}" if name in executables else None),
            patch.object(lookup, "run", side_effect=fake_run),
            contextlib.redirect_stdout(output),
        ):
            self.assertEqual(lookup.main(), 0)
        self.assertNotIn("test-pat-not-real", output.getvalue())
        self.assertEqual([cmd[1] for cmd in calls], ["init", "apply", "output"])
        expected_engine = "tofu" if "tofu" in executables else "terraform"
        self.assertTrue(all(cmd[0] == f"/mock/{expected_engine}" for cmd in calls))
        return json.loads(output.getvalue())

    def test_unique_exact_match_normalizes_case_and_whitespace(self):
        result = self.run_lookup("  Production   Team ", [{"id": "one", "name": "production team"}])
        self.assertEqual(result["selected"]["id"], "one")
        self.assertEqual(result["match_count"], {"exact": 1, "fuzzy": 0, "visible_organizations": 1})

    def test_duplicate_exact_matches_require_selection(self):
        result = self.run_lookup("production", [
            {"id": "one", "name": "Production"},
            {"id": "two", "name": "PRODUCTION"},
        ])
        self.assertIsNone(result["selected"])
        self.assertEqual(result["match_count"]["exact"], 2)

    def test_fuzzy_match_is_not_selected(self):
        result = self.run_lookup("production", [{"id": "one", "name": "production demo"}])
        self.assertIsNone(result["selected"])
        self.assertEqual(result["match_count"]["fuzzy"], 1)

    def test_exact_match_wins_over_fuzzy_match(self):
        result = self.run_lookup("production", [
            {"id": "one", "name": "production"},
            {"id": "two", "name": "production demo"},
        ])
        self.assertEqual(result["selected"]["id"], "one")
        self.assertEqual(result["match_count"]["fuzzy"], 1)

    def test_missing_match_does_not_select_another_workspace(self):
        result = self.run_lookup("production", [{"id": "one", "name": "staging"}])
        self.assertIsNone(result["selected"])
        self.assertEqual(result["match_count"], {"exact": 0, "fuzzy": 0, "visible_organizations": 1})

    def test_empty_inventory(self):
        result = self.run_lookup("production", [])
        self.assertIsNone(result["selected"])
        self.assertEqual(result["match_count"]["visible_organizations"], 0)

    def test_terraform_environment_credentials(self):
        self.run_lookup("production", [], credentials={
            "TF_VAR_stackgen_url": "https://example.invalid",
            "TF_VAR_stackgen_token": "test-pat-not-real",
        })

    def test_terraform_fallback(self):
        self.run_lookup("production", [], executables=("terraform",))


if __name__ == "__main__":
    unittest.main()
