-- 006a: brisanje naloga (zove ga Edge Function delete-account sa service_role).
-- Briše domaćinstva u kojima je osoba jedini član (kaskada briše podatke i
-- članstva), ostala članstva, ocene, profil ukusa, tragove i profil.
-- Slike se brišu kroz Storage API u funkciji, a auth korisnik posle ovoga.
-- Idempotentno: drugi poziv ne radi ništa.

-- Domaćinstva u kojima je osoba jedini član (njihove slike Edge Function
-- briše pre podataka).
create or replace function public.solo_households(uid uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.household_id
    from public.household_members m
   where m.user_id = uid
     and not exists (
       select 1 from public.household_members o
        where o.household_id = m.household_id and o.user_id <> uid
     );
$$;

revoke execute on function public.solo_households(uuid) from public, anon, authenticated;
grant execute on function public.solo_households(uuid) to service_role;

create or replace function public.delete_account_data(uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  solo uuid[];
begin
  select coalesce(array_agg(h), '{}') into solo from public.solo_households(uid) h;

  delete from public.ratings where user_id = uid;
  delete from public.taste_profiles where user_id = uid;
  delete from public.households where id = any (solo);
  delete from public.household_members where user_id = uid;
  -- Tragovi nastaju i iz brisanja iznad, pa se brišu poslednji.
  delete from public.deletions where household_id = any (solo) or user_id = uid;
  delete from public.profiles where id = uid;
end;
$$;

revoke execute on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;
