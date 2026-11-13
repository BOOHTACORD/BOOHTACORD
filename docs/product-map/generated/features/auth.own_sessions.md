# Управление своими сеансами

ID: `auth.own_sessions`

Описание: Просмотр и завершение сеансов собственного аккаунта.

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

- cmp.backend.list\_own\_sessions: [backend/internal/identity/list\_own\_sessions/api/handler.go](../../../../backend/internal/identity/list_own_sessions/api/handler.go)
- cmp.backend.own\_session\_routes: [backend/internal/app/own\_session\_routes/routes.go](../../../../backend/internal/app/own_session_routes/routes.go)
- cmp.backend.revoke\_own\_sessions: [backend/internal/identity/revoke\_own\_sessions/api/handler.go](../../../../backend/internal/identity/revoke_own_sessions/api/handler.go)
- cmp.flutter.own\_sessions\_api: [clients/flutter/lib/src/features/session/own\_sessions/api.dart](../../../../clients/flutter/lib/src/features/session/own_sessions/api.dart)
- cmp.flutter.own\_sessions\_controller: [clients/flutter/lib/src/features/session/own\_sessions/controller.dart](../../../../clients/flutter/lib/src/features/session/own_sessions/controller.dart)
- cmp.flutter.own\_sessions\_facade: [clients/flutter/lib/src/features/session/own\_sessions/facade.dart](../../../../clients/flutter/lib/src/features/session/own_sessions/facade.dart)
- cmp.flutter.own\_sessions\_panel: [clients/flutter/lib/src/features/session/own\_sessions/panel.dart](../../../../clients/flutter/lib/src/features/session/own_sessions/panel.dart)
- cmp.web.own\_sessions\_client: [clients/web/src/identity/own\_sessions/client.ts](../../../../clients/web/src/identity/own_sessions/client.ts)
- cmp.web.own\_sessions\_panel: [clients/web/src/identity/own\_sessions/OwnSessionsPanel.vue](../../../../clients/web/src/identity/own_sessions/OwnSessionsPanel.vue)
- cmp.web.own\_sessions\_state: [clients/web/src/identity/own\_sessions/state.ts](../../../../clients/web/src/identity/own_sessions/state.ts)

## Зависимости функций

- [auth.session](auth.session.md)

## Связи компонентов

- cmp.backend.own\_session\_routes → cmp.backend.list\_own\_sessions (зависит от)
- cmp.backend.own\_session\_routes → cmp.backend.revoke\_own\_sessions (зависит от)
- cmp.flutter.own\_sessions\_facade → cmp.flutter.own\_sessions\_api (зависит от)
- cmp.flutter.own\_sessions\_panel → cmp.flutter.own\_sessions\_controller (зависит от)
- cmp.web.own\_sessions\_panel → cmp.web.own\_sessions\_state (зависит от)
- cmp.web.own\_sessions\_state → cmp.web.own\_sessions\_client (зависит от)
