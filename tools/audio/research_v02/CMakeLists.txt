cmake_minimum_required(VERSION 3.20)
project(rnnoise_v02_research LANGUAGES C)
if(NOT IS_DIRECTORY "${RNNOISE_SOURCE}/src")
  message(FATAL_ERROR "A verified RNNOISE_SOURCE is required")
endif()
set(src "${RNNOISE_SOURCE}/src")
add_executable(rnnoise_v02_pcm probe_pcm.c
  "${src}/denoise.c" "${src}/rnn.c" "${src}/pitch.c" "${src}/kiss_fft.c"
  "${src}/celt_lpc.c" "${src}/nnet.c" "${src}/nnet_default.c"
  "${src}/parse_lpcnet_weights.c" "${src}/rnnoise_data.c" "${src}/rnnoise_tables.c")
target_include_directories(rnnoise_v02_pcm PRIVATE "${RNNOISE_SOURCE}/include" "${src}" "${CMAKE_CURRENT_SOURCE_DIR}")
if(MSVC)
  target_compile_options(rnnoise_v02_pcm PRIVATE /std:c11)
  target_compile_definitions(rnnoise_v02_pcm PRIVATE _USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS)
else()
  target_link_libraries(rnnoise_v02_pcm PRIVATE m)
endif()
