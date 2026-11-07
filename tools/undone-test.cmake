# Unit tests for the override check in ProfileCommon.cmake, for flags no
# compiler on the fixture's machines accepts. Run: cmake -P tools/undone-test.cmake
include("${CMAKE_CURRENT_LIST_DIR}/../fixture/cmake/profile/ProfileCommon.cmake")

set(failures 0)
# check(<name> <required> <flags> <expected refusals>): with CMAKE_CXX_FLAGS
# set to <flags>, the check must give exactly <expected refusals>.
function(check name required flags expected)
  set(CMAKE_CXX_FLAGS "${flags}")
  _profile_undone("${required}" CMAKE_CXX_FLAGS got)
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
  "-fsanitize=memory -fsanitize-memory-track-origins -fsanitize-memory-track-origins=0"
  "CMAKE_CXX_FLAGS has -fsanitize-memory-track-origins=0 after -fsanitize-memory-track-origins, which the profile adds")
check("keeps a quoted semicolon in one token" "${msan}"
  "-fsanitize=memory -fsanitize-memory-track-origins -DSEP=\"a;b\" -fno-sanitize-memory-track-origins"
  "CMAKE_CXX_FLAGS has -fno-sanitize-memory-track-origins after -fsanitize-memory-track-origins, which the profile adds")
check("names a refused token that holds a semicolon" "-march=native"
  "-march=native -march=a;b"
  "CMAKE_CXX_FLAGS has -march=a\;b after -march=native, which the profile adds")

if(failures)
  message(FATAL_ERROR "${failures} override check case(s) failed")
endif()
