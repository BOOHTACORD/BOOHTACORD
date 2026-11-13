# Восстановление состава голосового канала

ID: `voice.roster_long_recovery`

Описание: An authenticated foreground client recovers an authorized, nonempty voice roster after a long transient service outage without inventing an empty result; logout, 401 and 403 still stop automatic retries.

[← Матрица](../index.md)

## Платформы

| Платформа | Исходники | Релиз | Runtime |
| --- | --- | --- | --- |
| web | UNKNOWN | UNKNOWN | NOT\_RUN |
| windows | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| macos | UNKNOWN | UNKNOWN | NOT\_VERIFIED |
| android | UNKNOWN | UNKNOWN | NOT\_RUN |
| ios | UNKNOWN | UNKNOWN | NOT\_RUN |

## Компоненты

- cmp.flutter.voice\_roster\_recovery: [clients/flutter/lib/src/features/realtime/lifecycle/recovery.dart](../../../../clients/flutter/lib/src/features/realtime/lifecycle/recovery.dart)
- cmp.web.voice\_roster\_recovery: [clients/web/src/voice/roster\_socket/state.ts](../../../../clients/web/src/voice/roster_socket/state.ts)
