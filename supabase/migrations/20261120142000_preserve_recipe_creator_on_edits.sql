-- D3-005: autor ostaje nepromenljiv pri izmenama, a uklanja se sa nalogom.
create or replace function private.set_recipe_creator()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  elsif new.created_by is distinct from old.created_by and (
    new.created_by is not null or exists (
      select 1 from auth.users u where u.id = old.created_by
    )
  ) then
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;
