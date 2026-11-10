# Фоновые адресные уведомления

ID: `notifications.addressed_background_v1`

Описание: Account consent and per-device opt-in stay separate; resolve an addressed message with current ACL, suppress duplicates, and never auto-read or join voice.

[← Матрица](../index.md)

## Платформы

| Платформа | Исходники | Релиз | Runtime |
| --- | --- | --- | --- |
| web | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| windows | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| macos | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| android | UNKNOWN | UNKNOWN | NOT\_RUN |
| ios | UNKNOWN | UNKNOWN | NOT\_RUN |

## Компоненты

- cmp.android.push\_driver: [clients/flutter/lib/src/features/notifications/mobile\_driver/firebase\_driver.dart](../../../../clients/flutter/lib/src/features/notifications/mobile_driver/firebase_driver.dart)
- cmp.ios.push\_adapter: [clients/flutter/ios/Runner/notifications/PushSupport.swift](../../../../clients/flutter/ios/Runner/notifications/PushSupport.swift)
- cmp.web.notification\_settings: [clients/web/src/notification/NotificationSettings.vue](../../../../clients/web/src/notification/NotificationSettings.vue)
