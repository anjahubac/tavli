import csv
import tempfile
import unittest
from pathlib import Path

from scripts.build_food_catalog_seed import generate

ROOT = Path(__file__).resolve().parent.parent
WORKSHEET = ROOT / "specs/018-ingredient-catalog/research/catalog-review-worksheet.csv"
NUTRITION = (
    ROOT
    / "specs/023-optional-nutrition/research/nutrition-values-sr-legacy-2018.csv"
)


class BuildFoodCatalogSeedTests(unittest.TestCase):
    def write_fixture(
        self,
        directory: Path,
        *,
        fdc_id: str = "222",
        calories: str = "57",
        identity_status: str = "reviewed",
        usda_reviewer: str = "owner approval",
        include_legacy: bool = False,
    ):
        worksheet = directory / "worksheet.csv"
        nutrition = directory / "nutrition.csv"
        fields = [
            "candidate_name", "category_hint", "proposed_base_unit",
            "identity_status", "identity_source", "identity_reviewer",
            "base_unit_basis", "base_unit_reviewer", "usda_basis",
            "usda_fdc_id", "usda_reviewer", "legacy_aliases", "origin",
        ]
        rows = [{
            "candidate_name": "Dunja", "category_hint": "voće",
            "proposed_base_unit": "g", "identity_status": identity_status,
            "identity_source": "owner review", "identity_reviewer": "unspecified",
            "base_unit_basis": "owner review", "base_unit_reviewer": "unspecified",
            "usda_basis": "SR Legacy", "usda_fdc_id": "222",
            "usda_reviewer": usda_reviewer, "legacy_aliases": "Kisela dunja",
            "origin": "candidate",
        }]
        if include_legacy:
            rows.append({
                "candidate_name": "Legacy reference", "category_hint": "voće",
                "proposed_base_unit": "g", "identity_status": "pending",
                "identity_source": "", "identity_reviewer": "",
                "base_unit_basis": "historical reference", "base_unit_reviewer": "",
                "usda_basis": "historical mapping", "usda_fdc_id": "333",
                "usda_reviewer": "owner approval", "legacy_aliases": "",
                "origin": "legacy_reference",
            })
        with worksheet.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
        with nutrition.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=[
                "candidate_name", "usda_fdc_id", "kcal_per_100g",
                "protein_grams_per_100g", "fat_grams_per_100g",
                "carbs_grams_per_100g",
            ])
            writer.writeheader()
            writer.writerow({
                "candidate_name": "Dunja", "usda_fdc_id": fdc_id,
                "kcal_per_100g": calories, "protein_grams_per_100g": "0.4",
                "fat_grams_per_100g": "0.1", "carbs_grams_per_100g": "15.3",
            })
        return worksheet, nutrition

    def test_pending_identity_rows_cannot_be_seeded(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(
                Path(temp), identity_status="pending"
            )
            output = Path(temp) / "seed.sql"
            with self.assertRaisesRegex(ValueError, "not approved for seeding"):
                generate(worksheet, nutrition, output)
            self.assertFalse(output.exists())

    def test_stale_nutrition_fdc_id_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(Path(temp), fdc_id="111")
            with self.assertRaisesRegex(ValueError, "does not match reviewed worksheet"):
                generate(worksheet, nutrition, Path(temp) / "seed.sql")

    def test_fdc_mapping_without_approval_cannot_seed_nutrition(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(
                Path(temp), usda_reviewer=""
            )
            with self.assertRaisesRegex(ValueError, "missing review evidence.*usda_reviewer"):
                generate(worksheet, nutrition, Path(temp) / "seed.sql")

    def test_invalid_nutrient_number_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(Path(temp), calories="12,5")
            with self.assertRaisesRegex(ValueError, "Invalid nutrient value.*Dunja"):
                generate(worksheet, nutrition, Path(temp) / "seed.sql")

    def test_alias_display_text_is_preserved_in_generated_seed(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(Path(temp))
            output = Path(temp) / "seed.sql"
            generate(worksheet, nutrition, output)
            sql = output.read_text(encoding="utf-8")
            self.assertIn("'Kisela dunja', 'kisela dunja'", sql)

    def test_legacy_references_are_not_seeded_as_catalog_foods(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(
                Path(temp), include_legacy=True
            )
            output = Path(temp) / "seed.sql"
            foods, _, _ = generate(worksheet, nutrition, output)
            sql = output.read_text(encoding="utf-8")
            self.assertEqual(foods, 1)
            self.assertIn("'Dunja'", sql)
            self.assertNotIn("'Legacy reference'", sql)


if __name__ == "__main__":
    unittest.main()
