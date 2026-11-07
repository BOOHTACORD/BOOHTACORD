# Voice sound client integration (#678)

Scope: VC-001 / #676. This record separates interface integration from acoustic,
paired-room, signed release and production acceptance.

Observed locally on 2026-11-07:

- Web: all 520 suites / 1792 tests passed before the final legacy-review addition;
  the updated focused sound suites pass (46 tests). Production Web build passes.
- Real disposable HTTPS API, PostgreSQL and isolated FFmpeg worker: profile
  upload, initially disabled metadata, enable, preview and deletion pass through
  production browser components at 1440 and 393 px. A real HTML audio element
  and WebAudio analyser observe nonzero decoded PCM; this is not a claim of
  acoustic audibility. The server's 10-second upload limit also rejected the
  initial back-to-back viewport run, as expected; independent runs respect it.
- Windows native full BoohtacordApp: authenticated profile upload, enable,
  SoLoud preview and delete pass. Only the OS file picker returns a synthetic
  WAV; UI, secure-cookie transport, database and normalizer are real. Marker:
  `JOIN_SOUND_FULL_WORKSPACE_PASS`. The actual OS picker is not covered.
- Reviewed source-resolution captures in `.out/join-sounds-web` and
  `.out/join-sounds-native-windows`: melody controls fit narrow layouts, Russian
  labels render correctly, enabled/disabled state is distinct. The Windows
  capture is 1898x1024. A ListTile Material assertion found by the first native
  run was fixed, and the full test passed again.
- Focused native policy/preference/queue tests pass (33 tests). Native analysis
  finds no type errors or warnings. Contracts/parity (136 public operations),
  spec traceability and source-bound network configuration checks pass.
- Linux delivery tests cover the third attested image, exact signed payload
  membership, legacy two-image packages, installer and readback. The actual
  three-image signed build and production readback still require release CI.

Current changes also keep unowned legacy device OFF flags local until the
current account explicitly chooses its policy; they do not silently copy
another account's flags into server preferences. Final native revalidation of
this addition, physical Android, paired room/publisher events, canonical local
feature acceptance, current-head CI and deployment are pending in this record.

No merge, issue closure, production deployment, acoustic or iOS runtime PASS is
claimed here. Later evidence must identify the exact tested source revision.

## Follow-up runtime observations

The physical Samsung SM A576B / Android 17 run passed the same full-app scenario
with real HTTP normalization and SoLoud (`join-678-android-navigation.log`). The
initial phone runs correctly failed because a direct state switch left the
mobile navigation drawer over the profile; the test now enters through the real
user-footer action and requires hit-testable controls. The user answered that
they did not notice the short cue; acoustic audibility remains NOT_VERIFIED.

The real two-browser SFU run (`tools/qa/join_sounds/paired.mjs`) passed: another
participant's join downloads authenticated MP3 from the private endpoint and
plays it; actual screen publication/unpublication emits default cues; leaving
while publishing produces one leave cue and suppresses the stop cue; baseline,
self and deafen remain quiet. Media is synthetic canvas video; there is no
camera capture or recording. This does not prove every network or OS route.

All 115 workspace widget tests passed after adapting the existing dock test to
revisioned account preferences. Preference initialization now runs in the
background and keeps playback muted until settings are available, so an offline
preference service cannot block sign-in. Final CI and canonical gate remain
pending; earlier failed test logs are retained privately without payloads.

A focused conflicting-revision test exposed stale preference writes after a
second device changed another field. Web/Flutter now refresh once and retry only
the user's chosen fields; the tests preserve the other device's volume and reject
retries after a session replacement. The four procedural cues also have identical
Web/Dart SHA-256 output, enforced by shared PCM fixtures. Their original source
and CC0 provenance are documented in `docs/audio/voice-cues.md`.
