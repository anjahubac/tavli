import csv
import tempfile
import unittest
import uuid
from pathlib import Path

from scripts.build_food_catalog_seed import NAMESPACE
from scripts.food_allergens import GROUPS, apply, classify, propose, seed

ROOT = Path(__file__).resolve().parent.parent
WORKSHEET = ROOT / "specs/018-ingredient-catalog/research/catalog-review-worksheet.csv"
FIELDS = [
    "candidate_name", "category_hint", "allergen_status", "allergen_codes",
    "allergen_source", "allergen_reviewer", "origin",
]


def fixture(directory: Path, rows):
    path = directory / "worksheet.csv"
    with path.open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for name, category, status, codes in rows:
            writer.writerow({
                "candidate_name": name, "category_hint": category,
                "allergen_status": status, "allergen_codes": codes,
                "allergen_source": "src" if status == "reviewed" else "",
                "allergen_reviewer": "Person" if status == "reviewed" else "",
                "origin": "candidate",
            })
    return path


class FoodAllergenTests(unittest.TestCase):
    def test_rules_cover_annex_ii_examples(self):
        self.assertEqual(classify("kefir", "mlečni proizvodi i jaja")[0], "milk")
        self.assertEqual(classify("dagnja", "meso i riba")[0], "molluscs")
        self.assertEqual(classify("rečni rak", "meso i riba")[0], "crustaceans")
        self.assertEqual(classify("smuđ", "meso i riba")[0], "fish")
        self.assertEqual(classify("seme slačice", "začini i sosovi")[0], "mustard")
        self.assertEqual(classify("kuskus", "suvi proizvodi")[0], "gluten")

    def test_uncovered_food_is_never_called_safe(self):
        codes, _, confidence, _ = classify("nepoznato", "ostalo")
        self.assertEqual(confidence, "needs_review")
        self.assertEqual(codes, "")

    def test_processed_or_uncertain_foods_need_review(self):
        for name in ("vinsko sirće", "ovseno brašno", "javorov sirup"):
            self.assertEqual(classify(name, "x")[2], "needs_review", name)

    def test_every_rule_uses_known_codes(self):
        from scripts.food_allergens import CONTAINS
        for name, (codes, *_rest) in CONTAINS.items():
            for code in filter(None, codes.split("|")):
                self.assertIn(code, GROUPS, name)

    def test_real_worksheet_has_a_proposal_for_every_unreviewed_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            proposals = Path(tmp) / "p.csv"
            counts = propose(WORKSHEET, proposals)
            rows = list(csv.DictReader(proposals.open(encoding="utf-8")))
        with WORKSHEET.open(encoding="utf-8-sig") as src:
            expected = [
                r for r in csv.DictReader(src)
                if r["origin"] == "candidate" and r["allergen_status"] != "reviewed"
            ]
        self.assertEqual(len(rows), len(expected))
        self.assertEqual(sum(counts.values()), len(rows))

    def test_nothing_is_reviewed_without_a_decision(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ws = fixture(tmp, [("kefir", "mlečni proizvodi i jaja", "unknown", "unknown")])
            propose(ws, tmp / "p.csv")
            self.assertEqual(apply(ws, tmp / "p.csv", "Reviewer"), 0)
            out = tmp / "seed.sql"
            self.assertEqual(seed(ws, out), 0)

    def test_apply_and_seed_reviewed_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ws = fixture(tmp, [
                ("kefir", "mlečni proizvodi i jaja", "unknown", "unknown"),
                ("kruška", "voće i povrće", "unknown", "unknown"),
            ])
            proposals = tmp / "p.csv"
            propose(ws, proposals)
            rows = list(csv.DictReader(proposals.open(encoding="utf-8")))
            for r in rows:
                r["decision"] = "approved"
            with proposals.open("w", newline="", encoding="utf-8") as out:
                w = csv.DictWriter(out, fieldnames=rows[0].keys(), lineterminator="\n")
                w.writeheader()
                w.writerows(rows)
            self.assertEqual(apply(ws, proposals, "Reviewer"), 2)
            out = tmp / "seed.sql"
            self.assertEqual(seed(ws, out), 2)
            sql = out.read_text(encoding="utf-8")
            self.assertIn("array['milk']::text[]", sql)
            self.assertIn("'{}'::text[]", sql)
            self.assertIn(str(uuid.uuid5(NAMESPACE, "kefir")), sql)
            self.assertIn("household_id is null", sql)
            self.assertIn("reviewed by Reviewer", sql)

    def test_needs_review_cannot_be_bulk_approved(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ws = fixture(tmp, [("vinsko sirće", "začini i sosovi", "unknown", "unknown")])
            proposals = tmp / "p.csv"
            propose(ws, proposals)
            rows = list(csv.DictReader(proposals.open(encoding="utf-8")))
            rows[0]["decision"] = "approved"
            with proposals.open("w", newline="", encoding="utf-8") as out:
                w = csv.DictWriter(out, fieldnames=rows[0].keys(), lineterminator="\n")
                w.writeheader()
                w.writerows(rows)
            with self.assertRaises(ValueError):
                apply(ws, proposals, "Reviewer")

    def test_explicit_codes_and_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ws = fixture(tmp, [("vinsko sirće", "začini i sosovi", "unknown", "unknown")])
            proposals = tmp / "p.csv"
            propose(ws, proposals)
            for decision, ok in (("codes:sulphites", True), ("codes:nonsense", False)):
                rows = list(csv.DictReader(proposals.open(encoding="utf-8")))
                rows[0]["decision"] = decision
                with proposals.open("w", newline="", encoding="utf-8") as out:
                    w = csv.DictWriter(out, fieldnames=rows[0].keys(), lineterminator="\n")
                    w.writeheader()
                    w.writerows(rows)
                if ok:
                    self.assertEqual(apply(ws, proposals, "R"), 1)
                else:
                    ws2 = fixture(tmp, [("vinsko sirće", "x", "unknown", "unknown")])
                    with self.assertRaises(ValueError):
                        apply(ws2, proposals, "R")

    def test_reviewer_is_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ws = fixture(tmp, [("kefir", "x", "unknown", "unknown")])
            with self.assertRaises(ValueError):
                apply(ws, tmp / "p.csv", " ")


if __name__ == "__main__":
    unittest.main()
