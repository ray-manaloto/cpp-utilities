#!/bin/sh
# Validates every generated preset file against the presets schema shipped
# with the pinned CMake, then has CMake itself load the fixture's presets.
set -eu
cd "$(dirname "$0")/../fixture"
root=$(echo 'message("${CMAKE_ROOT}")' | cmake -P /dev/stdin 2>&1)
schema="$root/Help/manual/presets/schema.json"
test -f "$schema" || { echo "fixture: no presets schema at $schema" >&2; exit 1; }
check-jsonschema --schemafile "$schema" CMakePresets.json cmake/presets/*.json
cmake --list-presets=all >/dev/null
echo "fixture: presets match $schema"
