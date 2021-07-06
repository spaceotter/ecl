cmake_minimum_required(VERSION 3.0)

project(ECL)

include(ExternalProject)
set(ECL_SOURCE "${PROJECT_SOURCE_DIR}")
set(ECL_BUILD "${PROJECT_BINARY_DIR}")
ExternalProject_Add(ecl-prj
    PREFIX ${ECL_BUILD}
    SOURCE_DIR ${ECL_SOURCE}
    BINARY_DIR ${ECL_SOURCE}
    CONFIGURE_COMMAND
    bash ${ECL_SOURCE}/configure
    --prefix=${ECL_BUILD}
    --with-tcp
    --with-serve-event
    --with-clos-streams
    --enable-gmp=included
    --without-x
    --enable-threads
    --enable-shared
    --with-dffi=included
    --with-sse
    --enable-boehm=included
    --enable-manual=no
    BUILD_COMMAND make VERBOSE=1
    LOG_CONFIGURE ON
    USES_TERMINAL_CONFIGURE ON
    LOG_BUILD ON
    USES_TERMINAL_BUILD ON)

add_library(ecl SHARED IMPORTED GLOBAL)
set_target_properties(ecl PROPERTIES IMPORTED_LOCATION "${PROJECT_BINARY_DIR}/lib/libecl.so")
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/include")
target_include_directories(ecl INTERFACE "${PROJECT_BINARY_DIR}/include")

# You are supposed to use ecl-config, but cmake doesn't have a way to capture it at build time
if(WIN32)
    set(ECL_INCLUDE_DIR ${ECL_BUILD} PARENT_SCOPE)
    set(ECL_LINK_DIR ${ECL_BUILD} PARENT_SCOPE)
    set(ECL_BINARY_DIR ${ECL_BUILD} PARENT_SCOPE)
else()
    set(ECL_INCLUDE_DIR ${ECL_BUILD}/include PARENT_SCOPE)
    set(ECL_LINK_DIR ${ECL_BUILD}/lib PARENT_SCOPE)
    set(ECL_BINARY_DIR ${ECL_BUILD}/bin PARENT_SCOPE)
endif()
