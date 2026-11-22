#!/bin/sh
# Dvosesijski test za #98: ubacivanje kućnog aliasa dok druga sesija briše
# roditelja (namirnicu). Alias mora da se tiho preskoči, ne da padne sa 23503
# (to klijent tretira kao trajnu grešku). Radi nad lokalnim Supabase-om
# (`supabase start`) i docker/colima; iza sebe briše sve što napravi.
set -eu
# psql ide kroz kontejner lokalnog Supabase-a (ime: supabase_db_<project_id>).
CT="${DB_CONTAINER:-supabase_db_tavli}"
q() { docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -qtA "$@"; }

# Pomoćne funkcije za pgTAP (idempotentno; nestaju sa `supabase db reset`).
q < "$(dirname "$0")/../supabase/tests/00_helpers.sql" >/dev/null

UID_A=$(q -c "select tests.create_user('race-$$@test.local')")
HH=$(q -c "select tests.household_of('$UID_A')")
FOOD=$(q -c "select gen_random_uuid()")
ALIAS=$(q -c "select gen_random_uuid()")
cleanup() { q -c "select public.delete_account_data('$UID_A')" >/dev/null 2>&1 || true
            q -c "delete from public.deletions where household_id = '$HH'" >/dev/null 2>&1 || true; }
trap cleanup EXIT

q -c "insert into public.foods (id, household_id, slug, name, category, base_unit) values ('$FOOD', '$HH', 'race', 'race', 'Ostalo', 'gram')"

# Sesija 1: briše namirnicu i drži transakciju otvorenom 3 s.
( q <<SQL >/dev/null
begin;
delete from public.foods where id = '$FOOD';
select pg_sleep(3);
commit;
SQL
) &
sleep 1

# Sesija 2: kao član domaćinstva ubacuje alias dok je brisanje u toku.
OUT=$(q 2>&1 <<SQL || true
begin;
select tests.authenticate_as('$UID_A');
insert into public.food_aliases (id, food_id, household_id, alias, alias_normalized)
  values ('$ALIAS', '$FOOD', '$HH', 'race', 'race');
commit;
SQL
)
wait
if echo "$OUT" | grep -qiE 'error|23503|violates'; then
  echo "FAIL: istovremeno brisanje roditelja daje grešku:"; echo "$OUT"; exit 1
fi
N=$(q -c "select count(*) from public.food_aliases where id = '$ALIAS'")
[ "$N" = "0" ] || { echo "FAIL: alias obrisane namirnice je upisan"; exit 1; }
echo "OK: alias se tiho preskače kad se roditelj briše istovremeno"
