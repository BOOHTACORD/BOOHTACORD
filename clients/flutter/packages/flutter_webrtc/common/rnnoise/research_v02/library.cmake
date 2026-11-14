# Local-only, source-verified RNNoise v0.2; never used by release CI.
set(_rnnoise_core upstream/src/denoise.c upstream/src/kiss_fft.c ${_rnnoise_pitch_lpc}
  upstream/src/rnn.c upstream/src/rnn_data.c)
if(DEFINED ENV{BOOHTA_RNNOISE_V02_SOURCE})
  if(DEFINED ENV{CI} OR DEFINED ENV{GITHUB_ACTIONS} OR NOT "$ENV{BOOHTA_RNNOISE_LOCAL_ONLY}" STREQUAL "1")
    message(FATAL_ERROR "RNNoise research backend is local-only")
  endif()
  if(BINARY_NAME AND NOT CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    string(FIND "${CMAKE_INSTALL_PREFIX}/" "${CMAKE_BINARY_DIR}/" _inside_build)
    if(NOT _inside_build EQUAL 0 AND NOT CMAKE_INSTALL_PREFIX STREQUAL "$<TARGET_FILE_DIR:${BINARY_NAME}>")
      message(FATAL_ERROR "Unsafe research install prefix")
    endif()
  endif()
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
  execute_process(COMMAND "${Python3_EXECUTABLE}" -c
    "from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parents[6].as_posix())"
    "${CMAKE_CURRENT_LIST_DIR}" OUTPUT_VARIABLE _root OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _root_result)
  if(NOT _root_result EQUAL 0)
    message(FATAL_ERROR "RNNoise research repository path is unavailable")
  endif()
  file(TO_CMAKE_PATH "$ENV{BOOHTA_RNNOISE_V02_SOURCE}" _src)
  execute_process(COMMAND "${Python3_EXECUTABLE}" -m tools.audio.research_v02.native_client.check_source "${_src}"
    WORKING_DIRECTORY "${_root}" RESULT_VARIABLE _verified OUTPUT_QUIET ERROR_QUIET)
  if(NOT _verified EQUAL 0)
    message(FATAL_ERROR "RNNoise research source identity verification failed")
  endif()
  set(_research "${_root}/tools/audio/research_v02")
  add_library(boohta_rnnoise_v02_research OBJECT
    "${_src}/src/denoise.c" "${_src}/src/rnn.c" "${_src}/src/pitch.c" "${_src}/src/kiss_fft.c"
    "${_src}/src/celt_lpc.c" "${_src}/src/nnet.c" "${_src}/src/nnet_default.c"
    "${_src}/src/parse_lpcnet_weights.c" "${_src}/src/rnnoise_data.c" "${_src}/src/rnnoise_tables.c")
  target_include_directories(boohta_rnnoise_v02_research PRIVATE "${_src}/include" "${_src}/src" "${_research}")
  target_compile_definitions(boohta_rnnoise_v02_research PRIVATE rnnoise_init=rnnoise_v02_init
    rnnoise_process_frame=rnnoise_v02_process_frame _USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS)
  if(MSVC)
    target_compile_options(boohta_rnnoise_v02_research PRIVATE /std:c11)
  endif()
  set(_rnnoise_core $<TARGET_OBJECTS:boohta_rnnoise_v02_research>
    "${_research}/native_client/compat.c" "${_research}/native_adapter/research_16k.cc")
  set(BOOHTA_RNNOISE_V02_RESEARCH TRUE)
  set(_marker "${CMAKE_CURRENT_BINARY_DIR}/rnnoise-v02-research-only.txt")
  file(WRITE "${_marker}" "Local research only; model redistribution is not cleared.\n")
  if(BINARY_NAME AND NOT TARGET "${BINARY_NAME}")
    message(FATAL_ERROR "Research client target is missing")
  endif()
  if(BINARY_NAME)
    install(FILES "${_marker}" DESTINATION "$<TARGET_FILE_DIR:${BINARY_NAME}>" COMPONENT Runtime)
  else()
    install(FILES "${_marker}" DESTINATION . COMPONENT Runtime)
  endif()
endif()
