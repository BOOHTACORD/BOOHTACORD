# Critical five issues — integration and release

Route: review_gate, release/client_updates. Implementation: PR #123, merged source
`798cfcf702485269ef53068901fb4ec1eb84b836`. Packet boundaries: no new feature work;
verify immutable artifacts, promote only verified Android selectors and preserve
unavailable physical/production acceptance gates. Primary checkout is untouched.

## Implementation evidence

| Issue | Capability | Evidence |
| --- | --- | --- |
| #63 | Caller-owned session list and targeted revocation | [Sessions](own-sessions-2026-10-05.md) |
| #71 | Uncertain message delivery and UUID-safe retry | [Delivery](message-delivery-2026-10-05.md) |
| #100 | Public guild name, administrator editor, revision conflicts | [Guild](guild-client-settings-2026-10-05.md) |
| #101 | Immutable system welcome, TEXT selector, neutral notifications | [Welcome](system-welcome-clients-2026-10-05.md) |
| #102 | Real HTTP/PostgreSQL/OTLP lifecycle trace | [Telemetry](guild-lifecycle-otlp-database-2026-10-05.md) |

## Integration checks

- PASS: [PR CI 37275447958](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37275447958)
  at exact head `cbd08678458ec681627f137d53c27ea9c7016718`: contracts, backend,
  frontend, Flutter/Android and Windows. No failed job was bypassed.
- PASS: complete local Go suite with an isolated PostgreSQL fixture, full Web
  suite (1080 tests before final desktop-only change), 617 Flutter app tests,
  435 LiveKit tests plus one existing skip, 24 WebRTC tests.
- PASS: 113 Python native checks plus one existing platform skip, contract,
  Dart import/feature-boundary and actual Chrome component checks.
- PASS: analyzer has no errors or warnings; existing nonfatal info diagnostics
  remain. Windows CI builds the distribution; no physical Windows install claimed.
- PASS: [server deployment 37277729917](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37277729917)
  installs source `798cfcf7`. Read-only checks confirm API/web OCI revision,
  running containers, public health, signed release receipt and served audio assets.
- PASS: deployed anonymous guild-profile endpoint contains exactly name/revision,
  a valid revision and bounded name; it sets no session cookie.
- PASS: deployed sessions, administrative guild settings and delivery lookup
  endpoints reject anonymous callers with 401.
- Test PostgreSQL container and SSH forwarding were removed after validation;
  no production test accounts, messages or guild names were changed.

## Remaining acceptance boundaries

- NOT_RUN: physical Android installation/SDK media disconnect and Windows install.
- NOT_RUN: native two-device registration/reconnect visual parity and production
  Grafana rename/registration smoke. Widget/build/database/export tests are distinct
  evidence and do not close these device/production gates.
- #71 has actual Chrome component and real HTTP/PostgreSQL lost-response evidence.
  It was closed as completed on 2026-10-05 after the passing integration CI.
  Other issues retain open acceptance gates where their requested physical or
  production evidence is unavailable; implementation is merged, not deferred.

## Android publication

PASS: [signed Android release 1.0.33](https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/android-v1.0.33),
[release workflow 37277136670](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37277136670).
Downloaded all seven actual assets, checked their complete SHA256SUMS and manifest,
then independently ran apksigner/aapt and ZIP/ELF inspection on every APK.

| APK ABI | Published bytes |
| --- | ---: |
| arm64-v8a | 19,831,683 |
| armeabi-v7a | 17,644,771 |
| x86_64 | 21,188,113 |

arm64 baseline 1.0.32: 41,176,490 bytes; reduction **51.84%**. arm64 SHA-256:
`b281cc5229bbf0317049bc2bf6d08466eaa039be3ac5d3431ecf0adb8e056e1f`.
Signer remains `394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b`.
Actual version is 1.0.33+66, ABI version codes 2066/1066/4066, release order 47,
source 798cfcf7 and source_dirty=false. Every native library is DEFLATED; each
APK contains exactly its declared ABI and no Flutter debug kernel. All 14 arm64
native library names remain; every 64-bit ELF LOAD alignment is at least 16 KB.

Catalog CAS promotion 24 to 27 changes precisely the three Android selectors to
the verified release. It advertises no unpublished Windows/iOS/macOS distribution.
Local catalog validator, native Python tests and contract checks validate promotion;
the trusted server deployment is required before the live catalog changes.

Measurement APKs using the public debug certificate are not distributed.
Compression reduces download size; extraction on installation can increase installed
footprint. Codecs, all supported APK ABIs and media lifecycle remain present.

Slavik Gym report: route=review_gate; packet=critical-five-release;
tokens=estimated:15000; method=manual_estimate; driver=signed-apk-and-catalog;
next_split=physical-platform-acceptance.
