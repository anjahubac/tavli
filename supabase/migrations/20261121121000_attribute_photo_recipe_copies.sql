-- Kopija nastala u servisnoj potvrdi pripada osobi koja prelazi.
create or replace function private.set_recipe_creator()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if current_setting('role', true) in ('none', 'service_role') then
      new.created_by := coalesce(auth.uid(), new.created_by);
    else
      new.created_by := auth.uid();
    end if;
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
