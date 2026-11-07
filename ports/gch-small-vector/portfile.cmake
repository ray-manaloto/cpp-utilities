vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO gharveymn/small_vector
    REF "v${VERSION}"
    SHA512 726ba81479f6ba01d59f52849ce06dfc23693a13db7050679b2599557b9f2c201387f488fdc30f356203ceaaf37bd5d64f025d778db863b38da15fbde778e44b
    HEAD_REF main
)

# One header, nothing to compile: install it and a CMake config of our own. A registry's ports can
# depend only on ports in the registry, so this does not use vcpkg-cmake, a builtin port.
set(VCPKG_BUILD_TYPE release)

file(INSTALL "${SOURCE_PATH}/source/include/gch" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/small_vector-config.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/small_vector")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
