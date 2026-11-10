#!/usr/bin/env bash
# Lays the overlay over an upstream checkout.
#
# For each file F under the overlay (overlay/.base excluded), with U upstream's
# copy and B the base in overlay/.base the override was written against:
#   no U, no B        addition: copied
#   U == F            landed upstream: warned, not copied, delete overlay/F
#   U, B == U         override still valid: copied, the overlay wins
#   U, B != U         upstream moved under the override: fails
#   U, no B, U != F   upstream has its own F: fails
#   B without F       stale base: fails
# A failure stops the publish; the previous Pages deployment stays live.
set -euo pipefail

usage="usage: apply-overlay.sh <overlay dir> <upstream checkout>"
overlay="${1:?$usage}"
target="${2:?$usage}"
base="$overlay/.base"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
failed=0
copied=0

fail() {
  echo "::error::$*"
  echo "- FAIL: $*" >> "$summary"
  failed=1
}
landed() {
  echo "::warning::$1 landed upstream unchanged; delete overlay/$1"
  echo "- landed upstream, delete overlay/$1" >> "$summary"
}

while IFS= read -r -d '' file; do
  rel="${file#"$overlay"/}"
  up="$target/$rel"
  b="$base/$rel"
  if [ ! -e "$up" ]; then
    if [ -e "$b" ]; then
      fail "upstream has no $rel but overlay/.base/$rel exists; delete the base"
      continue
    fi
    mkdir -p "$(dirname "$up")"
    cp "$file" "$up"
    copied=$((copied + 1))
  elif cmp -s "$file" "$up"; then
    landed "$rel"
  elif [ -e "$b" ]; then
    if cmp -s "$b" "$up"; then
      cp "$file" "$up"
      copied=$((copied + 1))
    else
      fail "upstream changed $rel since the override was written; re-check overlay/$rel, then run scripts/override.sh $rel to refresh its base, or delete both"
    fi
  else
    fail "upstream has its own $rel; delete overlay/$rel to keep upstream's, or run scripts/override.sh $rel and reapply the change"
  fi
done < <(find "$overlay" -path "$base" -prune -o -type f -print0 | sort -z)

if [ -d "$base" ]; then
  while IFS= read -r -d '' file; do
    rel="${file#"$base"/}"
    [ -e "$overlay/$rel" ] || fail "overlay/.base/$rel has no overlay/$rel; delete it"
  done < <(find "$base" -type f -print0)
fi

echo "overlay: $copied file(s) applied" | tee -a "$summary"
exit "$failed"
