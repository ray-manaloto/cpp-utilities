#!/bin/sh
# Tests registry-check.sh against clones of the committed registry. The clean clone must pass. Each
# mutation is committed in its own clone, because the check reads git trees, and must fail.
# Needs the registry committed: it clones HEAD.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
# Git hooks in the clones run mise, which refuses an untrusted mise.toml.
export MISE_TRUSTED_CONFIG_PATHS="$work${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"

clone() {
  rm -rf "$work/c"
  git clone -q "$here" "$work/c"
  git -C "$work/c" config user.name test
  git -C "$work/c" config user.email test@example.invalid
}

mutate() { # name, command run in the clone's root
  name=$1; shift
  clone
  (cd "$work/c" && "$@")
  git -C "$work/c" add -A
  git -C "$work/c" commit -q -m "mutation: $name"
  if "$here/tools/registry-check.sh" "$work/c" >"$work/out" 2>&1; then
    echo "FAIL: '$name' was accepted"; cat "$work/out"; fail=1
  else
    echo "ok: '$name' is refused"
  fi
}

clone
if "$here/tools/registry-check.sh" "$work/c" >"$work/out" 2>&1; then
  echo "ok: the committed registry passes"
else
  echo "FAIL: the committed registry is refused"; cat "$work/out"; fail=1
fi

port=$(ls "$here/ports" | head -n 1)
[ -n "$port" ] || { echo "FAIL: no port under ports/"; exit 1; }

mutate "a portfile edited after its version was recorded" sh -c "echo '# edited' >> ports/$port/portfile.cmake"
mutate "a new version in the port with no versions entry" sh -c "sed -i.bak 's/\"version\": *\"[^\"]*\"/\"version\": \"99.0.0\"/' ports/$port/vcpkg.json && rm ports/$port/vcpkg.json.bak"
mutate "a baseline entry removed" sh -c "printf '{\"default\": {}}\n' > versions/baseline.json"
mutate "a port's versions file removed" sh -c "git rm -q -r versions/*-"
mutate "a port with no versions at all" sh -c "cp -R ports/$port ports/other-port && sed -i.bak 's/\"name\": *\"[^\"]*\"/\"name\": \"other-port\"/' ports/other-port/vcpkg.json && rm ports/other-port/vcpkg.json.bak"

exit "$fail"
