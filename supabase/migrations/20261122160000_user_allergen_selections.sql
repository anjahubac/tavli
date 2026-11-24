-- Store a complete selection per owner so offline edits and clearing it sync atomically.
create function private.valid_allergen_selection(codes text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select cardinality(codes) <= 14
     and coalesce(array_ndims(codes), 1) = 1
     and codes <@ array[
       'gluten', 'crustaceans', 'eggs', 'fish', 'peanuts', 'soy', 'milk', 'nuts',
       'celery', 'mustard', 'sesame', 'sulphites', 'lupin', 'molluscs'
     ]
     and cardinality(codes) = (select count(distinct code) from unnest(codes) code);
$$;

revoke execute on function private.valid_allergen_selection(text[]) from public, anon, authenticated;
grant execute on function private.valid_allergen_selection(text[]) to authenticated;

create table public.user_allergen_selections (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  group_codes text[] not null default '{}' check (private.valid_allergen_selection(group_codes)),
  updated_at timestamptz not null default clock_timestamp()
);

create index user_allergen_selections_sync_idx
  on public.user_allergen_selections (updated_at, user_id);

create trigger touch_updated_at before insert or update on public.user_allergen_selections
  for each row execute function private.touch_updated_at();

alter table public.user_allergen_selections enable row level security;
grant select, insert, update on public.user_allergen_selections to authenticated;
create policy "allergen selections: own select" on public.user_allergen_selections
  for select to authenticated using (user_id = (select auth.uid()));
create policy "allergen selections: own insert" on public.user_allergen_selections
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "allergen selections: own update" on public.user_allergen_selections
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
