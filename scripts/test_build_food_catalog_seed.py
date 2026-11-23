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
    def write_fixture(self, directory: Path, *, fdc_id: str = "222", calories: str = "57"):
        worksheet = directory / "worksheet.csv"
        nutrition = directory / "nutrition.csv"
        with worksheet.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=[
                "candidate_name", "category_hint", "proposed_base_unit",
                "identity_status", "identity_source", "identity_reviewer",
                "base_unit_basis", "base_unit_reviewer", "usda_basis",
                "usda_fdc_id", "usda_reviewer", "legacy_aliases",
            ])
            writer.writeheader()
            writer.writerow({
                "candidate_name": "Dunja", "category_hint": "voće",
                "proposed_base_unit": "g", "identity_status": "reviewed",
                "identity_source": "team review", "identity_reviewer": "reviewer",
                "base_unit_basis": "typical", "base_unit_reviewer": "reviewer",
                "usda_basis": "SR Legacy", "usda_fdc_id": "222",
                "usda_reviewer": "reviewer", "legacy_aliases": "Kiselog Dunja",
            })
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

    def test_pending_review_rows_cannot_be_seeded(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "seed.sql"
            with self.assertRaisesRegex(ValueError, "not approved for seeding"):
                generate(WORKSHEET, NUTRITION, output)
            self.assertFalse(output.exists())

    def test_stale_nutrition_fdc_id_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            worksheet, nutrition = self.write_fixture(Path(temp), fdc_id="111")
            with self.assertRaisesRegex(ValueError, "does not match reviewed worksheet"):
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
            self.assertIn("'Kiselog Dunja', 'kiselog dunja'", sql)


if __name__ == "__main__":
    unittest.main()
