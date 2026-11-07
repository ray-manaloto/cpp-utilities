# The override check ProfileCheck.cmake runs: does a later flag undo one the
# profile adds? It lives apart from ProfileCommon.cmake, which the triplets
# hash for vcpkg's binary cache, because it never changes how a dependency
# is built. tools/overrides-test.cmake tests it with cmake -P.
include_guard(GLOBAL)

# Sets <out> to the arguments in <flags>, as the compiler reads them. A list
# item ends at a ';' outside square brackets, so an argument may not hold its
# own ';', '[' or ']', as -DSEP="a;b" or -DLBRACKET=[ do: each stands in as
# ASCII 1, 2 or 3 until _profile_untokens puts it back.
function(_profile_tokens flags out)
  string(ASCII 1 semicolon)
  string(ASCII 2 lbracket)
  string(ASCII 3 rbracket)
  string(REPLACE ";" "${semicolon}" flags "${flags}")
  string(REPLACE "[" "${lbracket}" flags "${flags}")
  string(REPLACE "]" "${rbracket}" flags "${flags}")
  separate_arguments(tokens NATIVE_COMMAND "${flags}")
  set(${out} "${tokens}" PARENT_SCOPE)
endfunction()

# Sets <out> to the list <items>, with the stand-ins _profile_tokens put in
# its tokens turned back into '\;', '[' and ']'.
function(_profile_untokens items out)
  string(ASCII 1 semicolon)
  string(ASCII 2 lbracket)
  string(ASCII 3 rbracket)
  string(REPLACE "${semicolon}" "\\;" items "${items}")
  string(REPLACE "${lbracket}" "[" items "${items}")
  string(REPLACE "${rbracket}" "]" items "${items}")
  set(${out} "${items}" PARENT_SCOPE)
endfunction()

# Sets <out> to the written-out form of the bare flag <flag>, -f<x>=<value>
# with the value a bare -f<x> means, or to "" where none is known.
function(_profile_written_out flag out)
  set(value_-fsanitize-memory-track-origins 2)
  if(DEFINED value_${flag})
    set(${out} "${flag}=${value_${flag}}" PARENT_SCOPE)
  else()
    set(${out} "" PARENT_SCOPE)
  endif()
endfunction()

# Sets <out> to a refusal for each flag in <required> that a later flag in
# <vars> undoes. <vars> are read in order, as the compiler sees them: the base
# variable, then a configuration's. A flag is undone by:
# - -fno-sanitize=<names> or =all, for a sanitizer a -fsanitize= flag turns on,
#   unless a later -fsanitize= turns it on again;
# - -f<x> after -fno-<x>, or -fno-<x> or -f<x>=<value> after -f<x>, or
#   -fno-<x> after -f<x>=<value>;
# - -<opt>=<other> after -<opt>=<value>.
# The written-out form of a bare flag (_profile_written_out) stands for it:
# it is no undo, and a later flag can undo it.
# Flags a project adds itself, such as with add_compile_options, are not seen,
# nor is turning off one check of a group, such as -fno-sanitize=alignment
# under -fsanitize=undefined.
function(_profile_undone required vars out)
  set(refusals "")
  string(ASCII 1 semicolon)
  set(tokens_in_order "")
  set(token_vars "")
  foreach(var IN LISTS vars)
    _profile_tokens("${${var}}" tokens)
    foreach(token IN LISTS tokens)
      list(APPEND tokens_in_order "${token}")
      list(APPEND token_vars "${var}")
    endforeach()
  endforeach()

  set(wanted "")
  foreach(flag IN LISTS required)
    if(flag MATCHES "^-fsanitize=(.+)$")
      string(REPLACE "," ";" names "${CMAKE_MATCH_1}")
      list(APPEND wanted ${names})
    endif()
  endforeach()
  set(enabled "")
  set(i 0)
  foreach(token IN LISTS tokens_in_order)
    list(GET token_vars ${i} var)
    math(EXPR i "${i} + 1")
    if(token MATCHES "^-f(no-)?sanitize=(.+)$")
      set(negated "${CMAKE_MATCH_1}")
      # A bare ';' separates names here, as a ',' does.
      string(REGEX REPLACE "[,${semicolon}]" ";" names "${CMAKE_MATCH_2}")
      if(negated AND "all" IN_LIST names)
        set(names ${wanted})
      endif()
      foreach(name IN LISTS names)
        if(negated)
          list(REMOVE_ITEM enabled "${name}")
          set(off_${name} "${var}")
        else()
          list(APPEND enabled "${name}")
          unset(off_${name})
        endif()
      endforeach()
    endif()
  endforeach()
  foreach(name IN LISTS wanted)
    if(NOT name IN_LIST enabled AND DEFINED off_${name})
      list(APPEND refusals "${off_${name}} turns off sanitizer ${name}, which the profile turns on")
    endif()
  endforeach()

  foreach(flag IN LISTS required)
    if(flag MATCHES "^-f(no-)?sanitize=")
      continue()
    endif()
    set(negation "")
    set(prefix "")
    set(written_out "")
    if(flag MATCHES "^-fno-([^=]+)$")
      set(negation "-f${CMAKE_MATCH_1}")
    elseif(flag MATCHES "^-f([^=]+)$")
      set(negation "-fno-${CMAKE_MATCH_1}")
      set(prefix "${flag}=")
      _profile_written_out("${flag}" written_out)
    elseif(flag MATCHES "^(-[^=]+=)")
      set(prefix "${CMAKE_MATCH_1}")
      if(flag MATCHES "^-f([^=]+)=")
        set(negation "-fno-${CMAKE_MATCH_1}")
      endif()
    endif()
    set(last -1)
    set(i 0)
    foreach(token IN LISTS tokens_in_order)
      if(token STREQUAL flag OR (written_out AND token STREQUAL written_out))
        set(last ${i})
      endif()
      math(EXPR i "${i} + 1")
    endforeach()
    if(last LESS 0)
      continue()
    endif()
    set(i 0)
    foreach(token IN LISTS tokens_in_order)
      if(i GREATER last)
        string(FIND "${token}" "${prefix}" at)
        if((negation AND token STREQUAL negation)
            OR (prefix AND at EQUAL 0 AND NOT token STREQUAL written_out))
          list(GET token_vars ${i} var)
          list(APPEND refusals "${var} has ${token} after ${flag}, which the profile adds")
        endif()
      endif()
      math(EXPR i "${i} + 1")
    endforeach()
  endforeach()
  set(${out} "${refusals}" PARENT_SCOPE)
endfunction()

# Appends to <out> the refusals of _profile_undone for <base> followed by
# <base>_<CONFIG>, for each configuration the build can use, or for <base>
# alone when it names none.
function(_profile_undone_in required base out)
  get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(multi_config)
    set(configs ${CMAKE_CONFIGURATION_TYPES})
  else()
    set(configs ${CMAKE_BUILD_TYPE})
  endif()
  set(found "")
  if(NOT configs)
    _profile_undone("${required}" "${base}" found)
  endif()
  foreach(config IN LISTS configs)
    string(TOUPPER "${config}" upper)
    _profile_undone("${required}" "${base};${base}_${upper}" here)
    if(here)
      list(APPEND found "${here}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES found)
  _profile_untokens("${found}" found)
  set(all "${${out}}")
  if(found)
    list(APPEND all "${found}")
  endif()
  set(${out} "${all}" PARENT_SCOPE)
endfunction()
