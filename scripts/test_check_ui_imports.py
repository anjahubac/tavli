"""Regression cases for the tavli_ui public entry gate; synthetic temp files only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.check_ui_imports import ROOT, check, violations


class UiImportChecks(unittest.TestCase):
    def test_actual_repository(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / 'scripts/check_ui_imports.py')],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_public_entry_is_allowed(self):
        source = "import 'package:tavli_ui/tavli_ui.dart';\n"
        self.assertEqual(list(violations(Path('a.dart'), source)), [])

    def test_src_and_other_package_files_are_rejected(self):
        source = (
            "import 'package:material_ui/material_ui.dart';\n"
            "import 'package:tavli_ui/src/tokens.dart';\n"
            "export \"package:tavli_ui/other.dart\";\n"
            "import '../../packages/tavli_ui/lib/src/platform.dart';\n"
        )
        self.assertEqual(
            list(violations(Path('a.dart'), source)),
            [
                (2, 'package:tavli_ui/src/tokens.dart'),
                (3, 'package:tavli_ui/other.dart'),
                (4, '../../packages/tavli_ui/lib/src/platform.dart'),
            ],
        )

    def test_check_scans_app_folders_but_not_the_package(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            bad = "import 'package:tavli_ui/src/tokens.dart';\n"
            for rel in ('lib/a.dart', 'test/b_test.dart', 'packages/tavli_ui/lib/c.dart'):
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(bad)
            errors = check(root)
            self.assertEqual(len(errors), 2)
            self.assertTrue(errors[0].startswith('lib/a.dart:1:'))
            self.assertTrue(errors[1].startswith('test/b_test.dart:1:'))


if __name__ == '__main__':
    unittest.main()
