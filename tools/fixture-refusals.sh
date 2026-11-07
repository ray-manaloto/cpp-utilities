#!/bin/sh
# Configures the fixture with overrides each profile must refuse, and checks
# that configure stops with the expected reason. Run from the repo root on
# macOS after `mise run fixture:generate`.
set -eu
cd "$(dirname "$0")/../fixture"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

asan=fixture-macos-clang23_1_4-debug-ipo_off-asan_ubsan-none-native-cxx23-c17-gnu_off-importstd_off-refl_off-pch_off
importstd=fixture-macos-clang23_1_4-release-ipo_on-none-none-native-cxx23-c17-gnu_off-importstd_on-refl_off-pch_on
gcc=fixture-macos-gcc16_2_0-release-ipo_off-none-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_on
gcc_ipo_name=macos-gcc16_2_0-release-ipo_on-none-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_on
refl_name=macos-clang23_1_4-debug-ipo_off-asan_ubsan-none-native-cxx23-c17-gnu_off-importstd_off-refl_on-pch_off
asan_tsan_name=macos-clang23_1_4-debug-ipo_off-asan_tsan-none-native-cxx23-c17-gnu_off-importstd_off-refl_off-pch_off

# A launcher named sccache that runs the compiler unchanged.
mkdir "$work/bin"
printf '#!/bin/sh\nexec "$@"\n' >"$work/bin/sccache"
chmod +x "$work/bin/sccache"

# clang-p2996 wrappers whose --version names another fork commit.
p2996=fixture-macos-clangp2996_f17c8d6c-release-ipo_off-none-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_off
for tool in clang-p2996 clang++-p2996; do
  real=$(command -v "$tool")
  printf '#!/bin/sh\nif [ "$1" = --version ]; then "%s" --version | sed s/f17c8d6c/0badc0de/; else exec "%s" "$@"; fi\n' \
    "$real" "$real" >"$work/bin/$tool"
  chmod +x "$work/bin/$tool"
done

failures=0
n=0
# expect <reason> <preset> [cmake args...]: configure must fail and print <reason>.
expect() {
  reason=$1
  preset=$2
  shift 2
  n=$((n + 1))
  if cmake --preset "$preset" -B "$work/b$n" "$@" >"$work/log$n" 2>&1; then
    echo "FAIL $n: configure passed; expected: $reason"
    failures=$((failures + 1))
  elif tr -s ' \n' ' ' <"$work/log$n" | grep -qF -- "$reason"; then
    echo "ok   $n: $reason"
  else
    echo "FAIL $n: configure failed without: $reason"
    sed 's/^/     /' "$work/log$n" | tail -20
    failures=$((failures + 1))
  fi
}

expect 'CMAKE_CXX_STANDARD is "20" but cxx_standard cxx23 sets "23"' "$asan" -DCMAKE_CXX_STANDARD=20
expect 'the CXX compiler /opt/homebrew/bin/g++-16 is GNU 16.2.0, but the profile names clang23_1_4' "$asan" \
  -DCMAKE_C_COMPILER=gcc-16 -DCMAKE_CXX_COMPILER=g++-16
expect 'CMAKE_CXX_FLAGS lacks -fsanitize=address, which the profile adds' "$asan" -DCMAKE_CXX_FLAGS=
expect 'the axis values spell "macos-gcc16_2_0-' "$asan" -DPROFILE_COMPILER=gcc16_2_0
expect 'PROFILE_TARGET_CPU="haswell" is not one of' "$asan" -DPROFILE_TARGET_CPU=haswell
expect 'PROFILE_SANITIZER="ubsan_asan" is not none or sanitizers from' "$asan" -DPROFILE_SANITIZER=ubsan_asan
expect 'sanitizer_tsan_asan:' "$asan" -DPROFILE_SANITIZER=asan_tsan -DPROFILE_NAME="$asan_tsan_name"
expect 'importstd_generator:' "$importstd" -G "Unix Makefiles"
expect 'pch_sccache:' "$gcc" -DCMAKE_CXX_COMPILER_LAUNCHER="$work/bin/sccache"
expect 'reflection_compiler:' "$asan" -DPROFILE_REFLECTION=refl_on -DPROFILE_NAME="$refl_name"
expect 'IPO is not supported' "$gcc" -DPROFILE_IPO=ipo_on -DPROFILE_NAME="$gcc_ipo_name"
expect 'is Clang 21.0.0 commit 0badc0de, but the profile names clangp2996_f17c8d6c' "$p2996" \
  -DCMAKE_C_COMPILER="$work/bin/clang-p2996" -DCMAKE_CXX_COMPILER="$work/bin/clang++-p2996"
expect 'PROFILE_NAME is not set' "$asan" -DPROFILE_NAME=

echo "$((n - failures)) of $n refusal cases passed"
test "$failures" -eq 0
