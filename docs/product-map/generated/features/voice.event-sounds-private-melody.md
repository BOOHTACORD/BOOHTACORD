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

- cmp.backend.voice\_join\_sound\_processor: [backend/internal/voice/join\_sound/processor/remote.go](../../../../backend/internal/voice/join_sound/processor/remote.go)
- cmp.backend.voice\_join\_sound\_routes: [backend/internal/app/voice\_sound\_routes/join.go](../../../../backend/internal/app/voice_sound_routes/join.go)
- cmp.backend.voice\_join\_sound\_service: [backend/internal/voice/join\_sound/service.go](../../../../backend/internal/voice/join_sound/service.go)
- cmp.flutter.voice\_melody: [clients/flutter/lib/src/features/voice/join\_sound/panel.dart](../../../../clients/flutter/lib/src/features/voice/join_sound/panel.dart)
- cmp.flutter.voice\_melody\_api: [clients/flutter/lib/src/features/voice/join\_sound/api.dart](../../../../clients/flutter/lib/src/features/voice/join_sound/api.dart)
- cmp.flutter.voice\_melody\_controls: [clients/flutter/lib/src/features/voice/join\_sound/controls.dart](../../../../clients/flutter/lib/src/features/voice/join_sound/controls.dart)
- cmp.web.voice\_melody: [clients/web/src/voice/join\_sound/Panel.vue](../../../../clients/web/src/voice/join_sound/Panel.vue)
- cmp.web.voice\_melody\_client: [clients/web/src/voice/join\_sound/client.ts](../../../../clients/web/src/voice/join_sound/client.ts)

## Связи компонентов

- cmp.backend.voice\_join\_sound\_routes → cmp.backend.voice\_join\_sound\_processor (зависит от)
- cmp.backend.voice\_join\_sound\_routes → cmp.backend.voice\_join\_sound\_service (зависит от)
- cmp.flutter.voice\_melody → cmp.flutter.voice\_melody\_controls (зависит от)
- cmp.web.voice\_melody → cmp.web.voice\_melody\_client (зависит от)
