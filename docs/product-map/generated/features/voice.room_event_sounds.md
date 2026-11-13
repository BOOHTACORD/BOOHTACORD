# Звуки событий голосового канала

ID: `voice.room_event_sounds`

Описание: Web and Flutter announce human participant joins/leaves and explicit start/stop of viewing a remote screen stream, with reconnect restoration and internal voice-lease participants suppressed, plus a persisted independent preference.

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

- cmp.backend.voice\_sound\_preferences\_routes: [backend/internal/app/voice\_sound\_routes/register.go](../../../../backend/internal/app/voice_sound_routes/register.go)
- cmp.backend.voice\_sound\_preferences\_service: [backend/internal/voice/sound\_preferences/service.go](../../../../backend/internal/voice/sound_preferences/service.go)
- cmp.flutter.voice\_event\_sounds: [clients/flutter/lib/src/features/voice/voice\_room\_event\_sounds.dart](../../../../clients/flutter/lib/src/features/voice/voice_room_event_sounds.dart)
- cmp.web.voice\_event\_sounds: [clients/web/src/voice/stream\_start\_chime.ts](../../../../clients/web/src/voice/stream_start_chime.ts)

## Связи компонентов

- cmp.backend.voice\_sound\_preferences\_routes → cmp.backend.voice\_sound\_preferences\_service (зависит от)
