#!/usr/bin/env sh
set -eu

db=${OPENCODE_ACP_WATCH_DB:-"$HOME/.local/share/opencode/opencode.db"}
log=${OPENCODE_LOG:-"$HOME/.local/share/opencode/log/opencode.log"}
limit=${LIMIT:-20}

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required" >&2
  exit 1
fi

if [ ! -f "$db" ]; then
  echo "OpenCode DB not found: $db" >&2
  exit 1
fi

date '+%F %T %Z'

echo
echo "Files:"
stat -c '%n %y %s' "$db" "$db-wal" "$log" 2>/dev/null || true

echo
echo "Recent sessions:"
sqlite3 -header -column "$db" "
select
  s.id,
  datetime(s.time_updated/1000,'unixepoch','localtime') updated,
  cast((strftime('%s','now')*1000 - s.time_updated)/1000 as integer) age_sec,
  s.title,
  s.agent,
  s.directory,
  s.parent_id
from session s
order by s.time_updated desc
limit $limit;
"

echo
echo "Running or pending tools:"
sqlite3 -header -column "$db" "
select
  p.id,
  p.session_id,
  s.title,
  s.directory,
  datetime(p.time_updated/1000,'unixepoch','localtime') updated,
  cast((strftime('%s','now')*1000 - p.time_updated)/1000 as integer) age_sec,
  json_extract(p.data,'$.state.status') status,
  json_extract(p.data,'$.tool') tool
from part p
join session s on s.id=p.session_id
where json_extract(p.data,'$.type')='tool'
  and json_extract(p.data,'$.state.status') in ('pending','running')
order by p.time_updated desc
limit $limit;
"
