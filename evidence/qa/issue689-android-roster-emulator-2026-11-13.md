# Issue #689 Android roster runtime: scoped result

- Source: `111a9a7acb89c5bf743035d5c4a549c706d1f174`; Android API 35,
  x86_64 emulator `BOOHTACORD_QA_ISSUE689`; isolated local TLS API and SFU.
- Target: `integration_test/issue689_roster_test.dart`; two tests PASS. The
  harness reports auth, guest/auth maintenance handoff, synthetic unknown
  banner, roster socket and manual reconnect. It used no runtime mocks.
- Debug test APK SHA-256:
  `49b5b0586726af3832edc520f3740db91349411cd777a753bd693f29c0049ed6`.
  This is a synthetic test build, not a release artifact.
- Source-resolution images (1080 x 1920) were inspected. The unknown banner,
  login controls and empty roster navigation are readable; the unscrolled
  footer sits beneath a gray bottom system area, and the version is readable
  after scrolling. No visual baseline was approved from these captures.
- Image SHA-256: unknown `68ccaa2f65dc570e118dd318764d9522bdc9e5f4c763bd7cc4b2500d4054673d`,
  scrolled `30a3ee1dc6f0edd330dcf8cebfa4b8de7962cc71fec8bbed4fb855f12b84a54c`,
  roster `579fca780bde768509bf81c1d130be5058811fad27f0af059b21efcdc823f931`.
  Local originals and runtime JSON are in `.out/issue689-android-roster-final/`.
- This does not prove populated multi-account roster, packet blackhole,
  background push, physical device, media, CI, release or production. Full
  platform and visual acceptance remain open.
