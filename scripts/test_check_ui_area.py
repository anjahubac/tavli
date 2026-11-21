"""Regression cases for the migrated-screen gate; synthetic sources only."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.check_ui_area import MIGRATED, ROOT, check, violations


class UiAreaChecks(unittest.TestCase):
    def test_actual_repository(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / 'scripts/check_ui_area.py')],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_library_components_and_tokens_pass(self):
        source = (
            "TavliListRow(title: 'Izgled', showChevron: true);\n"
            "const SizedBox(height: TavliSpacing.small);\n"
            "final first = parts.split(' ').first; list[0]; n - 1;\n"
        )
        self.assertEqual(list(violations(source)), [])

    def test_raw_widgets_are_rejected(self):
        source = (
            "ListTile(title: Text('a'));\n"
            "FilledButton.icon(onPressed: null);\n"
            "showDialog(builder: (_) => AlertDialog());\n"
            "DropdownButtonFormField<AIProvider>(items: []);\n"
        )
        self.assertEqual(
            [line for line, _ in violations(source)], [1, 2, 3, 4],
        )

    def test_numbers_outside_strings_and_comments_are_rejected(self):
        source = (
            "// razmak 16 iz platna\n"
            "Text('Čeka slanje: 3 ${n + 2}');\n"
            "const EdgeInsets.all(16);\n"
            "BorderRadius.circular(TavliRadius.card - 3.5);\n"
        )
        messages = list(violations(source))
        self.assertEqual([line for line, _ in messages], [2, 3, 4])
        self.assertIn('2', messages[0][1])

    def test_names_containing_a_widget_name_pass(self):
        source = "TavliCard(child: x); MyCardHeader(); x.Material;\n"
        self.assertEqual(list(violations(source)), [])

    def test_missing_file_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            errors = check(Path(folder), files=('lib/missing.dart',))
        self.assertEqual(len(errors), 1)
        self.assertIn('ne postoji', errors[0])

    def test_area_lists_existing_files(self):
        for rel in MIGRATED:
            self.assertTrue((ROOT / rel).is_file(), rel)


if __name__ == '__main__':
    unittest.main()
