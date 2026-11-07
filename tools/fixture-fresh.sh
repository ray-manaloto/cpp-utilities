#!/bin/sh
# Fails when the committed generated fixture files differ from a fresh
# `pkl eval`, including files the generator no longer emits.
set -eu
cd "$(dirname "$0")/../fixture"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pkl eval -m "$work" generate.pkl >/dev/null
mkdir "$work/committed"
cp CMakePresets.json "$work/committed/"
cp -R cmake "$work/committed/"
mkdir "$work/fresh"
mv "$work/CMakePresets.json" "$work/cmake" "$work/fresh/"
if ! diff -r "$work/committed" "$work/fresh"; then
  echo "fixture: generated files are stale; run mise run fixture:generate" >&2
  exit 1
fi
echo "fixture: generated files are fresh"
