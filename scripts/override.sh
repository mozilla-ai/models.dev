#!/usr/bin/env bash
# Starts or refreshes an override of a file upstream already has.
#
# Copies upstream's current version of <path> into overlay/.base/<path>. A new
# override also gets that copy as overlay/<path>, to edit. An existing override
# keeps its overlay/<path>; the diff between the old and new base shows what
# upstream changed, so the override can be re-checked against it.
set -euo pipefail

rel="${1:?usage: override.sh <path under the upstream tree, e.g. providers/togetherai/models/Qwen/Qwen3.7-Max.toml>}"
root="$(git rev-parse --show-toplevel)"
file="$root/overlay/$rel"
b="$root/overlay/.base/$rel"

git -C "$root" fetch --quiet origin dev
mkdir -p "$(dirname "$file")" "$(dirname "$b")"
new="$(mktemp)"
git -C "$root" show "origin/dev:$rel" > "$new"

if [ -e "$file" ]; then
  if [ -e "$b" ]; then
    echo "upstream changed $rel as follows; re-check overlay/$rel against it:"
    git --no-pager diff --no-index -- "$b" "$new" || true
  fi
  mv "$new" "$b"
  echo "base refreshed: overlay/.base/$rel"
else
  cp "$new" "$file"
  mv "$new" "$b"
  echo "override started: edit overlay/$rel (base kept in overlay/.base/$rel)"
fi
