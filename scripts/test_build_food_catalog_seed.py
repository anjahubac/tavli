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
    def test_pending_review_rows_cannot_be_seeded(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "seed.sql"
            with self.assertRaisesRegex(ValueError, "not approved for seeding"):
                generate(WORKSHEET, NUTRITION, output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
