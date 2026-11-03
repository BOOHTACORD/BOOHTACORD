# Production deployment recovery — 2026-10-06

Task: T-054 (Continuous delivery and deployment inputs).
Result: PASS for CI, signed server build and production installation.

## Failure and correction

Build server run 37375238240 failed in the web browser test
`tests/voice_disconnect_notice/notice.browser.spec.ts`.
The test expected listener join to force voice-session transfer (`true`).
Commit f5401698849118bd4cdc6e40375a65fc0a664a1b made transfer explicit;
normal listener join correctly emits `false`.
Commit 200fa07e636401f52ece43cba3b3408aa28f1b96 corrects only the stale expectation.

## Validation

- Before correction: reproduced the same expected-true/received-false failure locally.
- After correction: `npm run test:voice-disconnect-notice` — 1 passed,
  covering seven disconnect reasons at widths 1440 and 1024.
- `npm test -- src/voice/disconnect_notice src/voice/controller_ownership` — 19 passed.
- Local test runtime: Node.js 26.10.0, macOS arm64; CI uses pinned Node.js 24.18.0.
- [CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37423676236) — success.
- [Build server](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37423676272) — success
  for backend, contracts, web and the signed, smoke-tested bundle.
- [Deploy production](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37424658159) — success.
  Installer log confirms: installed verified source revision
  `200fa07e636401f52ece43cba3b3408aa28f1b96` at 2026-10-06 09:37 Moscow time.

No production media quality or hardware capacity acceptance is inferred from these results.
