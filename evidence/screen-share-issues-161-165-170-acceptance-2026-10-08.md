# Screen-share issues #161 and #165–#170 — acceptance follow-up

Date: 2026-10-08. Source baseline: `origin/master` at `9b524569`.
This packet reviewed existing merged implementation; it did not change application code or close issues.

## Issue comments posted

Each comment distinguishes existing automated checks from device, SDK/SFU, browser, or production checks that remain `NOT_RUN`. Comments define the platform/scenario matrix and redacted evidence fields expected for a future PASS/FAIL result.

| Issue | Existing implementation / evidence | Acceptance comment |
|---|---|---|
| #161 | [PR #186](https://github.com/BOOHTACORD/BOOHTACORD/pull/186), [PR #201](https://github.com/BOOHTACORD/BOOHTACORD/pull/201), [publisher lifecycle verification](https://github.com/BOOHTACORD/BOOHTACORD/blob/master/evidence/screen-share-publisher-lifecycle/verification.md) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/161#issuecomment-6047860672) |
| #165 | [PR #204](https://github.com/BOOHTACORD/BOOHTACORD/pull/204) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/165#issuecomment-6047861068) |
| #166 | [PR #202](https://github.com/BOOHTACORD/BOOHTACORD/pull/202), [QA-319 capture-plan evidence](https://github.com/BOOHTACORD/BOOHTACORD/blob/master/evidence/flutter/qa319-flutter-desktop-screen-share-capture-plan-2026-10-07-001.json) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/166#issuecomment-6047861395) |
| #167 | [PR #208](https://github.com/BOOHTACORD/BOOHTACORD/pull/208) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/167#issuecomment-6047861689) |
| #168 | [PR #206](https://github.com/BOOHTACORD/BOOHTACORD/pull/206) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/168#issuecomment-6047862010) |
| #169 | [PR #207](https://github.com/BOOHTACORD/BOOHTACORD/pull/207), [adaptation policy verification](https://github.com/BOOHTACORD/BOOHTACORD/blob/master/evidence/screen-share-adaptation/verification.md) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/169#issuecomment-6047862346) |
| #170 | [PR #211](https://github.com/BOOHTACORD/BOOHTACORD/pull/211), [metadata evidence](https://github.com/BOOHTACORD/BOOHTACORD/blob/master/evidence/issue-170-screen-profile-metadata-2026-10-07.md) | [comment](https://github.com/BOOHTACORD/BOOHTACORD/issues/170#issuecomment-6047862697) |

## Verification status

- Existing PR records report the relevant focused/unit/CI checks as passing: #161 lifecycle and Web checks; #165 CI run 648; #166 source review only; #167 Android helper JUnit 12/12; #168 18 focused tests and `vue-tsc`; #169 10 tests and `vue-tsc`; #170 PR CI run #680 including backend, frontend, and lifecycle jobs.
- Physical Android, Windows, macOS, iOS, cross-client viewer, hardware codec A/B, calibrated adaptation, deployed descriptor API, and production teardown values remain `NOT_RUN` as applicable. No measured media numbers were inferred from target profiles or source settings.
- A follow-up implementation for #170 is now committed locally (`dc51d854`, `7e10855a`): Flutter parses the bounded v1 participant attribute, validates deployment/account/room scope and generation/revision, and labels sender mode/requested profile separately from measured receiver values. `python -m tools.verify.dependencies.dart` passes for 749 Dart files; Flutter/Dart tests remain `NOT_RUN` because both SDKs are unavailable here. The implementation is not yet present on GitHub because this batch has not been pushed.
- The Flutter implementation worktree had no Flutter/Dart executable, so native Flutter tests were `NOT_RUN`. The integrated batch worktree did run the Web and Go suites, recorded in [the batch review](screen-share-next20-review-2026-10-08.md); its Web suite has dependencies installed. The linked issue comments specify commands and evidence needed to collect the remaining SDK/device/SFU results on suitable runners/devices.
- No credentials, SDP, private identifiers, user media, or screen images were added to this evidence record.
