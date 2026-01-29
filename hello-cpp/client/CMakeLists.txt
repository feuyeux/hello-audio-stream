# Client CMakeLists.txt

# Client source files
set(CLIENT_SOURCES
    src/audio_client_application.cpp
    src/core/websocket_client.cpp
    src/core/file_manager.cpp
    src/core/chunk_manager.cpp
    src/core/upload_manager.cpp
    src/core/download_manager.cpp
    src/util/verification_module.cpp
    src/util/performance_monitor.cpp
    src/util/stream_id_generator.cpp
    src/util/error_handler.cpp
)

# Client headers
set(CLIENT_HEADERS
    include/audio_client_application.h
    include/core/websocket_client.h
    include/core/file_manager.h
    include/core/chunk_manager.h
    include/core/upload_manager.h
    include/core/download_manager.h
    include/util/verification_module.h
    include/util/performance_monitor.h
    include/util/stream_id_generator.h
    include/util/error_handler.h
    ../include/common_types.h
)

# Create client executable
add_executable(audio_stream_client ${CLIENT_SOURCES} ${CLIENT_HEADERS})

# Add compile definitions for standalone ASIO
target_compile_definitions(audio_stream_client PRIVATE 
    ASIO_STANDALONE
    _WEBSOCKETPP_CPP11_RANDOM_DEVICE_
    _WEBSOCKETPP_CPP11_TYPE_TRAITS_
)

# Link libraries
target_link_libraries(audio_stream_client PRIVATE
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    Threads::Threads
)

if(OpenSSL_FOUND)
    target_link_libraries(audio_stream_client PRIVATE
        OpenSSL::SSL
        OpenSSL::Crypto
    )
endif()

# Platform-specific libraries
if(WIN32)
    target_link_libraries(audio_stream_client PRIVATE ws2_32 wsock32)
elseif(UNIX)
    target_link_libraries(audio_stream_client PRIVATE pthread)
endif()

# Include directories
target_include_directories(audio_stream_client PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/include
)

if(OpenSSL_FOUND)
    target_include_directories(audio_stream_client PRIVATE
        ${OPENSSL_INCLUDE_DIR}
    )
endif()

# Install client
install(TARGETS audio_stream_client
    RUNTIME DESTINATION bin
)

# Tests
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()
