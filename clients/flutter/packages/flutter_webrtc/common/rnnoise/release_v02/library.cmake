find_package(Python3 REQUIRED COMPONENTS Interpreter)
get_filename_component(_release_root "${CMAKE_CURRENT_LIST_DIR}/../../../../../../.." ABSOLUTE)
execute_process(COMMAND "${Python3_EXECUTABLE}" -m tools.audio.release_source.run
  --output "${CMAKE_CURRENT_BINARY_DIR}/rnnoise-release-source"
  WORKING_DIRECTORY "${_release_root}" OUTPUT_VARIABLE _release_source
  OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _release_result)
if(NOT _release_result EQUAL 0)
  message(FATAL_ERROR "The pinned RNNoise 0.2 release source failed authentication")
endif()
set(_src "${_release_source}/src")
add_library(boohta_rnnoise_v02_release OBJECT
  "${_src}/denoise.c" "${_src}/rnn.c" "${_src}/pitch.c" "${_src}/kiss_fft.c"
  "${_src}/celt_lpc.c" "${_src}/nnet.c" "${_src}/nnet_default.c"
  "${_src}/parse_lpcnet_weights.c" "${_src}/rnnoise_data.c" "${_src}/rnnoise_tables.c")
target_include_directories(boohta_rnnoise_v02_release PRIVATE
  "${_release_source}/include" "${_src}" "${_release_root}/tools/audio/research_v02")
target_compile_definitions(boohta_rnnoise_v02_release PRIVATE
  rnnoise_init=rnnoise_v02_init rnnoise_process_frame=rnnoise_v02_process_frame
  _USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS)
if(MSVC)
  target_compile_options(boohta_rnnoise_v02_release PRIVATE /std:c11)
endif()
set(_rnnoise_core $<TARGET_OBJECTS:boohta_rnnoise_v02_release>
  "${_release_root}/tools/audio/research_v02/native_client/compat.c"
  "${_release_root}/tools/audio/research_v02/native_adapter/research_16k.cc")
set(BOOHTA_RNNOISE_V02_RESEARCH TRUE)
set(BOOHTA_RNNOISE_RELEASE_V02_ACTIVE TRUE)
if(BINARY_NAME)
  install(FILES "${_release_source}/COPYING"
    DESTINATION "$<TARGET_FILE_DIR:${BINARY_NAME}>" RENAME LICENSE-RNNoise-0.2.txt COMPONENT Runtime)
endif()
