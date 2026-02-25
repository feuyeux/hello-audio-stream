# Client CMakeLists.txt

add_executable(audio_stream_client
    client.cpp
)

target_compile_definitions(audio_stream_client PRIVATE
    ASIO_STANDALONE
    _WEBSOCKETPP_CPP11_RANDOM_DEVICE_
    _WEBSOCKETPP_CPP11_TYPE_TRAITS_
)

target_include_directories(audio_stream_client PRIVATE
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(audio_stream_client PRIVATE
    nlohmann_json::nlohmann_json
    Threads::Threads
)

if(WIN32)
    target_link_libraries(audio_stream_client PRIVATE ws2_32 wsock32)
elseif(UNIX)
    target_link_libraries(audio_stream_client PRIVATE pthread)
endif()

install(TARGETS audio_stream_client RUNTIME DESTINATION bin)
