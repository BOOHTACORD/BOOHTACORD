add_library(deepfilter_verified_engine STATIC deepfilter/verified_engine/engine.cc)
target_link_libraries(deepfilter_verified_engine PUBLIC deepfilter_verified_module)
add_executable(deepfilter_verified_engine_test deepfilter/verified_engine/engine_test.cc)
target_link_libraries(deepfilter_verified_engine_test PRIVATE deepfilter_verified_engine)
add_dependencies(deepfilter_verified_engine_test deepfilter_module_fixture)
if(MSVC)
  target_compile_options(deepfilter_verified_engine_test PRIVATE /UNDEBUG)
endif()
add_test(NAME deepfilter_verified_engine_test COMMAND deepfilter_verified_engine_test
  $<TARGET_FILE:deepfilter_module_fixture> $<TARGET_FILE:deepfilter_module_fixture>.sha256)
add_executable(deepfilter_verified_hook_research_probe
  ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../tools/audio/research_dfn_native/verified_probe.cc)
target_include_directories(deepfilter_verified_hook_research_probe PRIVATE deepfilter/capture_hook/stub)
target_link_libraries(deepfilter_verified_hook_research_probe PRIVATE deepfilter_verified_engine boohta_rnnoise Threads::Threads)
