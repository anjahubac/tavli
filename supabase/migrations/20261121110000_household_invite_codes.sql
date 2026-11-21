-- D3-005: isti kod služi za ručni unos, QR i deljenje linka.
create function private.new_household_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(substr('0123456789ABCDEFGHJKMNPQRSTVWXYZ',
    (get_byte(random.bytes, position.index) & 31) + 1, 1), '' order by position.index)
  from (select extensions.gen_random_bytes(16) as bytes) random
  cross join generate_series(0, 15) as position(index);
$$;

alter table private.household_invites
  alter column token set default private.new_household_invite_code();

create function private.normalize_household_invite_code(value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when length(value) > 80 then null
    when value ~ '^[0-9a-f]{64}$' then value
    when regexp_replace(upper(value), '[-[:space:]]', '', 'g')
      ~ '^[0-9A-HJKMNP-TV-Z]{16}$'
      then regexp_replace(upper(value), '[-[:space:]]', '', 'g')
  end;
$$;

revoke all on function private.new_household_invite_code() from public, anon, authenticated;
revoke all on function private.normalize_household_invite_code(text) from public, anon, authenticated;

create or replace function public.preview_household_join(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.allow_household_join_request(true) then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  return private.preview_household_join(private.normalize_household_invite_code(token));
end;
$$;
