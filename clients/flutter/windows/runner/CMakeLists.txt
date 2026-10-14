cmake_minimum_required(VERSION 3.15)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "voice_overlay/bridge/channel.cpp"
  "voice_overlay/presentation/paint.cpp"
  "voice_overlay/window_lifecycle/lifecycle.cpp"
  "voice_overlay/configuration/apply.cpp"
  "voice_overlay/configuration_decode/decoder.cpp"
  "voice_overlay/snapshot_decode/decoder.cpp"
  "voice_overlay/placement/position.cpp"
  "voice_overlay/window_events/handler.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "user32.lib" "gdi32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Official Velopack native SDK, restored and hash-verified before Flutter build.
set(BOOH_VPK "${CMAKE_SOURCE_DIR}/Updaters")
target_include_directories(${BINARY_NAME} PRIVATE "${BOOH_VPK}/include")
target_link_libraries(${BINARY_NAME} PRIVATE "${BOOH_VPK}/lib/velopack_libc_win_x64_msvc.dll.lib")
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${BOOH_VPK}/lib/velopack_libc_win_x64_msvc.dll" "$<TARGET_FILE_DIR:${BINARY_NAME}>")

# Compiled local monitor, copied outside current/ at consented apply.
add_executable(BOOHTACORDRecovery WIN32 "../../native/desktop_recovery/windows.cpp")
target_compile_features(BOOHTACORDRecovery PRIVATE cxx_std_17)
set_property(TARGET BOOHTACORDRecovery PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
target_compile_definitions(BOOHTACORDRecovery PRIVATE UNICODE _UNICODE NOMINMAX)
target_link_libraries(BOOHTACORDRecovery PRIVATE windowsapp version shell32 advapi32 user32 bcrypt)
add_dependencies(${BINARY_NAME} BOOHTACORDRecovery)
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "$<TARGET_FILE:BOOHTACORDRecovery>" "$<TARGET_FILE_DIR:${BINARY_NAME}>/BOOHTACORDRecovery.exe")
