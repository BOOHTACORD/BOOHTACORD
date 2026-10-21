#!/usr/bin/env bash
# Run the canonical installer from the already verified private driver directory.
run_received_installer() {
  local bundle="$1" revision="$2" bundle_sha="$3" current="$4" private="$5"
  # Losing the SSH channel must not kill the lock owner or its rollout children.
  # Inherit HUP-ignore and keep every child's output off the closing SSH pipe.
  # This stays foreground: the caller's EXIT cleanup must wait for completion.
  trap '' HUP
  trap '' PIPE
  umask 077
  if python3 -m tools.release.install.run "$bundle" "$revision" "$bundle_sha" --expected-current-revision "$current" \
      --failure-receipt "$private/install-failure.json" </dev/null >"$private/install-private.log" 2>&1; then
    printf '%s\n' '{"schema_version":1,"kind":"install-result","status":"PASS"}' || true
    return 0
  fi
  python3 -m tools.release.install.diagnostics publish "$private/install-failure.json" || true
  return 0
}
