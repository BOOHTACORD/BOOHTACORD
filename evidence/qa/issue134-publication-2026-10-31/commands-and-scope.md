# Issue134 scoped acceptance commands and evidence

Actual runtime: ce7; validation-only head4a0f has identical backend/deploy/Web/toolchain trees. Windows11 host, WSL Ubuntu Linux Go1.26.4, PostgreSQL17.6, native Caddy2.10.0; real LiveKit SDK in owned Chromium. Both owned QA namespaces were removed after acceptance.

These are the executed helper basenames/options with private paths replaced by variables. Replaying needs a NEW isolated exact-source owner-validated private profile and NEW output. The old private profiles were removed. No automatic replay or production endpoint is authorised by this document.

```sh
python3 launcher.py global --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-global-attempt1" --execute-owned
python3 launcher.py idle --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-idle-attempt1" --execute-owned --mode both
python3 launcher.py controls --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-controls-attempt1" --execute-owned
xvfb-run -a --server-num=153 --server-args="-screen 0 1600x1200x24" node voice_launcher.mjs --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-voice-provider-attempt1"
node h2_scope_diagnostic.mjs --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-h2-scope-attempt1" --execute-owned
python3 launcher.py absolute --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-absolute-attempt1" --execute-owned
python3 launcher.py enospc --profile "$CHILD_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-enospc-child-attempt1" --execute-owned --provision
python3 launcher.py cleanup --profile "$FIXED_PRIVATE_PROFILE" --out "$NEW_OUTPUT/ce7-main-cleanup-attempt1" --execute-owned
```

Provider uses the ordinary UI Join without microphone; cleanup uses ordinary UI Leave/logout then exact owned process absence. The protected WebSocket plus actual SDK/lease/RoomService participant remained qualified through the real900s window; this is not physical audio quality. A separate bounded tmpfs child produced real ENOSPC without filling host/main/persistent storage. Policy60/900/account2/global16/25MB and normal auth/ACL/Origin/CSRF remain unchanged.

The current materialized PASS is in runtime-acceptance.json and adjacent source-bound receipts. Original preparation docs may say NOT_RUN or reference718; their hashes are retained for command provenance only. V2 root metadata corrects h2_scope.mjs to actual h2_scope_diagnostic.mjs; original v1 SHA remains recorded. Earlier baseline2b95,718 proxy-delivery FAIL, negative mutations and controller UNKNOWN remain historical.

Observed59/80 and899/930 acceptance/watchdog bounds do not change native60s/900s policies. Durations and sampled heartbeat bounds are observations, not calibrated performance or latency SLOs. No parent QA/physical-media gate or production deployment is claimed.
