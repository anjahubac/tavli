#!/bin/sh
# 015 slice 2: paralelne rezervacije ne smeju da prođu preko limita. Pokreće N
# sesija odjednom sa dnevnim limitom L < N; tačno L mora da uspe, a u tabeli
# ostaje tačno L redova. Radi nad lokalnim Supabase-om (`supabase start`) kroz
# docker/colima kontejner; iza sebe briše sve što napravi.
set -eu
CT="${DB_CONTAINER:-supabase_db_tavli}"
N="${N:-12}"
LIMIT="${LIMIT:-3}"
q() { docker exec -i "$CT" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -qtA "$@"; }

q < "$(dirname "$0")/../supabase/tests/00_helpers.sql" >/dev/null
UID_A=$(q -c "select tests.create_user('ai-race-$$@test.local')")
# Brisanje naloga ostavlja redove sa user_id null (to je i namena); brišu se samo
# oni napravljeni od ovog pokretanja (posle trenutka GO), tuđi ostaju.
cleanup() { q -c "delete from auth.users where id = '$UID_A'" >/dev/null 2>&1 || true
            [ -z "${GO:-}" ] || q -c "delete from public.ai_calls where user_id is null and started_at >= to_timestamp($GO) - interval '10 seconds'" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Sesije se pokreću kroz docker različitim tempom, pa sve čekaju isti trenutak
# (3 s unapred) da bi se pozivi zaista preklopili.
GO=$(q -c "select (extract(epoch from clock_timestamp()) + 3)::text")
TMP=$(mktemp -d)
i=1
while [ "$i" -le "$N" ]; do
  ( q -c "select pg_sleep(greatest(0, $GO - extract(epoch from clock_timestamp()))); select public.ai_reserve('$UID_A', 'text', $LIMIT, 1000, 1000, 100000) ? 'id'" | grep -v '^$' | tail -1 > "$TMP/$i" ) &
  i=$((i + 1))
done
wait
OK=$(cat "$TMP"/* | grep -c '^t$' || true)
ROWS=$(q -c "select count(*) from public.ai_calls where user_id = '$UID_A'")
rm -rf "$TMP"
if [ "$OK" != "$LIMIT" ] || [ "$ROWS" != "$LIMIT" ]; then
  echo "FAIL: $N paralelnih zahteva, limit $LIMIT: uspelo $OK, redova $ROWS"; exit 1
fi
echo "OK: od $N paralelnih zahteva tačno $LIMIT je prošlo (limit $LIMIT)"
