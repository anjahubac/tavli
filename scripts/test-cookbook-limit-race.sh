#!/bin/sh
# 026: paralelni upisi knjiga ne smeju da pređu granicu od 20 po domaćinstvu.
# Domaćinstvo ima 17 knjiga, 8 sesija istovremeno upisuje po jednu: tačno 3 mora
# da uspe. Radi nad lokalnim Supabase-om kroz docker/colima kontejner.
set -eu
CT="${DB_CONTAINER:-supabase_db_tavli}"
q() { docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=0 -qtA "$@"; }
q < "$(dirname "$0")/../supabase/tests/00_helpers.sql" >/dev/null 2>&1
UID_A=$(q -c "select tests.create_user('cb-race-$$@test.local')")
HH=$(q -c "select tests.household_of('$UID_A')")
cleanup() { q -c "delete from public.households where id = '$HH'" >/dev/null 2>&1 || true
            q -c "delete from auth.users where id = '$UID_A'" >/dev/null 2>&1 || true; }
trap cleanup EXIT
q -v ON_ERROR_STOP=1 -c "insert into public.cookbooks (household_id, title, filename, storage_path, content_sha256)
  select '$HH', 'k'||i, 'k'||i||'.pdf', '$HH/k'||i||'.pdf', encode(sha256(convert_to('k'||i, 'UTF8')), 'hex')
  from generate_series(1,17) i" >/dev/null
GO=$(q -c "select (extract(epoch from clock_timestamp()) + 3)::text")
TMP=$(mktemp -d); i=1
while [ "$i" -le 8 ]; do
  ( q -c "select pg_sleep(greatest(0, $GO - extract(epoch from clock_timestamp())));
    insert into public.cookbooks (household_id, title, filename, storage_path, content_sha256)
      values ('$HH', 'r$i', 'r$i.pdf', '$HH/r$i.pdf', encode(sha256(convert_to('r$i', 'UTF8')), 'hex'))" >/dev/null 2>"$TMP/$i" ) &
  i=$((i + 1))
done
wait
ROWS=$(q -c "select count(*) from public.cookbooks where household_id = '$HH'")
rm -rf "$TMP"
if [ "$ROWS" != "20" ]; then echo "FAIL: domaćinstvo ima $ROWS knjiga umesto 20"; exit 1; fi
echo "OK: od 8 paralelnih upisa tačno 3 je prošlo, ukupno 20"
