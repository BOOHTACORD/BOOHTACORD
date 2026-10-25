# Notification epic #554 implementation plan

> Execution: inline in the existing isolated worktree, using bounded local-Qwen packets and Codex integration/review. No parallel agents, publishing, production credentials, or provider enrollment are authorized by this plan.

**Goal:** implement #555–#563 and a reproducible #564 local acceptance gate, preserving chat/voice and recording unavailable physical delivery separately.

**Architecture:** PostgreSQL metadata intents commit with messages. A bounded worker revalidates current access, settings, binding, read state and expiry before a transport call. Web uses encrypted Web Push; official mobile uses a separately deployed, device-approved relay with fixed neutral templates. The existing clients own consent, presentation and authenticated navigation.

**Stack:** Go/pgx/PostgreSQL, Vue/TypeScript, Flutter/Dart/native Android/iOS, Firebase HTTP v1, Web Push, Prometheus/OTel/Grafana.

Operating brief: route=split_first; size=large; native-manifests-and-imports. Select one capability per packet. New production/test files hard120 lines; leaf source/test counts hard16 each. Preserve pre-change behavior first. Checks use real local PostgreSQL plus deterministic clock/resolver/provider ports; no production probes. Gate remains NOT_RUN for unavailable devices/providers.

## 1. #555 preferences and contract

- [x] Reproduce the existing RED in `backend/internal/notifications/preferences/postgres/external_storage_test.go` with `VOICE_PLATFORM_TEST_DATABASE_URL` pointing to the isolated local fixture.
- [x] Repair `preferences/postgres/{queries,repository}.go`: UPDATE with revision predicate; INSERT only expected0 and ON CONFLICT DO NOTHING; union successful returning rows. Normalize server revision/imported; import only explicit overrides into disabled defaults.
- [x] Replace SQL-substring assertions in the newly generated tests with behavioral coverage, retain independent race/import assertions. Validate UUID aliases, nil IDs, UTC and bounds in `preferences/validation.go`.
- [x] Implement `preferences/api`, `preferences/access`, `app/notification_routes` and `config/runtime/notifications.go`; wire only the exact runtime registration edge. Strict request fields, own-session actor, current pair/channel access, private revision hint.
- [x] Add `contracts/notification-policy-v1.fixtures.json`, `notifications/eligibility`, Web `notification/server_policy`, Flutter `notifications/server_policy`; all three execute the same fixture file.
- [x] Add ADR, OpenAPI/realtime versions and external neutral payload schema. Add explicit preview/import clients with unavailable-old-server state, preserving implicit local all as local-only.
- [x] Check: `go -C backend test ./internal/notifications/... -count=1`, targeted Vitest/Dart, contracts validator.

## 2. #557 device binding and safe references

- [x] Implement `notifications/register_device`, `revoke_device`, `resolve_reference`, `attention` as separate trigger leaves with API/postgres children; additive migration after0057.
- [x] Session digest/generation plus trusted origin/installation, opaque instance and provider namespace scope every binding. Encrypt transport secrets with an operator-provided key outside DB; list responses omit credentials.
- [x] Transactionally bound idempotent registration/rotation, cap counts/rates, recheck issuing active sessions during send/resolve; reject cross-account and late-generation callbacks. Resolve checks current content access.
- [x] Check: real-PG two-account/admin/clone/race tests, expiry/revoke/attention fake-clock tests.

## 3. #556 outbox and bounded worker

- [x] Add `notifications/outbox`, `plan_delivery`, `dispatch_delivery`, `cleanup_delivery`; migrations with due indexes, leases, uniqueness, budgets and retention.
- [x] Follow exact TEXT/DM SQL insert branches and create metadata intent only for a newly inserted message; no body/provider I/O in transaction. Real commit/rollback/replay tests.
- [x] Page fanout; claim SKIP LOCKED; recheck message/access/read/settings/binding before each attempt. TTL remains tied to original event. Bound attention delay, sound window, retries, unknown delivery and queue growth.
- [x] Check: real-PG competing workers/restart/commit-crash; fake transport429/5xx/timeout; controlled bounded synthetic queue test.

## 4. #560 relay and #559 Web sender

- [x] Create dedicated `cmd/push-relay` and relay tenant enrollment, device challenge, pairing grant, send, revoke, receipt and queue leaves. Trusted publisher origin and installation signing key are pinned; raw token goes directly to relay. Durable quotas/replay/expiry and encrypted credentials.
- [x] Fixed provider adapter uses FCM HTTPv1; route-scoped tenant authorization, neutral templates, explicit TTL. Mock provider confirms correct encoding/error classes without credentials.
- [x] Implement Web Push using maintained library with HTTPS exact-host policy, public-only DNS answers, IP-pinned dialing, no proxy/redirects and bounded responses/timeouts.
- [x] Check: two-tenant isolation, forged/replayed grants, independent revoke, token spoof, SSRF DNS/IPv6/rebinding/redirect failures, restart/idempotency/quota tests.

## 5. #558 shared client runtime and #559 Web/PWA

- [x] Extend existing settings with account rules, device status, explicit enable and migration preview; preserve autosave/conflict UX. One scope/generation-aware presentation owner.
- [x] Add minimal push-only SW/manifest and IDB coordination; no fetch caching of private data. Common tap handler waits for bootstrap, uses paired origin/account and authenticated resolve, then existing navigation; never starts media or advances read on tap.
- [x] Register notification scenario in `tools/qa/local_features/features.json`; add browser/widget tests for foreground other chat, multi-tab/realtime+push, logout/generation/cold start and unavailable server.
- [x] Check: focused and full Web tests/build, Flutter widget suite, real browser SW journeys and source-resolution screenshots. Run required local_features real-stack command; report missing runtime separately.

## 6. #561 Android and #562 iOS

- [x] Pin compatible firebase_core/firebase_messaging, disable auto-init/analytics by default, initialize only supported mobile capabilities after consent. Shared adapters guard late callbacks and consume initial tap once.
- [x] Integrate Android permission/channel/GMS statuses and foreground/background presentation without touching voice/screen services. Add staging/prod config inputs without publisher secrets.
- [x] Integrate iOS APNs readiness, permission states, push entitlement and environment configuration while preserving ReplayKit/audio. No PushKit or content extension.
- [x] Check: adapter/widget/native configuration regressions; Android build when SDK inputs exist. iOS signed build/physical delivery needs macOS/signing and remains explicitly unavailable on this Windows host.

## 7. #563 operations and #564 acceptance

- [x] Add bounded-label metrics, short spans, source dashboard/alerts, separate relay deployment profile, per-platform flags and send kill switch. Disabled/reenabled queues expire without historical flood.
- [x] Add operator/publisher rotation/enrollment/revoke/rollback runbooks. Preserve repository no-backup-job rule; do not create backup or provision external accounts.
- [x] Add deterministic local acceptance matrix, schema/privacy/SSRF/tenant/queue tests and CI route coverage. Store source/build/platform/command/outcome evidence without secrets.
- [x] Final native cycle: Go test/race/build with real PG, Web tests/build/browser, Dart/Flutter tests/analyze/available native build, contract/spec validators, feature real-stack harness, dashboard query fixtures, diff/line/topology review. New concerns justify reruns; passing checks are not repeated without changes.
- [x] Record PASS/FAIL/NOT_RUN by platform and prerequisite; do not close physical #564/#554 based on mocks or compiler success.

## Local closeout boundary
Implementation and the available local native cycle are complete. Source evidence uses the frozen notification acceptance snapshot, real disposable PostgreSQL, synthetic providers, Chromium and Flutter components. Native debug Android/Windows builds were checked; signed iOS/macOS and physical/provider delivery remain NOT_RUN by the owner's local-only scope. The Mac/Colima real-stack harness and Go race checks are BLOCKED by observed host prerequisites. Those outcomes do not close epic554 or physical gate564. See docs/operations/notifications/local-acceptance.md and evidence/notifications/ for commands and status.
