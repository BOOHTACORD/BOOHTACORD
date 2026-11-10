# Личная мелодия входа

ID: `voice.event-sounds-private-melody`

Описание: Current-room publisher/member events produce bounded local cues; account-scoped settings and private processed join melodies are available in Web and Flutter. Baseline, reconnect, self and viewer-only actions stay quiet.

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

- cmp.backend.voice\_join\_sound\_routes: [backend/internal/app/voice\_sound\_routes/join.go](../../../../backend/internal/app/voice_sound_routes/join.go)
- cmp.backend.voice\_join\_sound\_service: [backend/internal/voice/join\_sound/service.go](../../../../backend/internal/voice/join_sound/service.go)
- cmp.flutter.voice\_melody: [clients/flutter/lib/src/features/voice/join\_sound/panel.dart](../../../../clients/flutter/lib/src/features/voice/join_sound/panel.dart)
- cmp.web.voice\_melody: [clients/web/src/voice/join\_sound/Panel.vue](../../../../clients/web/src/voice/join_sound/Panel.vue)

## Связи компонентов

- cmp.backend.voice\_join\_sound\_routes → cmp.backend.voice\_join\_sound\_service (зависит от)
