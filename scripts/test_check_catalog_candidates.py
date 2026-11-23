import subprocess
import sys
import unittest

from scripts.check_catalog_candidates import ROOT, validate, validate_worksheet


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

    def test_actual_research_csvs(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / 'scripts/check_catalog_candidates.py')],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_disputed_alias_can_be_reviewed_as_a_separate_candidate(self):
        self.row['candidate_name'] = 'jaja'
        self.assertTrue(validate(self.catalog, [self.row])[0])
        correction = {'historical_name': 'jaje', 'alias': 'jaja', 'reason': 'split'}
        self.assertEqual(validate(self.catalog, [self.row], [correction]), ([], 0))
        correction['historical_name'] = 'missing'
        self.assertTrue(validate(self.catalog, [self.row], [correction])[0])

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


class WorksheetChecks(unittest.TestCase):
    def setUp(self):
        self.catalog = [
            {'name': 'jaje', 'aliases': 'jaja|jajce', 'category': 'ostalo'}
        ]
        self.candidate = {
            'candidate_name': 'mandarina', 'category_hint': 'ostalo',
            'proposed_base_unit': '', 'identity_status': 'pending',
            'identity_source': '', 'identity_reviewer': '',
            'allergen_status': 'unknown', 'allergen_codes': 'unknown',
            'allergen_source': '', 'allergen_reviewer': '', 'notes': '',
        }
        self.candidates = [self.candidate]
        self.extra = {
            'origin': 'candidate', 'legacy_aliases': '',
            'base_unit_basis': 'typical measurement (proposal)',
            'usda_fdc_id': '169105',
            'usda_description': 'Tangerines, (mandarin oranges), raw',
            'usda_basis': 'keyword search of SR Legacy descriptions (proposal)',
            'usda_alternates': '', 'base_unit_reviewer': '',
            'usda_reviewer': 'owner-authorized mapping review',
        }
        self.worksheet = [
            {**self.candidate, **self.extra, 'proposed_base_unit': 'g'},
            {
                **self.candidate, **self.extra, 'candidate_name': 'jaje',
                'origin': 'legacy_reference', 'legacy_aliases': 'jaja|jajce',
                'proposed_base_unit': 'kom', 'usda_fdc_id': '',
                'usda_description': '',
                'usda_basis': 'no SR Legacy mapping in historical map',
            },
        ]

    def errors(self):
        return validate_worksheet(self.worksheet, self.catalog, self.candidates)

    def assertError(self, text):
        self.assertTrue(any(text in error for error in self.errors()), self.errors())

    def test_consistent_worksheet_is_valid(self):
        self.assertEqual(self.errors(), [])

    def test_columns_must_match_exactly(self):
        del self.worksheet[0]['usda_basis']
        self.assertError('invalid columns')
        self.setUp()
        self.worksheet[0]['surprise'] = 'x'
        self.assertError('invalid columns')

    def test_every_source_food_must_appear_exactly_once(self):
        self.worksheet.pop()
        self.assertError('missing from worksheet: jaje')
        self.setUp()
        self.worksheet.append(dict(self.worksheet[0]))
        self.assertError('duplicate worksheet food')
        self.setUp()
        self.worksheet.append({**self.worksheet[0], 'candidate_name': 'kivi'})
        self.assertError('not a candidate or reference food: kivi')

    def test_origin_and_category_must_match_the_source(self):
        self.worksheet[0]['origin'] = 'legacy_reference'
        self.assertError('origin')
        self.setUp()
        self.worksheet[1]['category_hint'] = 'pekara'
        self.assertError('category')

    def test_every_row_proposes_a_known_base_unit(self):
        self.worksheet[0]['proposed_base_unit'] = ''
        self.assertError('base unit')
        self.setUp()
        self.worksheet[0]['proposed_base_unit'] = 'gram'
        self.assertError('base unit')

    def test_usda_fields_must_be_consistent(self):
        self.worksheet[0]['usda_fdc_id'] = 'abc'
        self.assertError('usda_fdc_id')
        self.setUp()
        self.worksheet[0]['usda_description'] = ''
        self.assertError('usda_description')
        self.setUp()
        self.worksheet[1]['usda_description'] = 'Eggs, raw'
        self.assertError('usda_description')
        self.setUp()
        self.worksheet[0]['usda_basis'] = ''
        self.assertError('usda_basis')

    def test_worksheet_cannot_approve_what_candidates_still_hold_pending(self):
        self.worksheet[0]['identity_status'] = 'reviewed'
        self.assertError('differs from candidates.csv')

    def test_reference_rows_cannot_carry_identity_or_allergen_decisions(self):
        self.worksheet[1]['identity_status'] = 'reviewed'
        self.assertError('reference row')
        self.setUp()
        self.worksheet[1]['allergen_codes'] = 'none'
        self.assertError('reference row')

    def test_reference_row_may_record_owner_approved_fdc_mapping(self):
        reference = self.worksheet[1]
        reference.update({
            'usda_fdc_id': '172183',
            'usda_description': 'Egg, whole, raw, fresh',
            'usda_reviewer': 'owner-authorized mapping review',
        })
        self.assertEqual(self.errors(), [])

    def test_reviewed_candidate_needs_the_worksheet_reviewers(self):
        reviewed = {
            **self.candidate, 'proposed_base_unit': 'g',
            'identity_status': 'reviewed', 'identity_source': 'review record',
            'identity_reviewer': 'reviewer', 'allergen_status': 'reviewed',
            'allergen_codes': 'none', 'allergen_source': 'review record',
            'allergen_reviewer': 'reviewer',
        }
        self.candidates = [reviewed]
        self.worksheet[0].update({
            key: reviewed[key] for key in (
                'identity_status', 'identity_source', 'identity_reviewer',
                'allergen_status', 'allergen_codes', 'allergen_source',
                'allergen_reviewer')
        })
        self.assertError('base_unit_reviewer')
        self.worksheet[0]['base_unit_reviewer'] = 'reviewer'
        self.worksheet[0]['usda_reviewer'] = ''
        self.assertError('approval record')
        self.worksheet[0]['usda_reviewer'] = 'owner-authorized mapping review'
        self.assertEqual(self.errors(), [])


if __name__ == '__main__':
    unittest.main()
