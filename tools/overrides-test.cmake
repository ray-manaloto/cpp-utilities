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

if(failures)
  message(FATAL_ERROR "${failures} override check case(s) failed")
endif()
