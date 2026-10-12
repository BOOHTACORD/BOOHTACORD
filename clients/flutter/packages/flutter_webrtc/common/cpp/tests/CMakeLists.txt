cmake_minimum_required(VERSION 3.15)
project(flutter_webrtc_audio_device_selection_test LANGUAGES CXX)

enable_testing()
add_executable(audio_device_selection_test audio_device_selection_test.cc)
target_include_directories(audio_device_selection_test PRIVATE ../include)
target_compile_features(audio_device_selection_test PRIVATE cxx_std_17)
if(MSVC)
  target_compile_options(audio_device_selection_test PRIVATE /UNDEBUG)
else()
  target_compile_options(audio_device_selection_test PRIVATE -UNDEBUG)
endif()
add_test(NAME audio_device_selection_test COMMAND audio_device_selection_test)
add_custom_command(TARGET audio_device_selection_test POST_BUILD
  COMMAND $<TARGET_FILE:audio_device_selection_test>
  VERBATIM
)

add_executable(audio_device_change_coalescer_test audio_device_change_coalescer_test.cc)
target_include_directories(audio_device_change_coalescer_test PRIVATE ../../../macos/flutter_webrtc/Sources/flutter_webrtc)
target_compile_features(audio_device_change_coalescer_test PRIVATE cxx_std_17)
if(MSVC)
  target_compile_options(audio_device_change_coalescer_test PRIVATE /UNDEBUG)
else()
  target_compile_options(audio_device_change_coalescer_test PRIVATE -UNDEBUG)
endif()
add_test(NAME audio_device_change_coalescer_test COMMAND audio_device_change_coalescer_test)
add_custom_command(TARGET audio_device_change_coalescer_test POST_BUILD
  COMMAND $<TARGET_FILE:audio_device_change_coalescer_test>
  VERBATIM
)

add_executable(screen_audio_source_test
  screen_audio_source_test.cc
  ../../darwin/Classes/ScreenAudioSource.cc
)
target_include_directories(screen_audio_source_test PRIVATE
  ../include
  ../../darwin/Classes
)
target_compile_features(screen_audio_source_test PRIVATE cxx_std_17)
if(MSVC)
  target_compile_options(screen_audio_source_test PRIVATE /UNDEBUG)
else()
  target_compile_options(screen_audio_source_test PRIVATE -UNDEBUG)
endif()
add_test(NAME screen_audio_source_test COMMAND screen_audio_source_test)
add_custom_command(TARGET screen_audio_source_test POST_BUILD
  COMMAND $<TARGET_FILE:screen_audio_source_test>
  VERBATIM
)
