#!/usr/bin/env python3
"""Check review candidates against a historical reference; never edit app data."""

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESEARCH = ROOT / 'specs/018-ingredient-catalog/research'
CATALOG = RESEARCH / 'legacy-food-reference.csv'
CANDIDATES = RESEARCH / 'candidates.csv'
ALIAS_CORRECTIONS = RESEARCH / 'alias-correction-proposals.csv'
WORKSHEET = RESEARCH / 'catalog-review-worksheet.csv'
FIELDS = {
    'candidate_name', 'category_hint', 'proposed_base_unit', 'identity_status',
    'identity_source', 'identity_reviewer', 'allergen_status', 'allergen_codes',
    'allergen_source', 'allergen_reviewer', 'notes',
}
WORKSHEET_EXTRA_FIELDS = {
    'origin', 'legacy_aliases', 'base_unit_basis', 'usda_fdc_id',
    'usda_description', 'usda_basis', 'usda_alternates', 'base_unit_reviewer',
    'usda_reviewer',
}
REVIEW_FIELDS = (
    'identity_status', 'identity_source', 'identity_reviewer', 'allergen_status',
    'allergen_codes', 'allergen_source', 'allergen_reviewer',
)
UNREVIEWED = {
    'identity_status': 'pending', 'identity_source': '', 'identity_reviewer': '',
    'allergen_status': 'unknown', 'allergen_codes': 'unknown',
    'allergen_source': '', 'allergen_reviewer': '',
}
ALLERGENS = {
    'gluten', 'crustaceans', 'eggs', 'fish', 'peanuts', 'soy', 'milk',
    'nuts', 'celery', 'mustard', 'sesame', 'sulphites', 'lupin', 'molluscs',
}


def normalize(value):
    return ' '.join(value.strip().lower().split())


def validate(catalog, candidates, alias_corrections=()):
    """Return validation errors and the count marked reviewed, not approval."""
    errors = []
    marked_reviewed = 0
    if not catalog:
        errors.append('active catalog is empty')
    if not candidates:
        errors.append('candidate list is empty')
    if any(
        not isinstance(row.get(key), str)
        for row in catalog
        for key in ('name', 'aliases', 'category')
    ):
        errors.append('invalid catalog row')
        return errors, 0
    aliases_by_food = {}
    canonical_names = set()
    for row in catalog:
        food = normalize(row['name'])
        canonical_names.add(food)
        aliases_by_food.setdefault(food, set()).update(
            normalize(alias) for alias in row['aliases'].split('|') if alias.strip()
        )

    proposed_candidates = {
        row.get('candidate_name') for row in candidates
        if row.get('identity_status') in {'pending', 'reviewed'}
    }
    disputed = set()
    for number, row in enumerate(alias_corrections, start=2):
        if set(row) != {'historical_name', 'alias', 'reason'} or any(
            not isinstance(value, str) or not value.strip() for value in row.values()
        ):
            errors.append(f'alias correction row {number}: invalid columns or reason')
            continue
        food, alias = normalize(row['historical_name']), normalize(row['alias'])
        pair = (food, alias)
        if alias not in aliases_by_food.get(food, ()) or alias in canonical_names:
            errors.append(f'alias correction row {number}: expected a historical alias')
        elif pair in disputed or alias not in proposed_candidates:
            errors.append(f'alias correction row {number}: duplicate or missing candidate')
        else:
            disputed.add(pair)

    existing = canonical_names | {
        alias for food, aliases in aliases_by_food.items() for alias in aliases
        if (food, alias) not in disputed
    }
    categories = {row['category'] for row in catalog}
    seen = set()
    for number, row in enumerate(candidates, start=2):
        row_errors = []
        if set(row) != FIELDS or any(not isinstance(row[key], str) for key in FIELDS):
            errors.append(f'row {number}: invalid columns')
            continue
        name = row['candidate_name']
        key = normalize(name)
        identity = row['identity_status']
        if not key or key != name:
            row_errors.append('name must be nonempty and normalized')
        if identity != 'rejected':
            if key in existing:
                row_errors.append('name already in catalog or its aliases')
            if key in seen:
                row_errors.append('duplicate candidate')
            seen.add(key)
        if row['category_hint'] not in categories:
            row_errors.append('unknown category')

        if identity not in {'pending', 'reviewed', 'rejected'}:
            row_errors.append('invalid identity status')
        if identity == 'reviewed' and (
            not row['identity_source'].strip()
            or not row['identity_reviewer'].strip()
            or row['proposed_base_unit'] not in {'g', 'ml', 'kom'}
        ):
            row_errors.append('reviewed identity requires source, reviewer and unit')
        if identity == 'rejected' and not row['notes'].strip():
            row_errors.append('rejected identity requires a reason')
        if row['proposed_base_unit'] not in {'', 'g', 'ml', 'kom'}:
            row_errors.append('invalid unit')

        status, codes = row['allergen_status'], row['allergen_codes']
        if status == 'unknown':
            if codes != 'unknown':
                row_errors.append('unknown allergen status must use unknown codes')
        elif status == 'reviewed':
            values = codes.split('|')
            if codes != 'none' and (
                not values or len(values) != len(set(values))
                or any(code not in ALLERGENS for code in values)
            ):
                row_errors.append('reviewed allergens require explicit valid codes or none')
            if not row['allergen_source'].strip() or not row['allergen_reviewer'].strip():
                row_errors.append('reviewed allergens require source and reviewer')
        else:
            row_errors.append('invalid allergen status')
        errors.extend(f'row {number}: {error}' for error in row_errors)
        if not row_errors and identity == 'reviewed' and status == 'reviewed':
            marked_reviewed += 1
    return errors, marked_reviewed


def validate_worksheet(worksheet, catalog, candidates):
    """Check the review worksheet against its sources; it never approves a food.

    Review decisions live in candidates.csv. The worksheet only adds proposed
    evidence, so its review columns must repeat the candidate row and a
    reference row can carry no decision.
    """
    errors = []
    candidate_rows = {
        normalize(row['candidate_name']): row for row in candidates
        if isinstance(row.get('candidate_name'), str)
    }
    catalog_rows = {
        normalize(row['name']): row for row in catalog
        if isinstance(row.get('name'), str)
    }
    seen = set()
    for number, row in enumerate(worksheet, start=2):
        label = f'worksheet row {number}'
        if set(row) != FIELDS | WORKSHEET_EXTRA_FIELDS or any(
            not isinstance(value, str) for value in row.values()
        ):
            errors.append(f'{label}: invalid columns')
            continue
        name = normalize(row['candidate_name'])
        if name in seen:
            errors.append(f'{label}: duplicate worksheet food {name}')
            continue
        seen.add(name)
        if name not in candidate_rows and name not in catalog_rows:
            errors.append(f'{label}: not a candidate or reference food: {name}')
            continue
        is_candidate = name in candidate_rows
        origin = 'candidate' if is_candidate else 'legacy_reference'
        if row['origin'] != origin:
            errors.append(f'{label}: origin must be {origin}')
        category = (
            candidate_rows[name]['category_hint'] if is_candidate
            else catalog_rows[name]['category']
        )
        if row['category_hint'] != category:
            errors.append(f'{label}: category differs from its source')
        if row['proposed_base_unit'] not in {'g', 'ml', 'kom'}:
            errors.append(f'{label}: every worksheet row needs a known base unit')
        for key in ('base_unit_basis', 'usda_basis'):
            if not row[key].strip():
                errors.append(f'{label}: {key} is required')
        fdc, description = row['usda_fdc_id'], row['usda_description'].strip()
        if fdc and not fdc.isdigit():
            errors.append(f'{label}: usda_fdc_id must be a number')
        if fdc and not description:
            errors.append(f'{label}: usda_description is required with usda_fdc_id')
        if not fdc and description:
            errors.append(f'{label}: usda_description must be empty without usda_fdc_id')
        if is_candidate:
            source = candidate_rows[name]
            for key in REVIEW_FIELDS:
                if row[key] != source[key]:
                    errors.append(f'{label}: {key} differs from candidates.csv')
            if source['identity_status'] == 'reviewed':
                if not row['base_unit_reviewer'].strip():
                    errors.append(f'{label}: base_unit_reviewer is required for a reviewed food')
                if fdc and not row['usda_reviewer'].strip():
                    errors.append(f'{label}: usda_reviewer is required for a reviewed food')
        elif any(row[key] != UNREVIEWED[key] for key in REVIEW_FIELDS):
            errors.append(f'{label}: a reference row cannot carry review decisions')
    for name in sorted((candidate_rows.keys() | catalog_rows.keys()) - seen):
        errors.append(f'missing from worksheet: {name}')
    return errors


def read_rows(path):
    with path.open(encoding='utf-8', newline='') as source:
        return list(csv.DictReader(source))


def main():
    try:
        catalog = read_rows(CATALOG)
        candidates = read_rows(CANDIDATES)
        worksheet = read_rows(WORKSHEET)
        errors, marked = validate(catalog, candidates, read_rows(ALIAS_CORRECTIONS))
        errors += validate_worksheet(worksheet, catalog, candidates)
    except (OSError, csv.Error, KeyError, TypeError) as error:
        print(f'Unable to check candidate data: {error}', file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f'Historical reference: {len(catalog)}; proposals: {len(candidates)}; '
          f'worksheet rows: {len(worksheet)}; marked reviewed: {marked}.')
    print('The reference is not the team catalog; proposals are not active foods.')
    print('Exact checks do not prove identity, allergen safety or human approval.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
