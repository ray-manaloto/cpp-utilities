#!/bin/sh
# Fails when two fresh `pkl eval` runs differ, or when the committed
# generated fixture files differ from them, including files the generator
# no longer emits. Writes only to a temporary directory.
set -eu
cd "$(dirname "$0")/../fixture"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
mkdir "$work/fresh" "$work/again" "$work/committed"
pkl eval -m "$work/fresh" generate.pkl >/dev/null
pkl eval -m "$work/again" generate.pkl >/dev/null
cp -R CMakePresets.json cmake "$work/committed/"
diff -r "$work/fresh" "$work/again" || { echo "fixture: two generations differ" >&2; exit 1; }
if ! diff -r "$work/committed" "$work/fresh"; then
  echo "fixture: generated files are stale; run mise run fixture:generate" >&2
  exit 1
fi
echo "fixture: generated files are fresh"
