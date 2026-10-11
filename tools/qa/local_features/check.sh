#!/bin/sh
set -eu
qa_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:/opt/homebrew/bin:$PATH"
export FLUTTER_ROOT="${FLUTTER_ROOT:-/opt/homebrew/share/flutter}"
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-boohtacord-qa}"
cd "$qa_root"
exec python3 -m tools.qa.local_features.run "$@"
