#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
desktop_dir="$repo_dir/clients/flutter"
build_log="$(mktemp)"
trap 'rm -f "$build_log"' EXIT

check_build() {
  local label="$1"
  local mode="$2"
  shift 2
  echo "$label"
  if ! "$@" >"$build_log" 2>&1; then
    cat "$build_log"
    return 1
  fi
  cat "$build_log"
  if ! python3 "$repo_dir/tools/verify/android_kotlin/warning_policy.py" "$mode" "$build_log"; then
    echo 'Unexpected Flutter KGP compatibility warning.' >&2
    return 1
  fi
}

cd "$desktop_dir"
check_build "Checking legacy-KGP compatibility mode from android/gradle.properties" legacy \
  flutter build apk --debug --no-pub

cd "$desktop_dir/android"
check_build "Checking AGP built-in Kotlin mode without a connected device" builtin \
  ./gradlew :app:assembleDebug -Pandroid.builtInKotlin=true --no-daemon \
  -I "$repo_dir/tools/verify/android_kotlin/verify_built_in.gradle"
