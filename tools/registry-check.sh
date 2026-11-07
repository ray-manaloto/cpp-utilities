#!/bin/sh
# Checks the vcpkg registry in this repository (or in the clone named by $1): every port has a version
# entry, the baseline names each port's latest version, and each entry's git-tree is the tree of the
# port's directory in a commit. A tag is a release only if this passes on its commit.
set -eu
root=$(cd "${1:-$(dirname "$0")/..}" && pwd -P)
vcpkg x-ci-verify-versions --verify-git-trees \
  --x-builtin-ports-root="$root/ports" \
  --x-builtin-registry-versions-dir="$root/versions"
echo "registry: ports and versions in $root agree"
