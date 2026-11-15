find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(COMMAND "${Python3_EXECUTABLE}" -c
  "from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parents[6].as_posix())"
  "${CMAKE_CURRENT_LIST_DIR}" OUTPUT_VARIABLE _noise_release_root
  OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _noise_root_result)
if(NOT _noise_root_result EQUAL 0 OR NOT EXISTS "${_noise_release_root}/tools/audio/release_source/lock.json")
  message(FATAL_ERROR "Noise engine repository root is unavailable")
endif()
