-- D3-005: kraći ručni unos. Ranije podeljeni kodovi ostaju važeći.
create or replace function private.new_household_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(substr('0123456789ABCDEFGHJKMNPQRSTVWXYZ',
    (get_byte(random.bytes, position.index) & 31) + 1, 1), '' order by position.index)
  from (select extensions.gen_random_bytes(12) as bytes) random
  cross join generate_series(0, 11) as position(index);
$$;

create or replace function private.normalize_household_invite_code(value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  with normalized as (
    select regexp_replace(upper(value), '[-[:space:]]', '', 'g') as code
    where length(value) <= 80
  )
  select case
    when value ~ '^[0-9a-f]{64}$' then value
    when code ~ '^([0-9A-HJKMNP-TV-Z]{12}|[0-9A-HJKMNP-TV-Z]{16})$' then code
  end
  from normalized;
$$;

create or replace function public.household_invite_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  invite text;
begin
  if uid is null then raise insufficient_privilege; end if;
  select m.household_id into hid from public.household_members m
    where m.user_id = uid and m.role = 'owner';
  if hid is null then raise insufficient_privilege; end if;
  -- Koristi isti red kao potvrda prelaska, pa ponovo proveri vlasnika.
  perform 1 from public.households h where h.id = hid for key share;
  if not exists (
    select 1 from public.household_members m
      where m.household_id = hid and m.user_id = uid and m.role = 'owner'
  ) then
    raise insufficient_privilege;
  end if;
  select i.token into invite from private.household_invites i where i.household_id = hid;
  if found then return invite; end if;

  for attempt in 1..3 loop
    insert into private.household_invites (household_id) values (hid)
      on conflict do nothing;
    select i.token into invite from private.household_invites i where i.household_id = hid;
    if found then return invite; end if;
  end loop;
  raise exception 'Invite code generation failed';
end;
$$;
