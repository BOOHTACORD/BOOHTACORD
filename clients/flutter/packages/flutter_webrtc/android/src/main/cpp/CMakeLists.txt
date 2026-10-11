cmake_minimum_required(VERSION 3.22.1)
project(boohta_rnnoise_android LANGUAGES C CXX)
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../../common/rnnoise" "${CMAKE_CURRENT_BINARY_DIR}/rnnoise")
add_library(boohta_rnnoise_android SHARED
    rnnoise_capture_jni.cc
    microphone_controls_jni.cc
    screen_audio_capture_jni.cc
    ../../../../common/darwin/Classes/ScreenAudioSource.cc)
target_include_directories(boohta_rnnoise_android PRIVATE ../../../../common/darwin/Classes)
target_compile_features(boohta_rnnoise_android PRIVATE cxx_std_17)
target_link_libraries(boohta_rnnoise_android PRIVATE boohta_rnnoise)
# Android 15 devices may use 16 KiB pages.
target_link_options(boohta_rnnoise_android PRIVATE "-Wl,-z,max-page-size=16384")
