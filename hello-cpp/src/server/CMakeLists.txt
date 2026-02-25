# Server CMakeLists.txt

add_executable(audio_stream_server
    server.cpp
    handler.cpp
    stream_manager.cpp
    mmap_cache.cpp
)

target_include_directories(audio_stream_server PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(audio_stream_server PRIVATE
    nlohmann_json::nlohmann_json
    Threads::Threads
)

if(WIN32)
    target_link_libraries(audio_stream_server PRIVATE ws2_32 wsock32)
elseif(UNIX)
    target_link_libraries(audio_stream_server PRIVATE pthread)
endif()

install(TARGETS audio_stream_server RUNTIME DESTINATION bin)
