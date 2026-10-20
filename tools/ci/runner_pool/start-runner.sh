#!/usr/bin/env bash
set -euo pipefail
cd /home/runner/actions-runner
jit=$(cat /home/runner/.jit)
rm /home/runner/.jit
mkdir -p /home/runner/.gradle
cat > /home/runner/.gradle/gradle.properties <<'GRADLE'
org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=128m -XX:+ExitOnOutOfMemoryError
org.gradle.daemon=false
org.gradle.workers.max=2
org.gradle.parallel=false
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.jvmargs=-Xmx512m
GRADLE
exec ./run.sh --jitconfig "$jit"
