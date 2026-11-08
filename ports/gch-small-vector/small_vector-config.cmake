get_filename_component(_small_vector_prefix "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
if(NOT TARGET gch::small_vector)
  add_library(gch::small_vector INTERFACE IMPORTED)
  set_target_properties(gch::small_vector PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_small_vector_prefix}/include"
    INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_small_vector_prefix}/include")
endif()
unset(_small_vector_prefix)
