import csv
import tempfile
import unittest
import uuid
from pathlib import Path

from scripts.build_food_catalog_seed import NAMESPACE
from scripts.food_allergens import PROPOSAL_FIELDS, seed_legacy


def proposal(name, codes, confidence="auto", decision="approved"):
    return {
        "candidate_name": name, "category_hint": "x", "proposed_codes": codes,
        "confidence": confidence,
        "rule": "Annex II: " + codes if codes else "none: no Annex II group",
        "note": "", "decision": decision,
    }


class SeedLegacyAllergenTests(unittest.TestCase):
    def run_seed(self, rows, reviewer="Uroš Milutinović"):
        with tempfile.TemporaryDirectory() as temp:
            proposals = Path(temp) / "proposals.csv"
            with proposals.open("w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=PROPOSAL_FIELDS)
                writer.writeheader()
                writer.writerows(rows)
            output = Path(temp) / "seed.sql"
            count = seed_legacy(proposals, output, reviewer)
            return count, output.read_text(encoding="utf-8")

    def test_only_decided_rows_are_seeded_with_the_reviewer(self):
        count, sql = self.run_seed([
            proposal("losos", "fish"),
            proposal("krompir", ""),
            proposal("kobasica", "", "needs_review", ""),
        ])
        self.assertEqual(count, 2)
        self.assertIn("array['fish']::text[]", sql)
        self.assertIn(str(uuid.uuid5(NAMESPACE, "losos")), sql)
        self.assertIn("'{}'::text[]", sql)
        self.assertIn("(reviewed by Uroš Milutinović)", sql)
        self.assertNotIn(str(uuid.uuid5(NAMESPACE, "kobasica")), sql)

    def test_needs_review_cannot_be_bulk_approved(self):
        with self.assertRaisesRegex(ValueError, "needs explicit codes"):
            self.run_seed([proposal("hleb", "gluten", "needs_review")])

    def test_explicit_codes_override_the_proposal(self):
        count, sql = self.run_seed([
            proposal("hleb", "gluten", "needs_review", "codes:gluten|sesame"),
        ])
        self.assertEqual(count, 1)
        self.assertIn("array['gluten', 'sesame']::text[]", sql)

    def test_unknown_code_and_missing_reviewer_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Invalid codes"):
            self.run_seed([proposal("x", "gluten", "auto", "codes:wheat")])
        with self.assertRaisesRegex(ValueError, "named reviewer"):
            self.run_seed([proposal("losos", "fish")], reviewer=" ")


if __name__ == "__main__":
    unittest.main()
