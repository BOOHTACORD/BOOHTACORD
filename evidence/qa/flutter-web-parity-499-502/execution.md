# Local execution — 2026-10-21

Base: `840cb746c13a85ac2c5d097afdbadf8c9e663be9`. Flutter 3.47.7 pinned SDK. Work done in the owned `local-feature-qa` checkout; the primary user's dirty checkout was not edited.

| Check | Result | Evidence / qualification |
| --- | --- | --- |
| Focused final behavior + production captures | PASS | `.out/parity499-502-final-captures2.log`: 188 tests, including the new parity directory, populated workspace, screen setup and admin captures. `--coverage` produced nonempty `clients/flutter/coverage/lcov.info`. Includes the corrected dropdown font, an explicit fixture-only WebRTC event bridge, and actual production pin → TEXT → DM → profile → voice → end transitions with a retained draft. |
| Full Flutter unit run | Initial FAIL, presentation expectations corrected | `.out/parity499-502-flutter-final.log`: 1554 passed, 1 skipped, 1 old label expectation failed. The selected-quality label expectation was corrected; the nearest setup/admin suite subsequently passed all 25 tests. The final complete app/vendor suites and Android build are also mandatory PR CI checks, not inferred from these subset results. |
| Analyzer | PASS with informational lints | `flutter analyze --no-pub --no-fatal-infos`, `.out/parity499-502-analyze-final2.log`; no errors/warnings. Existing and non-fatal style infos are retained. |
| Before captures | PASS | Unmodified base source extracted separately; the original workspace capture test passed all 3 profiles and produced 6 TEXT/DM before images. No user's checkout or screenshot baseline was changed. |
| Registered local-feature harness | Initial FAIL, retained honestly | `./tools/qa/local_features/check.sh --base 840cb746... --real-stack`; `.out/local-features/20261021-191735/report.json`: 37 stages, 31 PASS, 6 FAIL. All browser fixture suites and Web unit/build passed. Flutter failures were stale removed-copy expectations subsequently corrected and rechecked above. |
| Web real API/SFU at 1440/393 | BLOCKED | QA Docker context initially absent/stopped. Existing `boohtacord-qa` Colima profile was started. No production environment was touched. |
| Android real API runtime | BLOCKED | Dedicated `emulator-5554` booted; initial missing Docker context, then Tempo `/ready` remained 503. A local runner allowed one extra bounded readiness window, still requiring actual HTTP 200; it also failed. No app/native runtime PASS is claimed. |
| iOS real API runtime | BLOCKED | Dedicated BOOHTACORD QA simulator booted; stack stopped at Tempo readiness before Flutter drive. |
| Physical Android/iOS/macOS/Windows capture/audio and multi-device media | NOT_RUN | Separate #303 acceptance. No real-media, OS picker, audio-quality, performance/capacity or release-gate PASS inferred from fixtures/simulators. |

The runtime retry adapter exists only under `.out/parity499-502/run_with_startup_grace.py`; it retries the same real readiness function once, does not mock health/API/media, and is not shipped. Tempo returned `Ingester not ready ... waiting for 15s after being ready` throughout the bounded attempt. No tracing, backend, production or CI policy change was added to these four presentation tasks.

## Visual observations at original source resolution

Inspected original images with `view_image(detail=original)`; all PNG dimensions and SHA-256 are in `images.json`. Images and logs remain under the ignored local `.out/` directory; no generated media is staged.

- Before/after mobile 393×852: TEXT header retains menu/member access and adds the conversation overflow; grouped message time is now visible in its gutter. Author and body alignment remain continuous. Time changes from UTC-only display to correctly converted local time are intentional.
- Before desktop DM vs after short/large-text DM: author/avatar/date/unread/time are visible in the continuous conversation. Corrected the initially stretched avatar to a circular 32 dp surface inside a scalable timestamp gutter. At 2× text, date/unread labels wrap and the history scrolls above the composer.
- Search 320×480 at 2×: scope and Find are reachable, empty-query Find is disabled, no touch-only Enter hint. Corrected dropdown font inheritance after the first capture exposed missing glyphs in the fixture font environment. Result rows retain full time/context tooltip and existing navigation.
- Mini 320×240 and 390/1440×480 at 2×: pause/resume and Stop remain reachable, short layout uses overflow for secondary controls, and the reserved area does not overlap the draft field. At very short height the video image is omitted; when IME plus the voice dock leaves insufficient height for header/composer, the bounded conversation/mini area scrolls to make both controls and input reachable without overlap. At wide/tall size the policy reserves a side rail. This is presentation evidence with no live track.
- Voice 1440×480 and 1/5/10-participant narrow captures: the duplicate welcome is removed, names/states grow, the known viewer marker remains, and primary dock actions plus Leave stay above the footer. On a short large-text desktop window, upper navigation scrolls rather than displacing the footer.
- Profile at 320/1440×480, 2× with 180 dp IME: viewport is clamped above the keyboard, card content scrolls internally and Close remains visible. Back/navigation dismiss stale profiles; late API responses do not repopulate the closed card. The close transition is atomic to avoid the reproduced semantics/focus crash during a fade.
- Audio 390×480: devices, refresh and activation remain primary; advanced processing/shortcuts are grouped and stay mounted. Errors/fallback are not hidden, and a report for an older noise-processing request does not confirm the new setting.

An additional production-state probe reproduced short-IME overflow and a large-text screen-stage footer overflow. The follow-up fixes add a short-pane scroll policy, wrapping ended-screen actions and compact accessible audience counts; the final 188-test capture run passes those regressions.

Hosted CI on the first PR revision passed the complete Dart profile but rejected the screenshot package because the new parity captures were not yet in the finite publication inventory. The follow-up explicitly registers all 90 deterministic synthetic names and retains the existing exact-set/freshness/privacy/integrity checks; it does not relax publication policy.

These records describe implementation/presentation acceptance. They do not close the blocked native/physical gates or #303.
