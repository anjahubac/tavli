-- D3-005: ograničenje poziva po nalogu, jedan red po vrsti zahteva.
create table private.household_join_limits (
  user_id uuid not null references auth.users (id) on delete cascade,
  preview boolean not null,
  minute_started_at timestamptz not null,
  request_count integer not null,
  primary key (user_id, preview)
);

alter table private.household_join_limits enable row level security;
revoke all on private.household_join_limits from public, anon, authenticated;

create function private.allow_household_join_request(is_preview boolean)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  minute_start timestamptz := date_trunc('minute', clock_timestamp());
  requests integer;
begin
  if uid is null then raise insufficient_privilege; end if;
  insert into private.household_join_limits as limits
    (user_id, preview, minute_started_at, request_count)
  values (uid, is_preview, minute_start, 1)
  on conflict (user_id, preview) do update
    set minute_started_at = excluded.minute_started_at,
        request_count = case
          when limits.minute_started_at < excluded.minute_started_at then 1
          else least(limits.request_count + 1, 61)
        end
  returning request_count into requests;
  return requests <= case when is_preview then 60 else 15 end;
end;
$$;

revoke all on function private.allow_household_join_request(boolean)
  from public, anon, authenticated;

alter function public.preview_household_join(text) set schema private;
alter function public.confirm_household_join(text, uuid, text, boolean, uuid) set schema private;
revoke all on function private.preview_household_join(text) from public, anon, authenticated;
revoke all on function private.confirm_household_join(text, uuid, text, boolean, uuid)
  from public, anon, authenticated;

create function public.preview_household_join(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.allow_household_join_request(true) then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  return private.preview_household_join(token);
end;
$$;

create function public.confirm_household_join(
  token text,
  expected_source_household_id uuid,
  recipe_choice text,
  source_deletion_ack boolean,
  operation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.allow_household_join_request(false) then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  return private.confirm_household_join(
    token, expected_source_household_id, recipe_choice, source_deletion_ack, operation_id
  );
end;
$$;

revoke all on function public.preview_household_join(text) from public, anon;
revoke all on function public.confirm_household_join(text, uuid, text, boolean, uuid)
  from public, anon;
grant execute on function public.preview_household_join(text) to authenticated;
grant execute on function public.confirm_household_join(text, uuid, text, boolean, uuid)
  to authenticated;
