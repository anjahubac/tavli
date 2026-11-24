-- RLS is bypassed by service_role, but it still needs table privileges for
-- registration, resumable processing and chunk insertion via PostgREST.
grant select, insert, update on public.cookbooks to service_role;
grant select, insert on public.cookbook_chunks to service_role;
-- cookbook-process checks the signed-in user's household before using storage.
grant select (user_id, household_id) on public.household_members to service_role;
