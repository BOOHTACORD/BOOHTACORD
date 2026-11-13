# Issue #689: Flutter recovery dispatch fence, partial

- App-composition regressions reproduced an old recovery starting topology,
  member and DM loads after socket closure, and an old ready event starting a
  permission refresh after closure.
- Ready and recovery sequences now capture socket admission and check it after
  awaited steps before starting the next operation. The normal ready path remains
  covered. Sixty-four related tests, four focused regressions and the Flutter
  analyzer passed; the focused normal-ready test was added after that suite.
- Operations already running still need their own stale-response fences. Native
  Android/iOS, full current-source real-stack and visual acceptance remain NOT_RUN.
