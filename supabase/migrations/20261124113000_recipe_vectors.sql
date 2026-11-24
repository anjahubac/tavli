-- Household-wide opt-in recorded by a signed-in member before recipe text is sent.
create table private.recipe_vector_consents (
  household_id uuid primary key references public.households (id) on delete cascade,
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now()
);

alter table private.recipe_vector_consents enable row level security;
revoke all on private.recipe_vector_consents from public, anon, authenticated;

create function public.enable_recipe_vector_indexing(p_household_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
begin
  if not coalesce(private.is_member(p_household_id), false) then
    return false;
  end if;

  insert into private.recipe_vector_consents (household_id, granted_by)
  values (p_household_id, auth.uid())
  on conflict (household_id) do nothing;
  return true;
end;
$$;

revoke all on function public.enable_recipe_vector_indexing(uuid) from public, anon, authenticated;
grant execute on function public.enable_recipe_vector_indexing(uuid) to authenticated;

-- One derived row per recipe. Pending rows also serve as the durable work queue.
create table private.recipe_vectors (
  recipe_id text primary key,
  household_id uuid not null,
  model text not null default '@cf/baai/bge-m3'
    check (model = '@cf/baai/bge-m3'),
  embedding extensions.vector(1024),
  lease uuid,
  retry_at timestamptz not null default now(),
  foreign key (recipe_id, household_id)
    references public.recipes (id, household_id) on delete cascade
);

alter table private.recipe_vectors enable row level security;
revoke all on private.recipe_vectors from public, anon, authenticated;

create index recipe_vectors_pending on private.recipe_vectors (retry_at, recipe_id)
  where embedding is null;

create function private.queue_recipe_vector()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and
    row(new.title, new.ingredients, new.meal_types, new.weight, new.dish_kind, new.prep_minutes)
    is not distinct from
    row(old.title, old.ingredients, old.meal_types, old.weight, old.dish_kind, old.prep_minutes)
  then
    return new;
  end if;
  insert into private.recipe_vectors (recipe_id, household_id)
  values (new.id, new.household_id)
  on conflict (recipe_id) do update
    set embedding = null, lease = null, retry_at = now();
  return new;
end;
$$;
revoke all on function private.queue_recipe_vector() from public, anon, authenticated;

create trigger queue_recipe_vector
  after insert or update of title, ingredients, meal_types, weight, dish_kind, prep_minutes on public.recipes
  for each row execute function private.queue_recipe_vector();

-- Track IDs only, including recipes added concurrently with consent. The worker
-- cannot claim or read recipe text until the household opts in.
insert into private.recipe_vectors (recipe_id, household_id)
select id, household_id from public.recipes
on conflict (recipe_id) do nothing;

create function public.claim_recipe_vectors()
returns table (recipe_id text, lease uuid, content text)
language sql security definer set search_path = ''
as $$
  with batch as (
    select v.recipe_id from private.recipe_vectors v
    where v.embedding is null and v.retry_at <= now()
      and exists (
        select 1 from private.recipe_vector_consents consent
        where consent.household_id = v.household_id
      )
    order by v.retry_at, v.recipe_id
    limit 16 for update skip locked
  ), claimed as (
    update private.recipe_vectors v
    set retry_at = now() + interval '10 minutes', lease = gen_random_uuid()
    from batch where batch.recipe_id = v.recipe_id
    returning v.recipe_id, v.lease
  )
  select c.recipe_id, c.lease,
    'Naslov: ' || left(r.title, 250) ||
    E'\nOznake: ' || concat_ws(', ',
      array_to_string(r.meal_types, ', '), r.weight, r.dish_kind) ||
    coalesce(E'\nVreme pripreme: ' || r.prep_minutes || ' min', '') ||
    E'\nSastojci: ' || left(coalesce((
      select string_agg(i.value->>'name', ', ' order by i.position)
      from jsonb_array_elements(
        case when jsonb_typeof(r.ingredients) = 'array'
          then r.ingredients else '[]'::jsonb end
      ) with ordinality as i(value, position)
    ), ''), 1500)
  from claimed c join public.recipes r on r.id = c.recipe_id;
$$;

create function public.complete_recipe_vector(
  p_recipe_id text, p_lease uuid, p_embedding extensions.vector(1024)
)
returns boolean language sql security definer set search_path = ''
as $$
  with saved as (
    update private.recipe_vectors
    set embedding = p_embedding, lease = null
    where recipe_id = p_recipe_id and lease = p_lease and embedding is null
      and extensions.vector_dims(p_embedding) = 1024
      and extensions.vector_norm(p_embedding) > 0
    returning 1
  )
  select exists (select 1 from saved);
$$;

revoke all on function public.claim_recipe_vectors() from public, anon, authenticated;
revoke all on function public.complete_recipe_vector(text, uuid, extensions.vector)
  from public, anon, authenticated;
grant execute on function public.claim_recipe_vectors() to service_role;
grant execute on function public.complete_recipe_vector(text, uuid, extensions.vector)
  to service_role;

-- Verify the caller's household and restrict ranking to the eligible recipe IDs. The client uses its existing filters, including fasting.
create function public.rank_recipe_vectors(
  p_embedding extensions.vector(1024), p_recipe_ids text[]
)
returns table (recipe_id text, distance double precision)
language sql stable security definer set search_path = ''
as $$
  select v.recipe_id, v.embedding operator(extensions.<=>) p_embedding
  from private.recipe_vectors v
  where cardinality(p_recipe_ids) <= 256
    and v.recipe_id = any(p_recipe_ids)
    and private.is_member(v.household_id)
    and exists (
      select 1 from private.recipe_vector_consents consent
      where consent.household_id = v.household_id
    )
    and v.embedding is not null
    and extensions.vector_dims(p_embedding) = 1024
    and extensions.vector_norm(p_embedding) > 0
  order by 2, v.recipe_id
  limit 24;
$$;
revoke all on function public.rank_recipe_vectors(extensions.vector, text[])
  from public, anon;
grant execute on function public.rank_recipe_vectors(extensions.vector, text[])
  to authenticated;

-- Follow the Vault/pg_net convention used by household-photo-cleanup.
select cron.schedule('recipe-vector-index', '* * * * *', $job$
  select net.http_post(
    url := rtrim(project.decrypted_secret, '/') || '/functions/v1/recipe-vector-index',
    headers := jsonb_build_object('Authorization', 'Bearer ' || token.decrypted_secret),
    timeout_milliseconds := 60000
  )
  from vault.decrypted_secrets project, vault.decrypted_secrets token
  where project.name = 'recipe_vector_index_url'
    and token.name = 'recipe_vector_index_token'
    and length(token.decrypted_secret) >= 32
    and exists (
      select 1 from private.recipe_vectors v
      where v.embedding is null and v.retry_at <= now()
        and exists (
          select 1 from private.recipe_vector_consents consent
          where consent.household_id = v.household_id
        )
    );
$job$);
