-- 026 / Task 1: privatne kuvarske knjige i izolovan retrieval.
-- Knjigu i njene chunkove piše samo server (service_role) posle obrade;
-- član domaćinstva ih čita i briše. Svaki chunk nosi knjigu i stranicu.

create extension if not exists vector with schema extensions;

create table public.cookbooks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  filename text not null check (char_length(filename) between 1 and 255),
  -- Putanja u bucketu cookbooks: {household_id}/{ime}; prvi deo čuva RLS skladišta.
  storage_path text not null check (char_length(storage_path) between 1 and 400),
  status text not null default 'uploaded'
    check (status in ('uploaded', 'processing', 'ready', 'failed')),
  pages int check (pages is null or pages >= 1),
  -- Obrada se nastavlja od ove stranice posle prekida (bez duplikata).
  next_page int not null default 1 check (next_page >= 1),
  error_code text check (error_code is null or char_length(error_code) <= 60),
  -- Kad je obrada preuzeta (claim_cookbook); null kad niko ne radi na knjizi.
  claimed_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, storage_path),
  -- Cilj složenog stranog ključa chunkova: chunk mora u domaćinstvo svoje knjige.
  unique (id, household_id)
);

create table public.cookbook_chunks (
  id uuid primary key default gen_random_uuid(),
  cookbook_id uuid not null,
  household_id uuid not null,
  page int not null check (page >= 1),
  chunk_index int not null check (chunk_index >= 0),
  content text not null check (char_length(content) between 1 and 4000),
  embedding extensions.vector(768) not null,
  -- Ponovljena obrada iste stranice ne pravi duplikate.
  unique (cookbook_id, page, chunk_index),
  foreign key (cookbook_id, household_id)
    references public.cookbooks (id, household_id) on delete cascade
);

-- Pretraga se prvo sužava na domaćinstva korisnika, pa tek onda rangira. Bez
-- ANN indeksa je rangiranje tačno; kad knjiga bude previše, indeks mora da
-- čuva isti filter (partitioned ili iterativni HNSW), ne da filtrira posle.
create index cookbook_chunks_household_idx on public.cookbook_chunks (household_id, cookbook_id);
create index cookbooks_household_idx on public.cookbooks (household_id, created_at);

alter table public.cookbooks enable row level security;
alter table public.cookbook_chunks enable row level security;

revoke all on public.cookbooks, public.cookbook_chunks from public, anon, authenticated;
grant select, delete on public.cookbooks to authenticated;
grant select on public.cookbook_chunks to authenticated;

create policy "cookbooks: members select" on public.cookbooks
  for select to authenticated using (private.is_member(household_id));
create policy "cookbooks: members delete" on public.cookbooks
  for delete to authenticated using (private.is_member(household_id));
create policy "cookbook_chunks: members select" on public.cookbook_chunks
  for select to authenticated using (private.is_member(household_id));

-- Najviše 20 knjiga po domaćinstvu, u bazi: provera u funkciji pre upisa ne bi
-- zaustavila dva istovremena zahteva. Advisory lock po domaćinstvu serijalizuje
-- upise, pa drugi vidi red prvog.
create or replace function private.limit_cookbooks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('cookbooks:' || new.household_id::text, 0));
  if (select count(*) from public.cookbooks where household_id = new.household_id) >= 20 then
    raise exception 'cookbook_limit' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
revoke execute on function private.limit_cookbooks() from public, anon, authenticated;
create trigger limit_cookbooks before insert on public.cookbooks
  for each row execute function private.limit_cookbooks();

-- Obradu knjige u jednom trenutku radi samo jedan poziv: dva istovremena poziva
-- bi dvaput platila embedding. Preuzimanje starije od p_stale_seconds (srušen
-- poziv) se može preuzeti ponovo. Gotova i neuspela knjiga se ne preuzima.
create or replace function public.claim_cookbook(p_id uuid, p_stale_seconds int default 150)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.cookbooks
  set claimed_at = clock_timestamp(), status = 'processing', updated_at = now()
  where id = p_id
    and status in ('uploaded', 'processing')
    and (claimed_at is null
         or claimed_at < clock_timestamp() - make_interval(secs => p_stale_seconds));
  return found;
end;
$$;

create or replace function public.release_cookbook(p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.cookbooks set claimed_at = null where id = p_id;
$$;

revoke execute on function public.claim_cookbook(uuid, int) from public, anon, authenticated;
revoke execute on function public.release_cookbook(uuid) from public, anon, authenticated;
grant execute on function public.claim_cookbook(uuid, int) to service_role;
grant execute on function public.release_cookbook(uuid) to service_role;

-- Najbliži chunkovi iz knjiga domaćinstava u kojima je korisnik član. Poziva ga
-- samo funkcija koja je već proverila token; članstvo se ipak proverava ovde.
create or replace function public.cookbook_search(
  p_user_id uuid,
  p_embedding extensions.vector(768),
  p_limit int,
  p_book_id uuid default null
)
returns table (
  chunk_id uuid,
  cookbook_id uuid,
  title text,
  page int,
  content text,
  score float8
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_embedding is null
     or p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'cookbook_search: neispravan ulaz' using errcode = '22023';
  end if;
  return query
  select ch.id, ch.cookbook_id, b.title, ch.page, ch.content,
         (1 - (ch.embedding operator(extensions.<=>) p_embedding))::float8
  from public.cookbook_chunks ch
  join public.cookbooks b on b.id = ch.cookbook_id and b.status = 'ready'
  where ch.household_id in (
          select m.household_id from public.household_members m
          where m.user_id = p_user_id)
    and (p_book_id is null or ch.cookbook_id = p_book_id)
  order by ch.embedding operator(extensions.<=>) p_embedding
  limit p_limit;
end;
$$;

revoke execute on function public.cookbook_search(uuid, extensions.vector, int, uuid)
  from public, anon, authenticated;
grant execute on function public.cookbook_search(uuid, extensions.vector, int, uuid)
  to service_role;

-- Privatno skladište: {household_id}/{ime}; samo PDF i EPUB, najviše 15 MB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cookbooks', 'cookbooks', false, 15728640,
        array['application/pdf', 'application/epub+zip'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "cookbooks: members select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'cookbooks'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
create policy "cookbooks: members insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'cookbooks'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
create policy "cookbooks: members delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'cookbooks'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
