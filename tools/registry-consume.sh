#!/bin/sh
# Installs every port of the registry the way a consumer does: a manifest whose vcpkg-configuration.json
# pins this repository at its HEAD commit, then a CMake project that builds against the installed port.
# Needs the registry committed, because the consumer reads it through git.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sha=$(git -C "$here" rev-parse HEAD)

mkdir -p "$work/app"
cat >"$work/app/vcpkg-configuration.json" <<EOF
{
  "default-registry": null,
  "registries": [
    {
      "kind": "git",
      "repository": "file://$here",
      "baseline": "$sha",
      "packages": ["gch-small-vector"]
    }
  ]
}
EOF
cat >"$work/app/vcpkg.json" <<EOF
{ "name": "consume", "version": "0", "dependencies": ["gch-small-vector"] }
EOF
cat >"$work/app/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.25)
project(consume CXX)
find_package(small_vector CONFIG REQUIRED)
add_executable(main main.cpp)
target_compile_features(main PRIVATE cxx_std_17)
target_link_libraries(main PRIVATE gch::small_vector)
EOF
cat >"$work/app/main.cpp" <<EOF
#include <gch/small_vector.hpp>
int main() {
  gch::small_vector<int, 4> v{1, 2, 3};
  v.push_back(4);
  return v.size() == 4 && v.back() == 4 ? 0 : 1;
}
EOF

export VCPKG_DEFAULT_BINARY_CACHE="$work/cache"
mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"
cd "$work/app"
vcpkg install --x-install-root="$work/installed" --x-packages-root="$work/packages" --x-buildtrees-root="$work/buildtrees" --downloads-root="$work/downloads"
triplet=$(ls "$work/installed" | grep -v '^vcpkg$' | head -n 1)
cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH="$work/installed/$triplet"
cmake --build build
./build/main
echo "registry: gch-small-vector at $sha installs and builds"
