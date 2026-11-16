# Диагностика демонстрации

ID: `screen.diagnostics`

Описание: Distinguish send/receive/decode/present and unknown measurements; no invented capture or performance PASS.

[← Матрица](../index.md)

## Платформы

| Платформа | Исходники | Релиз | Runtime |
| --- | --- | --- | --- |
| web | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| windows | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| macos | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| android | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| ios | UNKNOWN | UNKNOWN | NOT\_VERIFIED |

## Компоненты

- cmp.backend.screen\_telemetry\_api: [backend/internal/media/screen\_telemetry\_relay/api/http\_handler.go](../../../../backend/internal/media/screen_telemetry_relay/api/http_handler.go)
- cmp.backend.screen\_telemetry\_gate: [backend/internal/media/screen\_telemetry\_relay/memory/gate.go](../../../../backend/internal/media/screen_telemetry_relay/memory/gate.go)
- cmp.backend.screen\_telemetry\_routes: [backend/internal/app/media\_routes/screen\_telemetry\_relay/configure.go](../../../../backend/internal/app/media_routes/screen_telemetry_relay/configure.go), [backend/internal/app/media\_routes/screen\_telemetry\_routes.go](../../../../backend/internal/app/media_routes/screen_telemetry_routes.go)
- cmp.backend.screen\_telemetry\_service: [backend/internal/media/screen\_telemetry\_relay/contract.go](../../../../backend/internal/media/screen_telemetry_relay/contract.go), [backend/internal/media/screen\_telemetry\_relay/contract\_types.go](../../../../backend/internal/media/screen_telemetry_relay/contract_types.go), [backend/internal/media/screen\_telemetry\_relay/service.go](../../../../backend/internal/media/screen_telemetry_relay/service.go)
- cmp.backend.screen\_telemetry\_viewer\_acl: [backend/internal/media/screen\_viewer\_presence/postgres/audience.go](../../../../backend/internal/media/screen_viewer_presence/postgres/audience.go)
- cmp.flutter.screen\_diagnostics: [clients/flutter/lib/src/features/screen/lifecycle/controller.dart](../../../../clients/flutter/lib/src/features/screen/lifecycle/controller.dart)
- cmp.flutter.screen\_telemetry\_sender: [clients/flutter/lib/src/features/screen/metrics/telemetry\_envelope.dart](../../../../clients/flutter/lib/src/features/screen/metrics/telemetry_envelope.dart)
- cmp.web.screen\_telemetry\_sender: [clients/web/src/voice/screen\_sender\_telemetry.ts](../../../../clients/web/src/voice/screen_sender_telemetry.ts)
- cmp.web.voice\_controls: [clients/web/src/voice/VoiceDock.vue](../../../../clients/web/src/voice/VoiceDock.vue)

## Связи компонентов

- cmp.backend.screen\_telemetry\_api → cmp.backend.screen\_telemetry\_service (зависит от)
- cmp.backend.screen\_telemetry\_routes → cmp.backend.screen\_telemetry\_api (зависит от)
- cmp.backend.screen\_telemetry\_routes → cmp.backend.screen\_telemetry\_gate (зависит от)
- cmp.backend.screen\_telemetry\_routes → cmp.backend.screen\_telemetry\_service (зависит от)
- cmp.backend.screen\_telemetry\_routes → cmp.backend.screen\_telemetry\_viewer\_acl (зависит от)
