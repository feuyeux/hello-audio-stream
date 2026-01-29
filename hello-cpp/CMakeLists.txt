cmake_minimum_required(VERSION 3.20)
project(AudioStreamCache VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

option(BUILD_TESTS "Build tests" ON)
option(BUILD_CLIENT "Build client" ON)
option(BUILD_SERVER "Build server" ON)

find_package(Threads REQUIRED)
find_package(OpenSSL QUIET)

if(NOT OpenSSL_FOUND)
    message(WARNING "OpenSSL not found. SSL/TLS support will be disabled.")
    add_compile_definitions(WEBSOCKETPP_NO_TLS)
endif()

include(FetchContent)

if(EXISTS "${CMAKE_SOURCE_DIR}/scripts/lib")
    set(USE_LOCAL_DEPS TRUE)
    set(LOCAL_DEPS_PATH "${CMAKE_SOURCE_DIR}/scripts/lib")
    message(STATUS "Using local dependencies from scripts/lib/")
endif()

if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/asio")
    include_directories(${LOCAL_DEPS_PATH}/asio/asio/include)
    set(asio_SOURCE_DIR ${LOCAL_DEPS_PATH}/asio)
else()
    FetchContent_Declare(asio
        GIT_REPOSITORY https://github.com/chriskohlhoff/asio.git
        GIT_TAG asio-1-30-2
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(asio)
    include_directories(${asio_SOURCE_DIR}/asio/include)
endif()
add_compile_definitions(ASIO_STANDALONE)

if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/websocketpp")
    set(websocketpp_SOURCE_DIR ${LOCAL_DEPS_PATH}/websocketpp)
    set(BUILD_TESTS_SAVED ${BUILD_TESTS})
    set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    add_subdirectory(${websocketpp_SOURCE_DIR} ${CMAKE_BINARY_DIR}/websocketpp-build EXCLUDE_FROM_ALL)
    set(BUILD_TESTS ${BUILD_TESTS_SAVED} CACHE BOOL "" FORCE)
else()
    FetchContent_Declare(websocketpp
        GIT_REPOSITORY https://github.com/zaphoyd/websocketpp.git
        GIT_TAG master
        GIT_SHALLOW TRUE
    )
    set(BUILD_TESTS_SAVED ${BUILD_TESTS})
    set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(websocketpp)
    set(BUILD_TESTS ${BUILD_TESTS_SAVED} CACHE BOOL "" FORCE)
endif()

if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/spdlog")
    set(spdlog_SOURCE_DIR ${LOCAL_DEPS_PATH}/spdlog)
    add_subdirectory(${spdlog_SOURCE_DIR} ${CMAKE_BINARY_DIR}/spdlog-build EXCLUDE_FROM_ALL)
else()
    FetchContent_Declare(spdlog
        GIT_REPOSITORY https://github.com/gabime/spdlog.git
        GIT_TAG v1.14.1
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(spdlog)
endif()

if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/nlohmann_json")
    set(nlohmann_json_SOURCE_DIR ${LOCAL_DEPS_PATH}/nlohmann_json)
    add_library(nlohmann_json::nlohmann_json INTERFACE IMPORTED)
    target_include_directories(nlohmann_json::nlohmann_json INTERFACE ${nlohmann_json_SOURCE_DIR}/include)
else()
    # Try to find system-installed nlohmann_json first
    find_package(nlohmann_json 3.11 QUIET)
    if(NOT nlohmann_json_FOUND)
        FetchContent_Declare(nlohmann_json
            GIT_REPOSITORY https://github.com/nlohmann/json.git
            GIT_TAG v3.11.3
            GIT_SHALLOW TRUE
            OVERRIDE
        )
        set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
        set(JSON_Install OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(nlohmann_json)
    endif()
endif()

if(BUILD_TESTS)
    if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/googletest")
        set(googletest_SOURCE_DIR ${LOCAL_DEPS_PATH}/googletest)
        set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
        add_subdirectory(${googletest_SOURCE_DIR} ${CMAKE_BINARY_DIR}/googletest-build EXCLUDE_FROM_ALL)
    else()
        FetchContent_Declare(googletest
            GIT_REPOSITORY https://github.com/google/googletest.git
            GIT_TAG v1.14.0
            GIT_SHALLOW TRUE
        )
        FetchContent_MakeAvailable(googletest)
    endif()

    if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/rapidcheck")
        set(rapidcheck_SOURCE_DIR ${LOCAL_DEPS_PATH}/rapidcheck)
        set(RC_ENABLE_GTEST ON CACHE BOOL "Enable RapidCheck GTest integration")
        add_subdirectory(${rapidcheck_SOURCE_DIR} ${CMAKE_BINARY_DIR}/rapidcheck-build EXCLUDE_FROM_ALL)
    else()
        FetchContent_Declare(rapidcheck
            GIT_REPOSITORY https://github.com/emil-e/rapidcheck.git
            GIT_TAG master
            GIT_SHALLOW TRUE
        )
        set(RC_ENABLE_GTEST ON CACHE BOOL "Enable RapidCheck GTest integration")
        FetchContent_MakeAvailable(rapidcheck)
    endif()

    enable_testing()
    include(GoogleTest)
endif()

include_directories(
    ${PROJECT_SOURCE_DIR}/client/include
    ${PROJECT_SOURCE_DIR}/server/include
    ${websocketpp_SOURCE_DIR}
    ${spdlog_SOURCE_DIR}/include
)

if(USE_LOCAL_DEPS AND EXISTS "${LOCAL_DEPS_PATH}/nlohmann_json")
    include_directories(${nlohmann_json_SOURCE_DIR}/include)
endif()

if(WIN32)
    add_compile_definitions(_WIN32_WINNT=0x0601 NOMINMAX _WEBSOCKETPP_CPP11_STRICT_=1)
elseif(UNIX)
    add_compile_definitions(HAVE_MMAP _WEBSOCKETPP_CPP11_STRICT_=1)
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic $<$<CONFIG:Release>:-O3> $<$<CONFIG:Debug>:-g>)
elseif(MSVC)
    add_compile_options(/W4 /MP /std:c++20 $<$<CONFIG:Release>:/O2> $<$<CONFIG:Debug>:/Zi>)
endif()

if(BUILD_CLIENT)
    add_subdirectory(client)
endif()

if(BUILD_SERVER)
    add_subdirectory(server)
endif()

install(DIRECTORY client/include/ DESTINATION include/audio_stream_cache/client
    FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp")
install(DIRECTORY server/include/ DESTINATION include/audio_stream_cache/server
    FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp")

set(CPACK_PACKAGE_NAME "AudioStreamCache")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Multi-Language Audio Stream Cache System - C++ Implementation")
set(CPACK_PACKAGE_VENDOR "Audio Stream Cache Project")
set(CPACK_GENERATOR "TGZ;ZIP")
include(CPack)
