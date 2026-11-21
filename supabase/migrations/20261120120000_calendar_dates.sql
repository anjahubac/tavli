-- 016 / D1-002: kalendarski dani plana i nedeljne liste postaju `date`.
--
-- Aplikacija je ove vrednosti uvek pisala kao ponoć UTC (`CivilDate.toWire`),
-- pa je dan postojećeg reda njegov UTC datum. Stara aplikacija i dalje šalje
-- vremensku oznaku; PostgreSQL je pri upisu u `date` svodi na datum, pa stari
-- red za slanje daje isti dan. Trenuci (`created_at`, `updated_at`) se ne
-- menjaju. Server posle ove migracije vraća `YYYY-MM-DD`; to ispravno čita samo
-- build sa čitačem iz #42 (dev od 18.11.2026), pa je on najstariji podržan.

-- Pre promene: dve nedeljne liste istog plana na isti UTC dan bi posle
-- konverzije prekršile jedinstvenost. Takav red se ne spaja automatski;
-- migracija staje sa jasnom porukom i spiskom, pa ga neko ručno razreši.
do $$
declare
  collisions text;
begin
  select string_agg(format('%s/%s', meal_plan_id, day), ', ')
    into collisions
    from (
      select meal_plan_id, (period_start at time zone 'UTC')::date as day
        from public.shopping_lists
       where meal_plan_id is not null and period_start is not null
       group by 1, 2
      having count(*) > 1
    ) c;
  if collisions is not null then
    raise exception 'calendar_dates: više nedeljnih lista istog plana pada na isti dan (plan/dan): %', collisions
      using errcode = '23505',
            hint = 'Spoji ili obriši duplikate u public.shopping_lists, pa ponovo pokreni migraciju.';
  end if;
end;
$$;

alter table public.meal_plans
  alter column start_date type date using (start_date at time zone 'UTC')::date,
  alter column end_date type date using (end_date at time zone 'UTC')::date;

alter table public.meal_plan_entries
  alter column date type date using (date at time zone 'UTC')::date;

alter table public.shopping_lists
  alter column period_start type date using (period_start at time zone 'UTC')::date,
  alter column period_end type date using (period_end at time zone 'UTC')::date;
