"""Regression cases for the documentation gate; synthetic data and temp files only."""
import copy
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("check_docs", Path(__file__).with_name("check-docs.py"))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class DocumentChecksTest(unittest.TestCase):
    def test_links_ignore_code_remote_and_anchor_only(self):
        source = "[local](a.md#title) [remote](https://example.invalid) [anchor](#x)\n"
        source += "`[inline](fake.md)`\n```\n[fenced](fake.md)\n```\n[ref]: <b.md>\n"
        self.assertEqual(list(checker.local_links(source)), ["a.md", "b.md"])

    def test_link_checks_missing_and_outside_root(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "exists.md").write_text("# Exists")
            page = root / "page.md"
            page.write_text("[ok](exists.md) [missing](missing.md) [escape](../outside.md)")
            errors = checker.broken_links(root, page)
            self.assertEqual(len(errors), 2)
            self.assertTrue(any("missing.md" in e for e in errors))
            self.assertTrue(any("outside.md" in e for e in errors))

    def registry(self):
        tasks = []
        for role, count in enumerate((20, 21, 20, 26), 1):
            for item in range(1, count + 1):
                tasks.append(dict(id=f"D{role}-{item:03}", source_row=len(tasks)+1,
                                  title="Synthetic task", role=f"Dev {role}", assignee="Test",
                                  phase=1, feature_key="TEST", status="not_assessed"))
        return dict(tasks=tasks, source_sha256="0"*64)

    def test_valid_register_and_duplicate_identity(self):
        data = self.registry()
        self.assertEqual(checker.registry_errors(data), [])
        data["tasks"][1]["id"] = data["tasks"][0]["id"]
        self.assertTrue(any("duplicate" in e for e in checker.registry_errors(data)))

    def test_missing_row_wrong_role_and_phase_are_detected(self):
        data = self.registry()
        data["tasks"][0].update(source_row=2, role="Dev 2", phase=9)
        errors = checker.registry_errors(data)
        self.assertTrue(any("Source rows" in e for e in errors))
        self.assertTrue(any("role/ID" in e for e in errors))
        self.assertTrue(any("phase" in e for e in errors))

    def test_feature_mapping_and_cycle_detection(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            feature = root / "specs/014-example"
            (feature / "checklists").mkdir(parents=True)
            (feature / "spec.md").write_text("- **FR-001**: D1-001 outcome")
            (feature / "plan.md").write_text("Plan")
            (feature / "checklists/readiness.md").write_text("Ready gates")
            (feature / "tasks.md").write_text("- [ ] T002 D1-001 test\n- [ ] T003 D1-001 implement\n")
            tasks = dict(tasks=[dict(id="D1-001", feature_key="TEST", spec="specs/014-example/spec.md",
                                    requirement="FR-001", test_task="T002", implementation_task="T003")])
            features = [dict(key="TEST", spec="specs/014-example/spec.md", dependencies=[])]
            self.assertEqual(checker.feature_errors(root, tasks, features), [])
            bad = copy.deepcopy(tasks)
            bad["tasks"][0]["implementation_task"] = "T099"
            self.assertTrue(any("implementation_task" in e for e in checker.feature_errors(root, bad, features)))
            features[0]["dependencies"] = [14]
            self.assertTrue(any("cycle" in e for e in checker.feature_errors(root, tasks, features)))


if __name__ == "__main__":
    unittest.main()
