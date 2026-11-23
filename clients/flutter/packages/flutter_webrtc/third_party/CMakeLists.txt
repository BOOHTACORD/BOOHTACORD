if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  include("${CMAKE_CURRENT_LIST_DIR}/cmake/windows_sdk.cmake")
  return()
endif()

include(ExternalProject)

# Flutter adds plugins to example builds through .plugin_symlinks. Windows
# CMake refuses to extract archives through that symlink path, so resolve the
# real third_party directory before downloading or extracting libwebrtc.
get_filename_component(LIBWEBRTC_THIRD_PARTY_DIR "${CMAKE_CURRENT_LIST_DIR}" REALPATH)

# Load binary version + download URL template from libwebrtc_version.ini so
# bumping the prebuilt release does not require editing CMake.
set(LIBWEBRTC_VERSION_INI "${LIBWEBRTC_THIRD_PARTY_DIR}/libwebrtc_version.ini")
if(NOT EXISTS "${LIBWEBRTC_VERSION_INI}")
  message(FATAL_ERROR "libwebrtc: missing version manifest at ${LIBWEBRTC_VERSION_INI}")
endif()

set(LIBWEBRTC_BINARY_VERSION "")
set(LIBWEBRTC_DOWNLOAD_URL_BASE "")
file(STRINGS "${LIBWEBRTC_VERSION_INI}" _libwebrtc_ini_lines)
foreach(_line IN LISTS _libwebrtc_ini_lines)
  string(STRIP "${_line}" _line)
  # Skip blanks, comments (# or ;) and section headers ([name]).
  if(_line STREQUAL "" OR _line MATCHES "^[#;]" OR _line MATCHES "^\\[.*\\]$")
    continue()
  endif()
  if(NOT _line MATCHES "^([^=]+)=(.*)$")
    continue()
  endif()
  string(STRIP "${CMAKE_MATCH_1}" _key)
  string(STRIP "${CMAKE_MATCH_2}" _value)
  if(_key STREQUAL "binary_version")
    set(LIBWEBRTC_BINARY_VERSION "${_value}")
  elseif(_key STREQUAL "download_url")
    set(LIBWEBRTC_DOWNLOAD_URL_BASE "${_value}")
  endif()
endforeach()

if(LIBWEBRTC_BINARY_VERSION STREQUAL "" OR LIBWEBRTC_DOWNLOAD_URL_BASE STREQUAL "")
  message(FATAL_ERROR "libwebrtc: ${LIBWEBRTC_VERSION_INI} must define binary_version and download_url")
endif()

# Strip any trailing slashes so we control the separator when composing the URL.
string(REGEX REPLACE "/+$" "" LIBWEBRTC_DOWNLOAD_URL_BASE "${LIBWEBRTC_DOWNLOAD_URL_BASE}")

# Resolve OS field for the release asset name (win / linux)
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(LIBWEBRTC_OS "win")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(LIBWEBRTC_OS "linux")
else()
  message(FATAL_ERROR "libwebrtc: unsupported target OS '${CMAKE_SYSTEM_NAME}'")
endif()

# Resolve arch field for the release asset name (x64 / arm64)
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  # Visual Studio generator exposes the selected arch via CMAKE_GENERATOR_PLATFORM
  string(TOLOWER "${CMAKE_GENERATOR_PLATFORM}" _libwebrtc_plat)
  if(_libwebrtc_plat STREQUAL "arm64")
    set(LIBWEBRTC_ARCH "arm64")
  elseif(_libwebrtc_plat STREQUAL "x64" OR _libwebrtc_plat STREQUAL "")
    # Empty platform usually means Ninja/default x64 host build
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(LIBWEBRTC_ARCH "x64")
    else()
      message(FATAL_ERROR "libwebrtc: 32-bit Windows is not supported")
    endif()
  else()
    message(FATAL_ERROR "libwebrtc: unsupported Windows arch '${CMAKE_GENERATOR_PLATFORM}'")
  endif()
else()
  # Flutter Linux / eLinux pass the target as e.g. linux-x64 or linux-arm64
  if(DEFINED FLUTTER_TARGET_PLATFORM AND FLUTTER_TARGET_PLATFORM MATCHES "arm64")
    set(LIBWEBRTC_ARCH "arm64")
  elseif(DEFINED FLUTTER_TARGET_PLATFORM AND FLUTTER_TARGET_PLATFORM MATCHES "x64")
    set(LIBWEBRTC_ARCH "x64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(LIBWEBRTC_ARCH "arm64")
  else()
    set(LIBWEBRTC_ARCH "x64")
  endif()
endif()

set(LIBWEBRTC_ASSET "libwebrtc-${LIBWEBRTC_OS}-${LIBWEBRTC_ARCH}-release")
set(ZIPFILE "${LIBWEBRTC_THIRD_PARTY_DIR}/downloads/${LIBWEBRTC_ASSET}.zip")

# Final URL = <base>/<binary_version>/<asset>.zip
set(DOWNLOAD_URL "${LIBWEBRTC_DOWNLOAD_URL_BASE}/${LIBWEBRTC_BINARY_VERSION}/${LIBWEBRTC_ASSET}.zip")

include("${CMAKE_CURRENT_LIST_DIR}/cmake/extract_sdk.cmake")

if(NOT EXISTS "${ZIPFILE}")
  message(NOTICE "download: ${DOWNLOAD_URL}")
  file(MAKE_DIRECTORY "${LIBWEBRTC_THIRD_PARTY_DIR}/downloads")
  file(DOWNLOAD "${DOWNLOAD_URL}"
      ${ZIPFILE}
      STATUS download_status
      LOG download_log)

  if(NOT download_status EQUAL 0)
    message(FATAL_ERROR "Failed to download dependency: ${download_log}")
  endif()

  _libwebrtc_extract_and_normalize("${ZIPFILE}" "${LIBWEBRTC_THIRD_PARTY_DIR}")
else()
  if(NOT EXISTS "${LIBWEBRTC_THIRD_PARTY_DIR}/libwebrtc")
    message(NOTICE "libwebrtc directory does not exist after extraction.")
    _libwebrtc_extract_and_normalize("${ZIPFILE}" "${LIBWEBRTC_THIRD_PARTY_DIR}")
  endif()
  message(TRACE "libwebrtc already downloaded.")
endif()
