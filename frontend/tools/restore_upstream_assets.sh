#!/usr/bin/env bash
set -euo pipefail

# Reconstruct unchanged binary/platform assets from the pinned frontend source.
# This never modifies the original planit_front repository.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="https://github.com/yhooni29/planit_front.git"
REVISION="c4becdf0010d"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

git clone --quiet "$SOURCE" "$TEMP/original"
git -C "$TEMP/original" checkout --quiet "$REVISION"
for folder in assets android ios linux macos windows; do
  if [[ ! -d "$ROOT/$folder" ]]; then
    cp -R "$TEMP/original/$folder" "$ROOT/$folder"
  fi
done
mkdir -p "$ROOT/web"
find "$TEMP/original/web" -type f ! -name index.html ! -name manifest.json -print0 |
  while IFS= read -r -d '' source_file; do
    relative="${source_file#"$TEMP/original/web/"}"
    destination="$ROOT/web/$relative"
    mkdir -p "$(dirname "$destination")"
    cp -n "$source_file" "$destination"
  done

echo "Restored unchanged Flutter platform and binary assets from $REVISION"
