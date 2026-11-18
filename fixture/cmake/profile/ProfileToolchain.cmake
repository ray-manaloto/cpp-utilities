# Profile toolchain file. A Profile preset names it and sets PROFILE_<AXIS>
# for every name axis; a vcpkg triplet chainloads it with the ABI axes only.
# It picks the profile's compiler unless CMAKE_<LANG>_COMPILER is already set,
# and starts the flag variables with the flags the profile adds. The check
# module then refuses any compiler or flag that differs from the profile.
include("${CMAKE_CURRENT_LIST_DIR}/ProfileCommon.cmake")

# A Profile preset sets PROFILE_PRESET in the environment as well as PROFILE_* in
# the cache. A changed compiler makes CMake delete the cache and configure again
# without the preset's cache variables: no PROFILE_* is left, and with it go the
# rules module and the check module. The environment survives, so a build that
# has the preset's name but none of its values stops here instead of running
# unchecked. (A vcpkg triplet passes the ABI axes, so PROFILE_COMPILER is set there.)
# PROFILE_SOURCE_DIR limits this to the preset's own source tree: a child build
# that inherits the environment, such as an ExternalProject or a try_compile
# project, has another source directory and is left alone.
# Such a child returns at once, so the flags it set for itself stay. Known
# gap: a child that configures this same source directory into another build
# directory looks like a lost cache and is refused.
if(DEFINED ENV{PROFILE_PRESET} AND NOT DEFINED PROFILE_COMPILER
    AND "${CMAKE_SOURCE_DIR}" STREQUAL "$ENV{PROFILE_SOURCE_DIR}")
  message(FATAL_ERROR "Profile $ENV{PROFILE_PRESET}: the build directory lost the profile. "
    "Changing CMAKE_C_COMPILER or CMAKE_CXX_COMPILER on an existing build directory makes "
    "CMake delete its cache, and the profile's values and checks with it. "
    "Delete the build directory and configure the preset again.")
endif()
if(DEFINED ENV{PROFILE_PRESET} AND NOT DEFINED PROFILE_COMPILER)
  return()
endif()

foreach(axis IN LISTS PROFILE_NAME_AXES)
  string(TOUPPER "PROFILE_${axis}" var)
  list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES "${var}")
endforeach()
list(REMOVE_DUPLICATES CMAKE_TRY_COMPILE_PLATFORM_VARIABLES)

if(DEFINED PROFILE_COMPILER AND DEFINED PROFILE_SYSTEM)
  foreach(lang IN ITEMS C CXX)
    set(program "PROFILE_COMPILER_${PROFILE_COMPILER}_${lang}_${PROFILE_SYSTEM}")
    if(NOT DEFINED CMAKE_${lang}_COMPILER AND DEFINED ${program})
      set(CMAKE_${lang}_COMPILER "${${program}}")
    endif()
  endforeach()
endif()

# import std reads the standard library's modules metadata from the path the
# compiler prints for libc++.modules.json. Some LLVM packages, such as
# Homebrew's, install it under lib/c++/ where that lookup misses it, so look
# there too when the profile asks for import std on a clang.
if(PROFILE_IMPORT_STD STREQUAL "importstd_on" AND NOT DEFINED CMAKE_CXX_STDLIB_MODULES_JSON
    AND "${PROFILE_COMPILER_${PROFILE_COMPILER}_ID}" STREQUAL "Clang" AND DEFINED CMAKE_CXX_COMPILER)
  foreach(candidate IN ITEMS libc++.modules.json c++/libc++.modules.json)
    execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "-print-file-name=${candidate}"
      OUTPUT_VARIABLE found OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET RESULT_VARIABLE failed)
    if(NOT failed AND IS_ABSOLUTE "${found}" AND EXISTS "${found}")
      cmake_path(NORMAL_PATH found)
      set(CMAKE_CXX_STDLIB_MODULES_JSON "${found}")
      break()
    endif()
  endforeach()
  unset(candidate)
  unset(found)
  unset(failed)
endif()

foreach(lang IN ITEMS C CXX)
  profile_flags(${lang} compile link)
  list(JOIN compile " " compile)
  set(CMAKE_${lang}_FLAGS_INIT "${compile}")
endforeach()
list(JOIN link " " link)
foreach(kind IN ITEMS EXE SHARED MODULE)
  set(CMAKE_${kind}_LINKER_FLAGS_INIT "${link}")
endforeach()
unset(compile)
unset(link)
unset(program)
