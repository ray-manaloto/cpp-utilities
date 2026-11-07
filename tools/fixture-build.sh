#!/bin/sh
# Configures, builds and tests every fixture preset whose condition holds on
# this machine. Configure runs the profile's rules and checks.
set -eu
cd "$(dirname "$0")/../fixture"
presets=$(cmake --list-presets | sed -n 's/^ *"\(fixture-[^"]*\)".*/\1/p')
test -n "$presets" || { echo "fixture: no presets apply on this machine" >&2; exit 1; }
for p in $presets; do
  echo "=== $p"
  log=$(cmake --preset "$p") || { printf '%s\n' "$log"; exit 1; }
  printf '%s\n' "$log" | grep '^-- Profile '
  cmake --build --preset "$p"
  ctest --preset "$p"
done
