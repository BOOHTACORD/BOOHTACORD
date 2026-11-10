# Восстановление голосового канала

ID: `voice.long_recovery`

Описание: After a long API/LiveKit restart beyond SDK retry limit and the 60-second media credential validity, foreground clients reacquire a fresh authorized lease and automatically rejoin the original voice channel without forcing a transfer. Explicit leave, logout, admin revocation, channel closure or another-device handoff must stop retries.

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

- cmp.flutter.voice\_recovery: [clients/flutter/lib/src/features/voice/connection\_close/recovery.dart](../../../../clients/flutter/lib/src/features/voice/connection_close/recovery.dart)
- cmp.web.voice\_recovery: [clients/web/src/voice/connection\_state/store.ts](../../../../clients/web/src/voice/connection_state/store.ts)
