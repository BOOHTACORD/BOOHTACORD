# Voice event sounds and personal join sound — Implementation Plan

> Work in bounded, independently tested capability packets. No release or production claim until the issue's full acceptance matrix passes.

**Goal:** Implement #676 across the existing API, Web and Flutter clients without sending audio through LiveKit or weakening room ACL.

**Architecture:** Store revisioned account-bound listener preferences and private sound metadata in the existing API/database. Build one event policy per shared client runtime with matching fixtures for baseline, deduplication, reconnect and leave/stream-stop arbitration. Play bounded local audio only; decode, normalize, validate and replace uploaded audio in an isolated server worker with fail-closed ACL and fallback.

**Tech stack:** Go/PostgreSQL existing object storage and secure session; Vue/TypeScript Web Audio; shared Flutter and existing flutter_soloud; existing LiveKit event sources.

## Packets and checks

1. **Preferences contract and persistence.** Add focused RED tests for defaults, account/deployment isolation, optimistic revision conflicts, secure mutation, migration with existing OFF settings and no cross-account leakage. Implement a leaf API/model/repository/migration following `backend/internal/notifications/preferences/{api,postgres}` and registered routes. Verify Go tests, API contract/traceability and two-account integration.
2. **Private audio lifecycle.** First test size/content sniffing, duration, decoder resource caps, volume and true-peak bounds, metadata stripping, ownership, current-room authorization, revocation, atomic replacement and cleanup. Implement bounded server processing and private object storage with one active item and documented rollback; missing decoder or resource must never block voice. Verify adversarial cases and two-account ACL with real stack.
3. **Event semantics.** Starting from `clients/web/src/voice/voice_participant_sound_tracker.ts` and `clients/flutter/lib/src/features/voice/voice_participant_sound_tracker.dart`, add matching fixtures for baseline, self filtering, channel/lease identity, deduplication, delayed leave, reconnect, stream replacement and leave-with-stream suppression. Connect confirmed participant and publication lifecycle events; never equate viewer selection with publication. Verify fake-clock tests and two-client real stack.
4. **Playback and controls.** Add shared assets and bounded queue, master/per-event/custom switches and volume, default fallback, route and deafen behavior, gesture/autoplay handling and no late custom playback. Wire `clients/web/src/voice/stream_start_chime.ts`, notification settings, Flutter voice sound and notification settings; test migration, account switch, offline errors, custom fallback and per-event controls.
5. **Author UI and acceptance.** Implement upload/preview/enable/delete and safe fallback; register local feature scenarios and run contract, traceability, native test/build and exact-head real-stack acceptance with visual review. Verify two clients, physical audio routes, no ducking or RTP, supported background behavior and Windows/macOS/Android/iOS/Web separately. Record NOT_RUN where unavailable. Deploy only a fully passing reviewed exact-head build with a tested feature flag and rollback.
