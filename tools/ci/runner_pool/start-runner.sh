#!/usr/bin/env bash
set -euo pipefail
cd /home/runner/actions-runner
jit=$(cat /home/runner/.jit)
rm /home/runner/.jit
mkdir -p /home/runner/.gradle
cat > /home/runner/.gradle/gradle.properties <<'GRADLE'
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=128m -XX:+ExitOnOutOfMemoryError
org.gradle.workers.max=2
org.gradle.parallel=false
kotlin.daemon.jvmargs=-Xmx512m
GRADLE
exec ./run.sh --jitconfig "$jit"
