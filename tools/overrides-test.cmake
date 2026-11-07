# Unit tests for the override check in ProfileOverrides.cmake, for flags no
# compiler on the fixture's machines accepts. Run: cmake -P tools/overrides-test.cmake
include("${CMAKE_CURRENT_LIST_DIR}/../catalogue/cmake/ProfileOverrides.cmake")

set(CMAKE_BUILD_TYPE Debug)
set(failures 0)
# check(<name> <required> <base flags> <debug flags> <expected refusals>):
# with CMAKE_CXX_FLAGS and CMAKE_CXX_FLAGS_DEBUG set, the check must give
# exactly <expected refusals>, a list.
function(check name required base debug expected)
  set(CMAKE_CXX_FLAGS "${base}")
  set(CMAKE_CXX_FLAGS_DEBUG "${debug}")
  set(got "")
  _profile_undone_in("${required}" CMAKE_CXX_FLAGS got)
  if("${got}" STREQUAL "${expected}")
    message(STATUS "ok   ${name}")
  else()
    message(STATUS "FAIL ${name}\n  got:      ${got}\n  expected: ${expected}")
    math(EXPR failures "${failures} + 1")
    set(failures ${failures} PARENT_SCOPE)
  endif()
endfunction()

set(msan "-fsanitize=memory;-fsanitize-memory-track-origins")
check("refuses a valued form of a required flag" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins" "-g -fsanitize-memory-track-origins=0"
  "CMAKE_CXX_FLAGS_DEBUG has -fsanitize-memory-track-origins=0 after -fsanitize-memory-track-origins, which the profile adds")
check("refuses -fno-<x> after a required -f<x>=<value>" "-fsanitize-memory-track-origins=2"
  "-fsanitize-memory-track-origins=2" "-fno-sanitize-memory-track-origins"
  "CMAKE_CXX_FLAGS_DEBUG has -fno-sanitize-memory-track-origins after -fsanitize-memory-track-origins=2, which the profile adds")
check("keeps a quoted semicolon in one token" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins -DSEP=\"a;b\"" "-fno-sanitize-memory-track-origins"
  "CMAKE_CXX_FLAGS_DEBUG has -fno-sanitize-memory-track-origins after -fsanitize-memory-track-origins, which the profile adds")
check("keeps a refused token's semicolon in one refusal" "-march=native"
  "-march=native" "-march=a;b"
  "CMAKE_CXX_FLAGS_DEBUG has -march=a\;b after -march=native, which the profile adds")
check("reads a bare semicolon between sanitizer names as a separator" "-fsanitize=address"
  "-fsanitize=address" "-fno-sanitize=leak;address"
  "CMAKE_CXX_FLAGS_DEBUG turns off sanitizer address, which the profile turns on")
check("sees a sanitizer override after an unmatched bracket" "-fsanitize=address"
  "-fsanitize=address -DLBRACKET=[" "-fno-sanitize=all"
  "CMAKE_CXX_FLAGS_DEBUG turns off sanitizer address, which the profile turns on")
check("keeps a refused token's bracket in its refusal" "-march=native"
  "-march=native" "-march=["
  "CMAKE_CXX_FLAGS_DEBUG has -march=[ after -march=native, which the profile adds")
check("accepts the level a bare flag means, written out" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins" "-fsanitize-memory-track-origins=2"
  "")
check("refuses a weaker level than a bare flag means" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins" "-fsanitize-memory-track-origins=1"
  "CMAKE_CXX_FLAGS_DEBUG has -fsanitize-memory-track-origins=1 after -fsanitize-memory-track-origins, which the profile adds")
check("refuses -fno-<x> after the written-out level" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins" "-fsanitize-memory-track-origins=2 -fno-sanitize-memory-track-origins"
  "CMAKE_CXX_FLAGS_DEBUG has -fno-sanitize-memory-track-origins after -fsanitize-memory-track-origins, which the profile adds")
check("sees a sanitizer override after other bracket forms" "-fsanitize=address"
  "-fsanitize=address -DA=[a;b] -DB=]=] -DC=[[x" "-fno-sanitize=all"
  "CMAKE_CXX_FLAGS_DEBUG turns off sanitizer address, which the profile turns on")
check("refuses a weaker level after the written-out level in place of the bare flag" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins=2" "-fsanitize-memory-track-origins=0"
  "CMAKE_CXX_FLAGS_DEBUG has -fsanitize-memory-track-origins=0 after -fsanitize-memory-track-origins, which the profile adds")

check("refuses a response file in the base variable" "-fsanitize=address"
  "-fsanitize=address @/abs/flags.rsp" "-g"
  "CMAKE_CXX_FLAGS has @/abs/flags.rsp, a response file the check can't read")
check("refuses a response file in a configuration's variable" "-fsanitize=address"
  "-fsanitize=address" "-g @/abs/flags.rsp"
  "CMAKE_CXX_FLAGS_DEBUG has @/abs/flags.rsp, a response file the check can't read")
check("refuses --config=<file>" "-fsanitize=address"
  "-fsanitize=address" "--config=/abs/x.cfg"
  "CMAKE_CXX_FLAGS_DEBUG has --config=/abs/x.cfg, a configuration file the check can't read")
check("refuses --config <file> as two tokens" "-fsanitize=address"
  "-fsanitize=address --config /abs/x.cfg" "-g"
  "CMAKE_CXX_FLAGS has --config, a configuration file the check can't read")
check("refuses the directories that decide which configuration files clang reads" "-fsanitize=address"
  "-fsanitize=address --config-user-dir=/abs" "--config-system-dir=/abs"
  "CMAKE_CXX_FLAGS has --config-user-dir=/abs, a configuration file the check can't read;CMAKE_CXX_FLAGS_DEBUG has --config-system-dir=/abs, a configuration file the check can't read")
check("accepts an @ inside a word" "-fsanitize=address"
  "-fsanitize=address -DEMAIL=a@b" "-g -Wl,@/abs/link.rsp -DCONFIG=--config"
  "")

check("refuses -Xclang with its argument" "-fsanitize=address"
  "-fsanitize=address -Xclang -disable-llvm-passes" "-g"
  "CMAKE_CXX_FLAGS has -Xclang, a forwarding option the check can't read")
check("refuses -Xclang in a configuration's variable" "-fsanitize=address"
  "-fsanitize=address" "-g -Xclang -disable-llvm-passes"
  "CMAKE_CXX_FLAGS_DEBUG has -Xclang, a forwarding option the check can't read")
check("refuses -Xarch_<arch> with its argument" "-fsanitize=address"
  "-fsanitize=address" "-Xarch_arm64 -fno-sanitize=address"
  "CMAKE_CXX_FLAGS_DEBUG has -Xarch_arm64, a forwarding option the check can't read;CMAKE_CXX_FLAGS_DEBUG turns off sanitizer address, which the profile turns on")
check("refuses -Xarch_host" "-fsanitize=address"
  "-fsanitize=address -Xarch_host -g" "-g"
  "CMAKE_CXX_FLAGS has -Xarch_host, a forwarding option the check can't read")
check("accepts words that only contain Xclang or Xarch_" "-fsanitize=address"
  "-fsanitize=address -DXclang -DNO-Xarch_x=1" "-g -DX=-Xclang"
  "")

if(failures)
  message(FATAL_ERROR "${failures} override check case(s) failed")
endif()
