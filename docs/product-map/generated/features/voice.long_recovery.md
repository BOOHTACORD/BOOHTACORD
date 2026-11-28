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
- cmp.web.browser\_resume\_lifecycle: [clients/web/src/voice/browser\_resume/lifecycle.ts](../../../../clients/web/src/voice/browser_resume/lifecycle.ts), [clients/web/src/voice/browser\_resume/session\_binding.ts](../../../../clients/web/src/voice/browser_resume/session_binding.ts)
- cmp.web.voice\_admission\_cleanup: [clients/web/src/voice/admission\_cleanup/cleanup.ts](../../../../clients/web/src/voice/admission_cleanup/cleanup.ts), [clients/web/src/voice/room\_admission/connect.ts](../../../../clients/web/src/voice/room_admission/connect.ts), [clients/web/src/voice/room\_admission/disconnect.ts](../../../../clients/web/src/voice/room_admission/disconnect.ts)
- cmp.web.voice\_recovery: [clients/web/src/voice/connection\_state/store.ts](../../../../clients/web/src/voice/connection_state/store.ts)
- cmp.web.voice\_rejoin\_fixtures: [clients/web/src/voice/room\_admission/session\_fixture.ts](../../../../clients/web/src/voice/room_admission/session_fixture.ts), [clients/web/src/voice/connection\_state/join\_fixture.ts](../../../../clients/web/src/voice/connection_state/join_fixture.ts)
- cmp.web.voice\_signal\_rejoin: [clients/web/src/voice/room\_admission/establish.ts](../../../../clients/web/src/voice/room_admission/establish.ts), [clients/web/src/voice/room\_admission/intent.ts](../../../../clients/web/src/voice/room_admission/intent.ts), [clients/web/src/voice/room\_admission/defaults.ts](../../../../clients/web/src/voice/room_admission/defaults.ts), [clients/web/src/voice/room\_admission/admission\_context.ts](../../../../clients/web/src/voice/room_admission/admission_context.ts)

## Связи компонентов

- cmp.web.voice\_signal\_rejoin → cmp.web.voice\_admission\_cleanup (зависит от)
