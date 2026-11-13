# Системная архитектура — частичная схема исходников

Ссылки отражают исходники в этой ветке. Тестовый файл не подтверждает PASS, релиз или runtime.

[Матрица функций](index.md)

## Компоненты

| ID | Компонент | Исходник |
| --- | --- | --- |
| sys.web | Web-клиент | [clients/web/src/main.ts](../../../clients/web/src/main.ts) |
| sys.windows | Windows | [clients/flutter/windows/runner/main.cpp](../../../clients/flutter/windows/runner/main.cpp) |
| sys.macos | macOS | [clients/flutter/macos/Runner/AppDelegate.swift](../../../clients/flutter/macos/Runner/AppDelegate.swift) |
| sys.android | Android | [clients/flutter/android/app/src/main/kotlin/ru/boohtacord/app/MainActivity.kt](../../../clients/flutter/android/app/src/main/kotlin/ru/boohtacord/app/MainActivity.kt) |
| sys.ios | iOS | [clients/flutter/ios/Runner/AppDelegate.swift](../../../clients/flutter/ios/Runner/AppDelegate.swift) |
| sys.flutter.shared | Общий Flutter-клиент | [clients/flutter/lib/main.dart](../../../clients/flutter/lib/main.dart) |
| sys.proxy | Обратный прокси | [deploy/caddy/Caddyfile](../../../deploy/caddy/Caddyfile) |
| sys.api | Go API | [backend/cmd/api/main.go](../../../backend/cmd/api/main.go) |
| sys.postgres | PostgreSQL | [deploy/compose.yaml](../../../deploy/compose.yaml) |
| sys.livekit | LiveKit | [deploy/livekit/livekit.yaml](../../../deploy/livekit/livekit.yaml) |
| sys.http\_contract | HTTP-контракт | [contracts/openapi.yaml](../../../contracts/openapi.yaml) |
| sys.realtime\_contract | Realtime-контракт | [contracts/realtime.schema.json](../../../contracts/realtime.schema.json) |
| sys.acceptance | Локальная приёмка | [tools/qa/critical\_client\_acceptance/media.mjs](../../../tools/qa/critical_client_acceptance/media.mjs) |

## Направленные связи

- sys.windows → sys.flutter.shared (runs)
- sys.macos → sys.flutter.shared (runs)
- sys.android → sys.flutter.shared (runs)
- sys.ios → sys.flutter.shared (runs)
- sys.web → sys.proxy (calls)
- sys.flutter.shared → sys.proxy (calls)
- sys.proxy → sys.api (routes)
- sys.api → sys.postgres (depends\_on)
- sys.api → sys.livekit (calls)
- sys.web → sys.livekit (media)
- sys.flutter.shared → sys.livekit (media)
- sys.api → sys.http\_contract (depends\_on)
- sys.api → sys.realtime\_contract (depends\_on)
- sys.api → sys.acceptance (verified\_by)
