# Server CMakeLists.txt

# Server source files
set(SERVER_SOURCES
    src/audio_server_application.cpp
    src/network/audio_websocket_server.cpp
    src/handler/websocket_message_handler.cpp
    src/memory/stream_manager.cpp
    src/memory/memory_mapped_cache.cpp
    src/memory/memory_pool_manager.cpp
)

# Server headers
set(SERVER_HEADERS
    include/audio_server_application.h
    include/network/audio_websocket_server.h
    include/handler/websocket_message_handler.h
    include/memory/stream_manager.h
    include/memory/memory_mapped_cache.h
    include/memory/memory_pool_manager.h
    include/memory/stream_context.h
    ${CMAKE_SOURCE_DIR}/include/common_types.h
)

# Create server executable
add_executable(audio_stream_server ${SERVER_SOURCES} ${SERVER_HEADERS})

# Link libraries
target_link_libraries(audio_stream_server PRIVATE
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    Threads::Threads
)

# Platform-specific libraries
if(WIN32)
    target_link_libraries(audio_stream_server PRIVATE ws2_32 wsock32)
elseif(UNIX)
    target_link_libraries(audio_stream_server PRIVATE pthread)
endif()

# Include directories
target_include_directories(audio_stream_server PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/include
)

# Install server
install(TARGETS audio_stream_server
    RUNTIME DESTINATION bin
)

# Tests
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()
