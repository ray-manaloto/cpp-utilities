#!/bin/sh
# Configures the fixture with overrides each profile must refuse, and checks
# that configure stops with the expected reason, then with overrides it must
# accept. macOS only: the cases name macOS profiles and Homebrew's g++-16.
set -eu
cd "$(dirname "$0")/../fixture"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

asan=fixture-macos-clang23_1_4-debug-ipo_off-asan_ubsan-none-native-cxx23-c17-gnu_off-importstd_off-refl_off-pch_off
importstd=fixture-macos-clang23_1_4-release-ipo_on-none-none-native-cxx23-c17-gnu_off-importstd_on-refl_off-pch_on
gcc=fixture-macos-gcc16_2_0-release-ipo_off-none-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_on
gcc_ipo_name=macos-gcc16_2_0-release-ipo_on-none-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_on
refl_name=macos-clang23_1_4-debug-ipo_off-asan_ubsan-none-native-cxx23-c17-gnu_off-importstd_off-refl_on-pch_off
gcc_ubsan_name=macos-gcc16_2_0-release-ipo_off-ubsan-none-native-cxx26-c17-gnu_off-importstd_off-refl_on-pch_on
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
expect 'sanitizer_gcc_macos:' "$gcc" -DPROFILE_SANITIZER=ubsan -DPROFILE_NAME="$gcc_ubsan_name"
expect 'reflection_compiler:' "$asan" -DPROFILE_REFLECTION=refl_on -DPROFILE_NAME="$refl_name"
expect 'IPO is not supported' "$gcc" -DPROFILE_IPO=ipo_on -DPROFILE_NAME="$gcc_ipo_name"
expect 'is Clang 21.0.0 commit 0badc0de, but the profile names clangp2996_f17c8d6c' "$p2996" \
  -DCMAKE_C_COMPILER="$work/bin/clang-p2996" -DCMAKE_CXX_COMPILER="$work/bin/clang++-p2996"
expect 'PROFILE_NAME is not set' "$asan" -DPROFILE_NAME=

# Reconfiguring an existing directory with another compiler makes CMake delete
# the cache, and the profile's variables with it. The check must still run.
n=$((n + 1))
if ! cmake --preset "$asan" -B "$work/b$n" >"$work/log$n" 2>&1; then
  echo "FAIL $n: the first configure of the reconfigure case failed"
  sed 's/^/     /' "$work/log$n" | tail -20
  failures=$((failures + 1))
elif cmake --preset "$asan" -B "$work/b$n" -DCMAKE_C_COMPILER=gcc-16 -DCMAKE_CXX_COMPILER=g++-16 >"$work/relog$n" 2>&1; then
  echo "FAIL $n: a reconfigure with another compiler passed without a profile check"
  failures=$((failures + 1))
elif tr -s ' \n' ' ' <"$work/relog$n" | grep -qF -- 'the build directory lost the profile'; then
  echo "ok   $n: a reconfigure that deletes the cache is refused"
else
  echo "FAIL $n: the reconfigure failed without the lost-profile reason"
  sed 's/^/     /' "$work/relog$n" | tail -20
  failures=$((failures + 1))
fi

# A child CMake build that inherits the preset's environment (an ExternalProject,
# a configure test) has another source directory and lost nothing: it is not refused.
mkdir "$work/child"
printf 'cmake_minimum_required(VERSION 4.0)\nproject(child LANGUAGES CXX)\n' >"$work/child/CMakeLists.txt"
n=$((n + 1))
if env PROFILE_PRESET="$asan" PROFILE_SOURCE_DIR="$PWD" CMAKE_TOOLCHAIN_FILE="$PWD/cmake/profile/ProfileToolchain.cmake" \
    cmake -G Ninja -S "$work/child" -B "$work/b$n" -DCMAKE_CXX_FLAGS_INIT=-DCHILD_KEEPS_ME >"$work/log$n" 2>&1 \
    && grep -q 'CMAKE_CXX_FLAGS:STRING=.*-DCHILD_KEEPS_ME' "$work/b$n/CMakeCache.txt"; then
  echo "ok   $n: accepts a child build that inherits the preset's environment, with its own flags"
else
  echo "FAIL $n: configure refused a child build that inherits the preset's environment"
  sed 's/^/     /' "$work/log$n" | tail -20
  failures=$((failures + 1))
fi

# Overrides that keep every flag the profile adds but undo one of them later:
# in the same variable, in a configuration's variable, or at link time.
base='-fsanitize=address -fno-omit-frame-pointer -fsanitize=undefined -march=native'
expect 'CMAKE_CXX_FLAGS turns off sanitizer address, which the profile turns on' "$asan" \
  -DCMAKE_CXX_FLAGS="$base -fno-sanitize=all"
expect 'CMAKE_CXX_FLAGS_DEBUG turns off sanitizer undefined, which the profile turns on' "$asan" \
  -DCMAKE_CXX_FLAGS_DEBUG="-g -fno-sanitize=undefined"
expect 'CMAKE_EXE_LINKER_FLAGS_DEBUG turns off sanitizer address, which the profile turns on' "$asan" \
  -DCMAKE_EXE_LINKER_FLAGS_DEBUG=-fno-sanitize=all
expect 'CMAKE_CXX_FLAGS_RELEASE turns off sanitizer address, which the profile turns on' "$asan" \
  -G "Ninja Multi-Config" -DCMAKE_CXX_FLAGS_RELEASE=-fno-sanitize=address
expect 'CMAKE_SHARED_LINKER_FLAGS turns off sanitizer undefined, which the profile turns on' "$asan" \
  -DCMAKE_SHARED_LINKER_FLAGS=-fno-sanitize=undefined
expect 'CMAKE_C_FLAGS_DEBUG has -fomit-frame-pointer after -fno-omit-frame-pointer, which the profile adds' "$asan" \
  -DCMAKE_C_FLAGS_DEBUG="-g -fomit-frame-pointer"
expect 'CMAKE_CXX_FLAGS_DEBUG has -march=armv8.5-a after -march=native, which the profile adds' "$asan" \
  -DCMAKE_CXX_FLAGS_DEBUG="-g -march=armv8.5-a"
expect 'CMAKE_CXX_FLAGS_DEBUG turns off sanitizer address, which the profile turns on' "$asan" \
  -DCMAKE_CXX_FLAGS="-DLBRACKET=[ $base" -DCMAKE_CXX_FLAGS_DEBUG=-fno-sanitize=all
# Empty files for the flags below to name, so the compiler test passes.
: >"$work/flags.rsp"
: >"$work/x.cfg"
expect "CMAKE_CXX_FLAGS_DEBUG has @$work/flags.rsp, a response file the check can't read" "$asan" \
  -DCMAKE_CXX_FLAGS_DEBUG="-g @$work/flags.rsp"
expect "CMAKE_EXE_LINKER_FLAGS has --config=$work/x.cfg, a configuration file the check can't read" "$asan" \
  -DCMAKE_EXE_LINKER_FLAGS="--config=$work/x.cfg"

expect 'CMAKE_CXX_FLAGS_DEBUG has -Xclang, a forwarding option the check can' "$asan" \
  -DCMAKE_CXX_FLAGS_DEBUG="-g -Xclang -disable-llvm-passes"
expect 'CMAKE_CXX_FLAGS has -Xarch_arm64, a forwarding option the check can' "$asan" \
  -DCMAKE_CXX_FLAGS="$base -Xarch_arm64 -fno-sanitize=address"

# accept <what> <preset> [cmake args...]: configure must pass.
accept() {
  what=$1
  preset=$2
  shift 2
  n=$((n + 1))
  if cmake --preset "$preset" -B "$work/b$n" "$@" >"$work/log$n" 2>&1; then
    echo "ok   $n: accepts $what"
  else
    echo "FAIL $n: configure refused $what"
    sed 's/^/     /' "$work/log$n" | tail -20
    failures=$((failures + 1))
  fi
}

accept 'turning off a sanitizer the profile lacks' "$asan" -DCMAKE_CXX_FLAGS_DEBUG="-g -fno-sanitize=leak"
accept 'a quoted semicolon in a flag' "$asan" -DCMAKE_CXX_FLAGS="$base -DSEP=\"a;b\""
accept 'an unmatched bracket in a flag' "$asan" -DCMAKE_CXX_FLAGS="-DLBRACKET=[ $base"
accept 'an @ inside a word' "$asan" -DCMAKE_CXX_FLAGS="$base -DEMAIL=a@b"
accept 'turning a profile sanitizer off and on again' "$asan" \
  -DCMAKE_CXX_FLAGS_DEBUG="-g -fno-sanitize=address -fsanitize=address"

echo "$((n - failures)) of $n cases passed"
test "$failures" -eq 0
