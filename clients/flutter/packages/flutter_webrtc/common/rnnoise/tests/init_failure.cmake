add_executable(rnnoise_init_failure_test
  tests/init_failure_test.cc tests/init_failure_stub.cc
  rnnoise_capture_processor.cc deepfilter/capture_hook/process.cc
  microphone_controls/processor.cc)
target_include_directories(rnnoise_init_failure_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(rnnoise_init_failure_test PRIVATE cxx_std_17)
target_link_libraries(rnnoise_init_failure_test PRIVATE Threads::Threads)
if(MSVC)
  target_compile_options(rnnoise_init_failure_test PRIVATE /UNDEBUG)
else()
  target_compile_options(rnnoise_init_failure_test PRIVATE -UNDEBUG)
endif()
add_test(NAME rnnoise_init_failure_test COMMAND rnnoise_init_failure_test)
set_tests_properties(rnnoise_init_failure_test PROPERTIES TIMEOUT 15)
