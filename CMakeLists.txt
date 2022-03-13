cmake_minimum_required(VERSION 3.0)

project(ECL)

include(ExternalProject)
set(ECL_SOURCE "${PROJECT_SOURCE_DIR}")
set(ECL_BUILD "${PROJECT_BINARY_DIR}")
file(CREATE_LINK "${ECL_BUILD}/build" "${ECL_SOURCE}/build" SYMBOLIC)
file(MAKE_DIRECTORY "${ECL_BUILD}/build")
ExternalProject_Add(ecl-prj
    PREFIX ${ECL_BUILD}
    SOURCE_DIR ${ECL_SOURCE}
    BINARY_DIR ${ECL_SOURCE}
    CONFIGURE_COMMAND
    env CC=${CMAKE_C_COMPILER}
    CXX=${CMAKE_CXX_COMPILER} ${ECL_SOURCE}/configure
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
        "SYSTEM_NAME;SYSTEM_C_NAME;LISP_SRC;ECL_LD_FLAGS;ECL_C_FLAGS"
        "SYSTEM_PATHS;INCLUDE_PATHS;SYSTEM_DEPS")
    if(NOT DEFINED ecl_lib_SYSTEM_C_NAME)
        string(REPLACE "-" "_" ecl_lib_SYSTEM_C_NAME "${ecl_lib_SYSTEM_NAME}")
    endif()
    list(APPEND ALL_LISP_SYSTEMS "${ecl_lib_SYSTEM_C_NAME}")
    set(ALL_LISP_SYSTEMS "${ALL_LISP_SYSTEMS}" PARENT_SCOPE)

    configure_file(
        "${ECL_SOURCE_DIR}/build.lisp.in"
        "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp.in")

    file(GENERATE
        OUTPUT "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp"
        INPUT "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp.in"
        )

    file(GLOB_RECURSE COMMON_LISP_SRC LIST_DIRECTORIES false
        "${ecl_lib_LISP_SRC}/*.lisp" "${ecl_lib_LISP_SRC}/*.asd")

    string(TOLOWER "${ecl_lib_SYSTEM_NAME}" ecl_lib_LIBRARY_PATH)
    set(ecl_lib_LIBRARY_PATH "${PROJECT_BINARY_DIR}/${ecl_lib_LIBRARY_PATH}.a")
    cmake_path(ABSOLUTE_PATH ecl_lib_LIBRARY_PATH NORMALIZE)
    message(STATUS "Build ASDF system :${ecl_lib_SYSTEM_NAME} as ${ecl_lib_LIBRARY_PATH}")
    add_custom_command(
        OUTPUT "${ecl_lib_LIBRARY_PATH}"
        COMMAND
        "${ECL_BINARY_DIR}/ecl"
        -norc
        -load "${ecl_lib_SYSTEM_NAME}-build.lisp"
        DEPENDS ecl-prj "${PROJECT_BINARY_DIR}/${ecl_lib_SYSTEM_NAME}-build.lisp"
        ${COMMON_LISP_SRC} ${ecl_lib_SYSTEM_DEPS})

    add_custom_target(${ecl_lib_SYSTEM_NAME}_custom_target
        DEPENDS "${ecl_lib_LIBRARY_PATH}")
    add_library(${ecl_lib_SYSTEM_NAME} STATIC IMPORTED)
    set_target_properties(${ecl_lib_SYSTEM_NAME} PROPERTIES IMPORTED_LOCATION
        "${ecl_lib_LIBRARY_PATH}")
    target_link_libraries(${ecl_lib_SYSTEM_NAME} INTERFACE ecl ${ecl_lib_SYSTEM_DEPS})
    add_dependencies(${ecl_lib_SYSTEM_NAME} ${ecl_lib_SYSTEM_NAME}_custom_target)
endfunction()

function(emit_all_systems_header)
    message(STATUS "Lisp systems: ${ALL_LISP_SYSTEMS}")
    set(LISP_SYSTEMS_HEADER "${PROJECT_BINARY_DIR}/all_lisp_systems.h")
    set(LISP_SYSTEMS_INCLUDE "${PROJECT_BINARY_DIR}" PARENT_SCOPE)
    file(WRITE "${LISP_SYSTEMS_HEADER}" "extern \"C\" {\n")
    foreach(system ${ALL_LISP_SYSTEMS})
        file(APPEND "${LISP_SYSTEMS_HEADER}" "extern void init_lib_${system}(cl_object);\n")
    endforeach()
    file(APPEND "${LISP_SYSTEMS_HEADER}" "}\n")
    file(APPEND "${LISP_SYSTEMS_HEADER}" "static void ecl_init_all_modules() {\n")
    foreach(system ${ALL_LISP_SYSTEMS})
        file(APPEND "${LISP_SYSTEMS_HEADER}" "ecl_init_module(NULL, init_lib_${system});\n")
    endforeach()
    file(APPEND "${LISP_SYSTEMS_HEADER}" "}\n")
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
