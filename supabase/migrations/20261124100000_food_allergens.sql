-- 018 / 008 D3-010: reviewed allergen groups on shared catalog foods.
-- allergen_codes null  = allergen status unknown (never treated as safe);
-- allergen_codes '{}'  = reviewed, no EU Annex II group present;
-- allergen_codes {..}  = reviewed, these groups are present.
-- Only shared foods can carry a review; household foods stay unknown. This
-- adds storage only; the reviewed values arrive in a separate seed migration.
alter table public.foods
  add column allergen_codes text[]
    check (allergen_codes is null or private.valid_allergen_selection(allergen_codes)),
  add column allergen_source text
    check (allergen_source is null or char_length(allergen_source) between 1 and 500),
  add column allergen_source_ref text
    check (allergen_source_ref is null or char_length(allergen_source_ref) between 1 and 500),
  add column allergen_reviewed_at timestamptz,
  add constraint foods_allergens_reviewed_complete
    check (
      (allergen_codes is null
        and allergen_source is null
        and allergen_source_ref is null
        and allergen_reviewed_at is null)
      or (
        allergen_codes is not null
        and household_id is null
        and nullif(btrim(allergen_source), '') is not null
        and nullif(btrim(allergen_source_ref), '') is not null
        and allergen_reviewed_at is not null
      )
    );
