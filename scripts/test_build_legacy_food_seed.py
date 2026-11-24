import csv
import tempfile
import unittest
from pathlib import Path

from scripts.build_food_catalog_seed import LEGACY_REVIEW_SOURCE, generate_legacy

WORKSHEET_FIELDS = [
    "candidate_name", "category_hint", "proposed_base_unit",
    "identity_status", "identity_source", "identity_reviewer",
    "base_unit_basis", "base_unit_reviewer", "usda_basis",
    "usda_fdc_id", "usda_reviewer", "legacy_aliases", "origin",
]


def worksheet_row(name, origin, *, aliases="", fdc="", reviewer=""):
    return {
        "candidate_name": name, "category_hint": "voće i povrće",
        "proposed_base_unit": "g",
        "identity_status": "reviewed" if origin == "candidate" else "pending",
        "identity_source": "owner review" if origin == "candidate" else "",
        "identity_reviewer": "owner" if origin == "candidate" else "",
        "base_unit_basis": "historical catalog", "base_unit_reviewer": "",
        "usda_basis": "historical map", "usda_fdc_id": fdc,
        "usda_reviewer": reviewer, "legacy_aliases": aliases,
        "origin": origin,
    }


class BuildLegacyFoodSeedTests(unittest.TestCase):
    def write(self, directory, *, approvals, corrections=(), rows=None):
        rows = rows or [
            worksheet_row("dunja", "candidate", fdc="222", reviewer="owner"),
            worksheet_row(
                "krompir", "legacy_reference",
                aliases="krompira|mladi krompir", fdc="170026",
                reviewer="owner mapping approval",
            ),
            worksheet_row("pšenično brašno", "legacy_reference",
                          aliases="brašno|brašno t-400"),
            worksheet_row("cvekla", "legacy_reference"),
        ]
        paths = {name: directory / f"{name}.csv" for name in
                 ("worksheet", "nutrition", "approvals", "corrections")}
        with paths["worksheet"].open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=WORKSHEET_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        with paths["nutrition"].open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=[
                "candidate_name", "usda_fdc_id", "kcal_per_100g",
                "protein_grams_per_100g", "fat_grams_per_100g",
                "carbs_grams_per_100g",
            ])
            writer.writeheader()
            for row in rows:
                full = row["usda_fdc_id"] == "170026"
                writer.writerow({
                    "candidate_name": row["candidate_name"],
                    "usda_fdc_id": row["usda_fdc_id"],
                    "kcal_per_100g": "77" if full else "",
                    "protein_grams_per_100g": "2" if full else "",
                    "fat_grams_per_100g": "0.1" if full else "",
                    "carbs_grams_per_100g": "17" if full else "",
                })
        with paths["approvals"].open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=[
                "candidate_name", "identity_source", "identity_reviewer",
            ])
            writer.writeheader()
            writer.writerows(approvals)
        with paths["corrections"].open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=[
                "historical_name", "alias", "reason",
            ])
            writer.writeheader()
            writer.writerows(corrections)
        return paths

    def approval(self, name, reviewer="Uroš Milutinović"):
        return {"candidate_name": name, "identity_source": "owner chat review",
                "identity_reviewer": reviewer}

    def run_generate(self, paths, output):
        return generate_legacy(
            paths["worksheet"], paths["nutrition"], paths["approvals"],
            paths["corrections"], output,
        )

    def test_only_approved_legacy_rows_are_seeded_with_their_aliases(self):
        with tempfile.TemporaryDirectory() as temp:
            paths = self.write(Path(temp), approvals=[self.approval("krompir")])
            output = Path(temp) / "seed.sql"
            foods, mapped, aliases = self.run_generate(paths, output)
            sql = output.read_text(encoding="utf-8")
            self.assertEqual((foods, mapped, aliases), (1, 1, 2))
            self.assertIn("'krompir'", sql)
            self.assertIn(f"'{LEGACY_REVIEW_SOURCE}'", sql)
            self.assertNotIn("owner chat review", sql)
            self.assertIn("'FDC 170026'", sql)
            self.assertIn("'mladi krompir', 'mladi krompir'", sql)
            self.assertNotIn("'dunja'", sql)
            self.assertNotIn("'cvekla'", sql)

    def test_reviewer_name_stays_out_of_synced_rows(self):
        with tempfile.TemporaryDirectory() as temp:
            approval = self.approval("krompir")
            approval["identity_source"] = (
                "Uroš Milutinović confirmed in chat that he reviewed this row."
            )
            paths = self.write(Path(temp), approvals=[approval])
            output = Path(temp) / "seed.sql"
            self.run_generate(paths, output)
            sql = output.read_text(encoding="utf-8")
            self.assertNotIn("Milutinović", sql)
            self.assertNotIn("confirmed in chat that", sql)

    def test_disputed_aliases_are_not_seeded(self):
        with tempfile.TemporaryDirectory() as temp:
            paths = self.write(
                Path(temp),
                approvals=[self.approval("pšenično brašno")],
                corrections=[{"historical_name": "pšenično brašno",
                              "alias": "brašno t-400", "reason": "separate"}],
            )
            output = Path(temp) / "seed.sql"
            foods, mapped, aliases = self.run_generate(paths, output)
            sql = output.read_text(encoding="utf-8")
            self.assertEqual((foods, mapped, aliases), (1, 0, 1))
            self.assertIn("'brašno', 'brašno'", sql)
            self.assertNotIn("t-400", sql)

    def test_approval_must_name_a_legacy_reference_row(self):
        for name in ("dunja", "nepoznato"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                paths = self.write(Path(temp), approvals=[self.approval(name)])
                with self.assertRaisesRegex(ValueError, "not a legacy reference"):
                    self.run_generate(paths, Path(temp) / "seed.sql")

    def test_approval_requires_source_and_reviewer(self):
        with tempfile.TemporaryDirectory() as temp:
            paths = self.write(
                Path(temp), approvals=[self.approval("krompir", reviewer="")]
            )
            output = Path(temp) / "seed.sql"
            with self.assertRaisesRegex(ValueError, "missing review evidence"):
                self.run_generate(paths, output)
            self.assertFalse(output.exists())

    def test_alias_matching_another_food_name_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            rows = [
                worksheet_row("dunja", "candidate"),
                worksheet_row("krompir", "legacy_reference", aliases="dunja"),
            ]
            paths = self.write(
                Path(temp), approvals=[self.approval("krompir")], rows=rows
            )
            with self.assertRaisesRegex(ValueError, "Ambiguous shared alias"):
                self.run_generate(paths, Path(temp) / "seed.sql")


class SlugTransliterationTest(unittest.TestCase):
    def test_serbian_dje_slugs_keep_distinct_consonant(self):
        from scripts.build_food_catalog_seed import slugify

        self.assertEqual(slugify('mirođija'), 'mirodjija')
        self.assertEqual(slugify('grožđe'), 'grozdje')
        self.assertEqual(slugify('đumbir'), 'djumbir')


if __name__ == "__main__":
    unittest.main()
