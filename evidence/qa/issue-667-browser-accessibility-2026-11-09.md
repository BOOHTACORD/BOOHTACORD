# Issue 667: browser accessibility suite

Product source `8306413a84c224a712509d7a059916c95b00bd3c`, headless Chromium in WSL on Windows 11, project-pinned dependencies and Vite. The project command `npm run test:accessibility` was run twice without altering product code or assertions. The first attempt returned exit 1: 110 of 114 first-suite tests passed; three failures were dynamic module fetch errors and one failed to find the initial composer. The second returned exit 1: 109 passed and five failed, with a different set of dynamic module fetch and initial composer errors. Because the first command uses `&&`, its second suite did not run in either attempt. This is a failed and intermittent test run, not a confirmed product accessibility defect.

The four individual failures from the first run were retested: three passed together on the first retry; the composer failed once more, then passed twice on a further retry. The second suite's single axe scenario failed once with a dynamic import error, then passed twice in isolation. A separate diagnostic loaded the same message component eight times in fresh browser pages without reproducing the module error; it had no real API and its API 404s were expected. The cause remains unknown. Do not mark the full suite green based on isolated retries.

These browser fixtures commonly mock APIs; they do not establish live-stack, screen-reader, physical-device, full visual baseline or WCAG 2.2 AA acceptance. Original second-run output remains locally in `.out/qa667-accessibility.log`. Issue #667 remains open.

On the same product source, `flutter test --no-pub test/admin_accessibility test/workspace_navigation_text_scale_test.dart test/voice_manual_join_actions_accessibility_test.dart` passed 71 widget tests on Windows. These cover selected semantics, keyboard, text scale and layout fixtures, not native screen-reader or physical platform acceptance.

A follow-up standalone diagnostic loaded the message module in 100 fresh Chromium pages against its own Vite server: 100 imports passed and no non-API request error was observed. This narrower diagnostic did not recreate the full suite or its API fixtures, so it does not explain or erase the intermittent failures.

Another repeat ran five scenarios that failed in the two full-suite attempts ten times each, with temporary browser listeners for failed `/src/` and `/node_modules/` requests. All 50 passed; no such request failure was recorded. The listeners were removed after the run. This is targeted retry evidence only; it does not convert either full-suite failure into a pass or establish a root cause.

## Isolated dependency-cache follow-up

The preceding failed runs used a `node_modules` symlink whose final target was shared with a separate working copy. The experiment moved this run's symlink aside, copied the same lockfile-compatible dependencies into a private directory, and started with a private Vite cache. On product Web source `8306413a84c224a712509d7a059916c95b00bd3c`, the full 114-case accessibility Playwright configuration then passed twice, and its additional axe case passed independently. The exact project command `npm run test:accessibility` subsequently completed successfully: 114/114 followed by 1/1, exit 0. The Linux copy also contained an unrelated Flutter candidate and QA navigation-helper change, neither used by these Web fixtures.

This improves current repeatability and identifies shared mutable dependency/cache state as a plausible contributor; it does not prove that it caused any prior failure, whose original results remain FAIL. It is browser fixture evidence only, not physical screen-reader, exhaustive visual, platform or production accessibility acceptance. #667 remains open.
