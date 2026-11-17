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
FIELDS = {
    'candidate_name', 'category_hint', 'proposed_base_unit', 'identity_status',
    'identity_source', 'identity_reviewer', 'allergen_status', 'allergen_codes',
    'allergen_source', 'allergen_reviewer', 'notes',
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


def read_rows(path):
    with path.open(encoding='utf-8', newline='') as source:
        return list(csv.DictReader(source))


def main():
    try:
        catalog = read_rows(CATALOG)
        candidates = read_rows(CANDIDATES)
        errors, marked = validate(catalog, candidates, read_rows(ALIAS_CORRECTIONS))
    except (OSError, csv.Error, KeyError, TypeError) as error:
        print(f'Unable to check candidate data: {error}', file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f'Historical reference: {len(catalog)}; proposals: {len(candidates)}; '
          f'marked reviewed: {marked}.')
    print('The reference is not the team catalog; proposals are not active foods.')
    print('Exact checks do not prove identity, allergen safety or human approval.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
