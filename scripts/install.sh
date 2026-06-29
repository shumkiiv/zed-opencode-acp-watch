#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
prefix=${PREFIX:-"$HOME/.local"}
bin_dir=${BIN_DIR:-"$prefix/bin"}
target=${TARGET:-"$bin_dir/opencode-acp-watch"}
source_file="$repo_dir/bin/opencode-acp-watch"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

mkdir -p "$bin_dir"

if [ -e "$target" ]; then
  backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$target" "$backup"
  echo "Backup: $backup"
fi

install -m 0755 "$source_file" "$target"
python3 -m py_compile "$target"

echo "Installed: $target"
echo "Use this absolute path in Zed settings.json."
