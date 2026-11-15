import unittest

from scripts.check_catalog_candidates import validate


class CandidateChecks(unittest.TestCase):
    def setUp(self):
        self.catalog = [
            {'name': 'jaje', 'aliases': 'jaja|jajce', 'category': 'ostalo'}
        ]
        self.row = {
            'candidate_name': 'mandarina',
            'category_hint': 'ostalo',
            'proposed_base_unit': '',
            'identity_status': 'pending',
            'identity_source': '',
            'identity_reviewer': '',
            'allergen_status': 'unknown',
            'allergen_codes': 'unknown',
            'allergen_source': '',
            'allergen_reviewer': '',
            'notes': '',
        }

    def test_pending_is_valid_but_not_review_marked(self):
        errors, count = validate(self.catalog, [self.row])
        self.assertEqual(errors, [])
        self.assertEqual(count, 0)

    def test_empty_data_is_not_accepted_as_a_successful_review(self):
        errors, _ = validate([], [])
        self.assertTrue(any('catalog is empty' in error for error in errors))
        self.assertTrue(any('candidate list is empty' in error for error in errors))

    def test_malformed_catalog_is_reported_instead_of_crashing(self):
        errors, _ = validate([{'name': 'jaje', 'aliases': None}], [self.row])
        self.assertTrue(any('invalid catalog row' in error for error in errors))

    def test_existing_alias_and_duplicate_candidates_are_rejected(self):
        alias = {**self.row, 'candidate_name': 'jaja'}
        errors, _ = validate(self.catalog, [alias, self.row, self.row])
        self.assertTrue(any('already in catalog' in error for error in errors))
        self.assertTrue(any('duplicate candidate' in error for error in errors))

    def test_rejected_duplicate_can_remain_as_review_history(self):
        rejected = {
            **self.row,
            'candidate_name': 'jaja',
            'identity_status': 'rejected',
            'notes': 'already an alias',
        }
        errors, count = validate(self.catalog, [rejected])
        self.assertEqual(errors, [])
        self.assertEqual(count, 0)

    def test_unknown_allergens_cannot_be_treated_as_none(self):
        row = {**self.row, 'allergen_codes': 'none'}
        errors, _ = validate(self.catalog, [row])
        self.assertTrue(any('unknown allergen' in error for error in errors))

    def test_review_requires_source_reviewer_and_explicit_allergens(self):
        row = {**self.row, 'identity_status': 'reviewed', 'allergen_status': 'reviewed'}
        errors, count = validate(self.catalog, [row])
        self.assertTrue(errors)
        self.assertEqual(count, 0)
        row.update({
            'proposed_base_unit': 'kom',
            'identity_source': 'review record',
            'identity_reviewer': 'reviewer',
            'allergen_codes': 'none',
            'allergen_source': 'review record',
            'allergen_reviewer': 'reviewer',
        })
        errors, count = validate(self.catalog, [row])
        self.assertEqual(errors, [])
        self.assertEqual(count, 1)

    def test_reviewed_allergens_must_use_known_codes(self):
        row = {
            **self.row,
            'allergen_status': 'reviewed',
            'allergen_codes': 'unknown|milk',
            'allergen_source': 'review record',
            'allergen_reviewer': 'reviewer',
        }
        errors, _ = validate(self.catalog, [row])
        self.assertTrue(any('explicit valid codes' in error for error in errors))

    def test_incomplete_csv_row_is_reported_not_crashed(self):
        errors, _ = validate(self.catalog, [{**self.row, 'candidate_name': None}])
        self.assertTrue(any('invalid columns' in error for error in errors))


if __name__ == '__main__':
    unittest.main()
