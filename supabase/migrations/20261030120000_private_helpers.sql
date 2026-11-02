-- 006a: pomoćna šema `private` (nije u [api] schemas, pa nije dostupna preko API-ja)
-- i podrazumevana prava: nove tabele i funkcije se NE otvaraju automatski.

create schema if not exists private;
revoke all on schema private from public;
-- Politike se izvršavaju sa pravima pozivaoca, pa `authenticated` mora da vidi
-- šemu; izvršavanje je dozvoljeno samo za private.is_member (sledeća migracija).
grant usage on schema private to authenticated;

-- Nove tabele u `public` ne dobijaju prava za anon/authenticated; dodeljuju
-- se izričito po tabeli (20261030120500_rls_and_grants.sql).
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;
-- Funkcije su podrazumevano izvršive za PUBLIC; to se ukida globalno
-- (podrazumevana prava po šemi mogu samo da dodaju).
alter default privileges revoke execute on functions from public;

-- updated_at uvek postavlja server (clock_timestamp raste i unutar transakcije);
-- argument 'updated_by' upisuje i ko je menjao.
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  if tg_nargs > 0 and tg_argv[0] = 'updated_by' then
    new.updated_by := coalesce(auth.uid(), new.updated_by);
  end if;
  return new;
end;
$$;

revoke execute on function private.touch_updated_at() from public, anon, authenticated;
