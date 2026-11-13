add_library(deepfilter_module_fixture SHARED deepfilter/verified_module/fixture.cc)
add_custom_command(TARGET deepfilter_module_fixture POST_BUILD
  COMMAND ${CMAKE_COMMAND} "-DINPUT=$<TARGET_FILE:deepfilter_module_fixture>"
    "-DOUTPUT=$<TARGET_FILE:deepfilter_module_fixture>.sha256"
    -P ${CMAKE_CURRENT_SOURCE_DIR}/deepfilter/verified_module/write_hash.cmake VERBATIM)
add_executable(deepfilter_verified_module_test deepfilter/verified_module/module_test.cc)
target_link_libraries(deepfilter_verified_module_test PRIVATE deepfilter_verified_module)
add_dependencies(deepfilter_verified_module_test deepfilter_module_fixture)
if(MSVC)
  target_compile_options(deepfilter_verified_module_test PRIVATE /UNDEBUG)
endif()
add_test(NAME deepfilter_verified_module_test COMMAND deepfilter_verified_module_test
  $<TARGET_FILE:deepfilter_module_fixture> $<TARGET_FILE:deepfilter_module_fixture>.sha256)
include(deepfilter/verified_engine/tests.cmake)
