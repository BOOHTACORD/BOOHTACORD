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

add_executable(deepfilter_owner_test deepfilter/owner/owner_test.cc)
target_include_directories(deepfilter_owner_test PRIVATE deepfilter/capture_hook/stub)
target_link_libraries(deepfilter_owner_test PRIVATE deepfilter_verified_engine boohta_rnnoise Threads::Threads)
add_dependencies(deepfilter_owner_test deepfilter_module_fixture)
if(MSVC)
  target_compile_options(deepfilter_owner_test PRIVATE /UNDEBUG)
endif()
add_test(NAME deepfilter_owner_test COMMAND deepfilter_owner_test
  $<TARGET_FILE:deepfilter_module_fixture> $<TARGET_FILE:deepfilter_module_fixture>.sha256)
add_executable(deepfilter_owner_research_probe
  ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../tools/audio/research_dfn_native/owner_probe.cc)
target_include_directories(deepfilter_owner_research_probe PRIVATE deepfilter/capture_hook/stub)
target_link_libraries(deepfilter_owner_research_probe PRIVATE deepfilter_verified_engine boohta_rnnoise Threads::Threads)
if(BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE)
  add_executable(deepfilter_factory_research_probe
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../tools/audio/research_dfn_native/factory_probe.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/src/experimental_deepfilter.cc)
  target_include_directories(deepfilter_factory_research_probe PRIVATE
    deepfilter/capture_hook/stub ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/include)
  target_compile_definitions(deepfilter_factory_research_probe PRIVATE
    BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE NOMINMAX
    BOOHTA_DEEPFILTER_DLL_SHA256="${BOOHTA_DEEPFILTER_DLL_SHA256}"
    BOOHTA_DEEPFILTER_MODEL_SHA256="${BOOHTA_DEEPFILTER_MODEL_SHA256}")
  target_compile_options(deepfilter_factory_research_probe PRIVATE /wd4324)
  target_link_libraries(deepfilter_factory_research_probe PRIVATE deepfilter_verified_engine boohta_rnnoise Threads::Threads)
endif()
