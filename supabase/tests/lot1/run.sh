#!/bin/bash
# Usage : ./run.sh [avec_85]  — reconstruit une base jetable, rejoue 01→84 (+85 si demandé), lance les scénarios.
set -e
DB=edl_lot1
MIG=$(cd "$(dirname "$0")/../../migrations" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
STUBS=${STUBS:-$HERE/supabase_stubs.sql}
su postgres -c "psql -q -c 'drop database if exists $DB' -c 'create database $DB'" >/dev/null
su postgres -c "psql -q -d $DB -v ON_ERROR_STOP=1 -f $STUBS" >/dev/null
for f in $(ls "$MIG"/*.sql); do
  b=$(basename "$f")
  [ "$b" = "85_access_hardening_lot1.sql" ] && [ "$1" != "avec_85" ] && continue
  [ "$b" = "65_ia007_test_skills_seed.sql" ] && continue   # seed à identifiants codés en dur
  sed '/create extension.*pg_cron/Id' "$f" > /tmp/_m.sql
  su postgres -c "psql -q -d $DB -v ON_ERROR_STOP=1 -f /tmp/_m.sql" >/dev/null 2>/tmp/_err || { echo "ÉCHEC migration $b"; cat /tmp/_err; exit 1; }
done
su postgres -c "psql -q -d $DB -v ON_ERROR_STOP=1 -f $HERE/seed.sql" >/dev/null
su postgres -c "psql -q -d $DB -f $HERE/attack_scenarios.sql" 2>&1 | grep -E "OK|FAILLE|ERROR"
