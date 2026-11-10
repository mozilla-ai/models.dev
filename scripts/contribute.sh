#!/usr/bin/env bash
# Opens an upstream pull request carrying the named overlay files.
#
# Cuts feat/<name> from the mirror (origin/dev) in a throwaway worktree, copies
# the overlay files onto it, commits, pushes, and opens the PR against
# anomalyco/models.dev:dev. A provider model that names a base_model needs its
# lab file under models/<lab>/ in the same list. Once the PR merges, the hourly
# build reports each file as "landed upstream, delete overlay/<path>".
set -euo pipefail

usage="usage: contribute.sh <name> <PR title> <overlay path>..."
name="${1:?$usage}"
title="${2:?$usage}"
shift 2
[ $# -gt 0 ] || { echo "$usage" >&2; exit 2; }

root="$(git rev-parse --show-toplevel)"
for rel in "$@"; do
  [ -f "$root/overlay/$rel" ] || { echo "no overlay/$rel" >&2; exit 2; }
done

git -C "$root" fetch --quiet origin dev
wt="$(mktemp -d)/models.dev"
git -C "$root" worktree add --quiet -b "feat/$name" "$wt" origin/dev
trap 'git -C "$root" worktree remove --force "$wt"' EXIT

for rel in "$@"; do
  mkdir -p "$wt/$(dirname "$rel")"
  cp "$root/overlay/$rel" "$wt/$rel"
done
git -C "$wt" add -A
git -C "$wt" commit --quiet -m "$title"
git -C "$wt" push --quiet -u origin "feat/$name"
gh pr create -R anomalyco/models.dev -B dev -H "mozilla-ai:feat/$name" -t "$title" \
  -b "$(printf 'Files:\n\n%s\n' "$(printf -- '- `%s`\n' "$@")")"
