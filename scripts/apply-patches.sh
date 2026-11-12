#!/usr/bin/env bash
# Applies the patches in patches/ to an upstream checkout, before the overlay.
#
# A patch carries a code change that waits for an upstream merge. Each one is
# the commit of an open upstream pull request (git format-patch -U1 of its
# feat/<name> branch). For each patch P:
#   P applies             copied in: applied
#   P applies in reverse  landed upstream: warned, delete patches/P
#   neither               upstream moved under P: fails
# A failure stops the publish; the previous Pages deployment stays live.
set -euo pipefail

usage="usage: apply-patches.sh <patches dir> <upstream checkout>"
patches="${1:?$usage}"
target="${2:?$usage}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
failed=0
applied=0

[ -d "$patches" ] || { echo "patches: none" | tee -a "$summary"; exit 0; }

while IFS= read -r -d '' file; do
  name="$(basename "$file")"
  abs="$(cd "$(dirname "$file")" && pwd)/$name"
  if git -C "$target" apply --check "$abs" 2>/dev/null; then
    git -C "$target" apply "$abs"
    applied=$((applied + 1))
  elif git -C "$target" apply --reverse --check "$abs" 2>/dev/null; then
    echo "::warning::$name landed upstream; delete patches/$name"
    echo "- landed upstream, delete patches/$name" >> "$summary"
  else
    echo "::error::$name no longer applies; if upstream merged it, delete patches/$name, else rebase its feat branch on dev and regenerate it"
    echo "- FAIL: $name no longer applies" >> "$summary"
    git -C "$target" apply --check "$abs" || true
    failed=1
  fi
done < <(find "$patches" -name '*.patch' -type f -print0 | sort -z)

echo "patches: $applied applied" | tee -a "$summary"
exit "$failed"
