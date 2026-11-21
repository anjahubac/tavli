-- Synthetic rehearsal of the shopping period constraints from
-- 20261102120000_plan_and_shopping.sql. Run on a disposable database.
begin;

create temp table shopping_period_fixture (
  id text primary key,
  meal_plan_id text,
  period_start timestamptz,
  period_end timestamptz,
  created_at timestamptz not null default '2026-12-30T23:00:00Z',
  check ((period_start is null) = (period_end is null)),
  check (period_start is null or period_start <= period_end),
  constraint fixture_plan_period_unique unique (meal_plan_id, period_start)
);

insert into shopping_period_fixture (id, meal_plan_id, period_start, period_end)
values
  ('early', 'plan-a', '2026-12-31T00:00:00Z', '2027-01-06T00:00:00Z'),
  ('late', 'plan-a', '2027-01-01T00:30:00+01:00', '2027-01-06T00:00:00Z'),
  ('other-plan', 'plan-b', '2026-12-31T00:00:00Z', '2027-01-06T00:00:00Z'),
  ('standalone-a', null, null, null),
  ('standalone-b', null, null, null);

do $$
declare
  collision record;
  violated_constraint text;
begin
  select meal_plan_id, (period_start at time zone 'UTC')::date as utc_day,
         count(*) as row_count
    into strict collision
    from shopping_period_fixture
   where meal_plan_id is not null and period_start is not null
   group by meal_plan_id, (period_start at time zone 'UTC')::date
  having count(*) > 1;

  if collision.meal_plan_id is distinct from 'plan-a'
      or collision.utc_day is distinct from date '2026-12-31'
      or collision.row_count is distinct from 2::bigint then
    raise exception 'Expected exactly the two plan-a rows to collide';
  end if;

  begin
    alter table shopping_period_fixture
      alter column period_start type date using (period_start at time zone 'UTC')::date,
      alter column period_end type date using (period_end at time zone 'UTC')::date;
    raise exception 'Expected the existing unique constraint to reject conversion';
  exception when unique_violation then
    get stacked diagnostics violated_constraint = constraint_name;
    if violated_constraint is distinct from 'fixture_plan_period_unique' then
      raise;
    end if;
  end;
end
$$;

-- Remove only the duplicate in this synthetic control. This is not a
-- decision about how to repair real or queued data.
delete from shopping_period_fixture where id = 'early';

alter table shopping_period_fixture
  alter column period_start type date using (period_start at time zone 'UTC')::date,
  alter column period_end type date using (period_end at time zone 'UTC')::date;

do $$
begin
  if (select count(*) from shopping_period_fixture) <> 4
      or not exists (
        select 1 from shopping_period_fixture
         where id = 'late' and period_start = date '2026-12-31'
           and period_end = date '2027-01-06'
           and created_at = timestamptz '2026-12-30T23:00:00Z'
      )
      or (select count(*) from shopping_period_fixture
          where meal_plan_id is null and period_start is null and period_end is null) <> 2 then
    raise exception 'Clean control must keep UTC days, event time and null bounds';
  end if;

  begin
    insert into shopping_period_fixture (id, meal_plan_id, period_start, period_end)
    values ('reversed', 'plan-a', date '2027-01-07', date '2027-01-06');
    raise exception 'Expected the period ordering check to reject reversed days';
  exception when check_violation then
    null;
  end;
end
$$;

rollback;
