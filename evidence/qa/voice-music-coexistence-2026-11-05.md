# Music/audio coexistence — 2026-11-05

- Base SHA: `0a5d63e7bdee78a8565950dd98f8d0a4bc0d4002`.
- Static review: the Android `AudioSwitchManager` defaults to `manageAudioFocus=true` and early startup did not explicitly disable it; iOS automatic recording and first-recording fallback did not include `mixWithOthers`.
- Change: configure Android focus policy before the initial voice call, enable iOS non-ducking music mixing and inform users of the Windows system communications setting in both native and browser UI.
- Unit tests, Dart analyzer, Vitest, QA harness and native builds: **NOT_RUN** in this session because required toolchains/dependencies are unavailable.
- Physical audio levels: Windows native, Windows Web, Android and iOS **NOT_RUN**. Bluetooth profile tests **NOT_RUN**.
- Release gate: **BLOCKED** until automated and physical/device checks are performed and reviewed.
- Instructions: `docs/clients/audio-coexistence.md`.
- OS caveat: Windows' system-wide Communications ducking is not changed by this patch and must not be modified silently; user-facing guidance is not an OS-level programmatic fix.
