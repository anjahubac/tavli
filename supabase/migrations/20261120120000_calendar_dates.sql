-- 016 / D1-002: kalendarski dani plana i nedeljne liste postaju `date`.
--
-- Aplikacija je ove vrednosti uvek pisala kao ponoć UTC (`CivilDate.toWire`),
-- pa je dan postojećeg reda njegov UTC datum. Stara aplikacija i dalje šalje
-- vremensku oznaku; PostgreSQL je pri upisu u `date` svodi na datum, pa stari
-- red za slanje daje isti dan. Trenuci (`created_at`, `updated_at`) se ne
-- menjaju. Ako bi dve nedeljne liste istog plana pale na isti dan, jedinstvenost
-- (meal_plan_id, period_start) zaustavlja migraciju umesto da tiho spoji liste.

alter table public.meal_plans
  alter column start_date type date using (start_date at time zone 'UTC')::date,
  alter column end_date type date using (end_date at time zone 'UTC')::date;

alter table public.meal_plan_entries
  alter column date type date using (date at time zone 'UTC')::date;

alter table public.shopping_lists
  alter column period_start type date using (period_start at time zone 'UTC')::date,
  alter column period_end type date using (period_end at time zone 'UTC')::date;
