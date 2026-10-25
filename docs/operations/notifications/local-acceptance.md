# Local notification acceptance (#564)

Run from a disposable checkout. Use a dedicated loopback PostgreSQL database and role both named `voice_platform_test`; never reuse a production URL. Test fixtures create isolated schemas and synthetic accounts. No real provider credentials are needed or permitted for this local profile.

```
python -m tools.verify.notifications.run --profile backend
python -m tools.verify.notifications.run --profile contracts
python -m tools.verify.notifications.run --profile web
python -m tools.verify.notifications.run --profile flutter
python -m tools.verify.notifications.run --profile flutter-vendor
python -m tools.verify.notifications.run --profile queries --promtool /absolute/path/to/promtool
```

Set `VOICE_PLATFORM_TEST_DATABASE_URL` and `TEST_DATABASE_URL` to the same dedicated fixture database. Provide the repository-pinned Go/Node/Flutter/Python toolchains on PATH. Pin native versions using `tools/toolchains.json`; a different installed SDK is recorded as a tooling limitation, even if source checks pass. Prometheus3.11.2 is the existing observability deployment version. Outputs under `.out/notification-acceptance/` record status and logs; a missing executable/prerequisite is BLOCKED and never PASS.

The normal CI selection now routes shared identity/chat/realtime/settings/notification changes to backend, Web and Flutter regressions. The Web browser suite is in `tools/ci/web_suites/plan-v1.json`; Flutter tests are discovered by its existing full suite. All three policy evaluators use `contracts/notification-policy-v1.fixtures.json`, and Go/Dart signing uses the synthetic cross-language fixture. A test-only signing seed is labelled synthetic and grants access to no service.

Register and run the native feature acceptance too:

```
./tools/qa/local_features/check.sh --feature notifications --base <base-sha> --real-stack
```

Include other affected features selected by the existing coverage policy for shared workspace changes. This harness requires its owned Docker/API/SFU stack and native QA targets. On Windows, WSL cannot directly use a Git worktree whose `.git` pointer contains a Windows absolute path; CRLF shell conversion alone does not fix that. The current host also has no running Docker engine or Apple runtime. Those rows remain BLOCKED; direct component/browser captures are separate evidence.

| Scenario | Local proof | External/runtime gate |
|---|---|---|
| Account/operator/device consent; old server; explicit migration; conflicts | Go API/PG, common fixtures, Vitest, Flutter tests | Permission allow/deny/dismiss on physical supported devices |
| Atomic commit/rollback/idempotency; original mentions, no edit push | Real PostgreSQL outbox and native chat regression suites | Isolated real API + provider DM/mention |
| Current ACL/read/session/generation/revoke; administrator has no DM bypass | Real PostgreSQL dispatch/resolve/attention/activation tests | Two real installations, A→B/origin/logout/reset/ban |
| Grace, bounded attention/sound/fanout/quotas/TTL/lease recovery | Fake-clock DB tests, actual fixed worker with synthetic transport | Observe processing latency separately from OS scheduling |
| Relay challenge possession, pinned installation, signatures/replay, independent revoke | Real PG with synthetic provider, Go/Dart interop | Signed staging builds and actual challenge delivery |
| Web Push SSRF/DNS/IPv6/rebinding/redirect restrictions | Controlled resolver/TLS/HTTP ports only | Approved public push providers; no internal network probes |
| 429/5xx/invalid/ambiguous timeout; stable logical ref/TTL; no blind resend | Provider fakes and crash/lease/worker tests | Provider outage/recovery in authorized staging |
| One system presenter, scoped durable dedup, stale logout clear fence | True Chromium multi-page IndexedDB + SW unit tests; Flutter adapter tests | Browser OS card; native foreground/background/lock/restart |
| Tap exact message after authenticated resolve, no automatic read/voice join | Common client navigation helpers and existing search context | Foreground/resume/cold-start tap, keyboard/focus/drafts/call |
| Metrics privacy, unknown/no-data, kill/no historical replay | PG collectors, live disabled relay scrape, real promtool query/alert fixtures, CLI smoke | Authorized staging dashboard and real action traces |
| Responsive controls and large text | Inspected393/1440 Web and Flutter393/1440/200% captures | Native screen reader/OS permission UI |

Source tests, component captures, APK compilation and provider acceptance are different evidence levels. Chromium component acceptance does not establish Firefox/Safari/iOS PWA compatibility. An Android debug build without publisher configuration intentionally leaves background registration unavailable. iOS signing/runtime cannot be inferred from XML or Dart compilation. No physical/provider row is closed by the local profile.
