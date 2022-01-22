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

function(add_ecl_library)
    cmake_parse_arguments(PARSE_ARGV 0 ecl_lib
        ""
        "SYSTEM_NAME;SYSTEM_C_NAME;LISP_SRC"
        "SYSTEM_PATHS;INCLUDE_PATHS;SYSTEM_DEPS")
    if(NOT DEFINED ecl_lib_SYSTEM_C_NAME)
        string(REPLACE "-" "_" ecl_lib_SYSTEM_C_NAME "${ecl_lib_SYSTEM_NAME}")
    endif()

    configure_file(
        "${ECL_SOURCE_DIR}/build.lisp.in"
        "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp")

    file(GLOB_RECURSE COMMON_LISP_SRC LIST_DIRECTORIES false
        "${ecl_lib_LISP_SRC}/*.lisp" "${ecl_lib_LISP_SRC}/*.asd")

    string(TOLOWER "${ecl_lib_SYSTEM_NAME}" ecl_lib_LIBRARY_PATH)
    set(ecl_lib_LIBRARY_PATH "${PROJECT_BINARY_DIR}/${ecl_lib_LIBRARY_PATH}.a")
    message(STATUS "Build ASDF system :${ecl_lib_SYSTEM_NAME} as ${ecl_lib_LIBRARY_PATH}")
    add_custom_command(
        OUTPUT "${ecl_lib_LIBRARY_PATH}"
        COMMAND
        "${ECL_BINARY_DIR}/ecl"
        -norc
        -load "${ecl_lib_SYSTEM_NAME}-build.lisp"
        DEPENDS ecl-prj "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp"
        ${COMMON_LISP_SRC})

    add_library(${ecl_lib_SYSTEM_NAME} STATIC IMPORTED)
    set_target_properties(${ecl_lib_SYSTEM_NAME} PROPERTIES IMPORTED_LOCATION
        "${ecl_lib_LIBRARY_PATH}")
    target_link_libraries(${ecl_lib_SYSTEM_NAME} INTERFACE ecl ${ecl_lib_SYSTEM_DEPS})
endfunction()

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
