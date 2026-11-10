# Регистрация учётной записи

ID: `auth.registration`

Описание: Создание учётной записи с серверной проверкой логина и пароля.

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

- cmp.backend.register\_user: [backend/internal/identity/register\_user/service.go](../../../../backend/internal/identity/register_user/service.go)
- cmp.backend.registration\_api: [backend/internal/identity/register\_user/api/http\_handler.go](../../../../backend/internal/identity/register_user/api/http_handler.go)
- cmp.backend.registration\_policy: [backend/internal/identity/registration/registration.go](../../../../backend/internal/identity/registration/registration.go)
- cmp.backend.registration\_routes: [backend/internal/app/auth\_routes/register.go](../../../../backend/internal/app/auth_routes/register.go)
- cmp.flutter.registration\_ui: [clients/flutter/lib/src/screens/auth\_screen.dart](../../../../clients/flutter/lib/src/screens/auth_screen.dart)
- cmp.web.registration\_client: [clients/web/src/identity/auth\_client.ts](../../../../clients/web/src/identity/auth_client.ts)
- cmp.web.registration\_ui: [clients/web/src/identity/AuthenticationLanding.vue](../../../../clients/web/src/identity/AuthenticationLanding.vue)

## Связи компонентов

- cmp.backend.register\_user → cmp.backend.registration\_policy (зависит от)
- cmp.backend.registration\_api → cmp.backend.register\_user (зависит от)
- cmp.backend.registration\_routes → cmp.backend.register\_user (зависит от)
- cmp.backend.registration\_routes → cmp.backend.registration\_api (зависит от)
