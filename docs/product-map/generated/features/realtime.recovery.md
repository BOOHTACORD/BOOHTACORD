# Восстановление realtime

ID: `realtime.recovery`

Описание: Apply durable hints in order before cursor acknowledgement; expire cursor into full snapshots; ready alone resets bounded jitter retry.

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

- cmp.backend.session\_revalidation: [backend/internal/realtime/connect\_session/session\_monitor.go](../../../../backend/internal/realtime/connect_session/session_monitor.go), [backend/internal/realtime/connect\_session/session\_monitor\_spread.go](../../../../backend/internal/realtime/connect_session/session_monitor_spread.go)
- cmp.flutter.realtime: [clients/flutter/lib/src/features/realtime/lifecycle/controller.dart](../../../../clients/flutter/lib/src/features/realtime/lifecycle/controller.dart)
- cmp.web.protected\_recovery: [clients/web/src/workspace/workspace\_realtime.ts](../../../../clients/web/src/workspace/workspace_realtime.ts), [clients/web/src/workspace/protected\_refresh/scope.ts](../../../../clients/web/src/workspace/protected_refresh/scope.ts), [clients/web/src/workspace/protected\_refresh/gate.ts](../../../../clients/web/src/workspace/protected_refresh/gate.ts), [clients/web/src/workspace/protected\_refresh/stores.ts](../../../../clients/web/src/workspace/protected_refresh/stores.ts), [clients/web/src/workspace/protected\_refresh/types.ts](../../../../clients/web/src/workspace/protected_refresh/types.ts), [clients/web/src/channel/topology\_store.ts](../../../../clients/web/src/channel/topology_store.ts)
- cmp.web.realtime\_connection\_lifecycle: [clients/web/src/realtime/connection\_lifecycle/controller.ts](../../../../clients/web/src/realtime/connection_lifecycle/controller.ts), [clients/web/src/realtime/connection\_lifecycle/session\_recovery.ts](../../../../clients/web/src/realtime/connection_lifecycle/session_recovery.ts)
- cmp.web.realtime\_store: [clients/web/src/realtime/realtime\_store.ts](../../../../clients/web/src/realtime/realtime_store.ts)

## Связи компонентов

- cmp.web.protected\_recovery → cmp.web.realtime\_store (зависит от)
- cmp.web.realtime\_store → cmp.web.realtime\_connection\_lifecycle (зависит от)
