# Управление голосом

ID: `voice.controls`

Описание: Join, mute/deafen, PTT, volume, lease revocation and reconnect retain the same user intent and server ACL.

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

- cmp.backend.voice\_deafen\_api: [backend/internal/media/set\_voice\_deafen/api/handler.go](../../../../backend/internal/media/set_voice_deafen/api/handler.go)
- cmp.backend.voice\_deafen\_livekit\_writer: [backend/internal/media/set\_voice\_deafen/livekit/writer.go](../../../../backend/internal/media/set_voice_deafen/livekit/writer.go)
- cmp.backend.voice\_deafen\_repository: [backend/internal/media/set\_voice\_deafen/postgres/repository.go](../../../../backend/internal/media/set_voice_deafen/postgres/repository.go)
- cmp.backend.voice\_deafen\_routes: [backend/internal/app/media\_routes/voice\_deafen/configure.go](../../../../backend/internal/app/media_routes/voice_deafen/configure.go), [backend/internal/app/media\_routes/voice\_deafen\_routes.go](../../../../backend/internal/app/media_routes/voice_deafen_routes.go)
- cmp.backend.voice\_deafen\_service: [backend/internal/media/set\_voice\_deafen/deafen.go](../../../../backend/internal/media/set_voice_deafen/deafen.go)
- cmp.flutter.deepfilter\_preflight: [clients/flutter/packages/flutter\_webrtc/common/rnnoise/deepfilter/preflight/benchmark.h](../../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/deepfilter/preflight/benchmark.h)
- cmp.flutter.native\_auto\_preflight: [clients/flutter/lib/src/services/native\_noise\_auto\_preflight.dart](../../../../clients/flutter/lib/src/services/native_noise_auto_preflight.dart), [clients/flutter/packages/flutter\_webrtc/common/rnnoise/preflight/worker.h](../../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/preflight/worker.h), [clients/flutter/packages/flutter\_webrtc/common/rnnoise/preflight/warmup.h](../../../../clients/flutter/packages/flutter_webrtc/common/rnnoise/preflight/warmup.h)
- cmp.flutter.native\_auto\_research: [clients/flutter/lib/src/services/native\_noise\_auto\_research.dart](../../../../clients/flutter/lib/src/services/native_noise_auto_research.dart), [clients/flutter/lib/src/services/native\_noise\_research\_debug.dart](../../../../clients/flutter/lib/src/services/native_noise_research_debug.dart)
- cmp.flutter.voice\_background\_playback: [clients/flutter/lib/src/features/voice/background\_playback/policy.dart](../../../../clients/flutter/lib/src/features/voice/background_playback/policy.dart), [clients/flutter/lib/src/features/voice/background\_playback/session.dart](../../../../clients/flutter/lib/src/features/voice/background_playback/session.dart), [clients/flutter/lib/src/features/voice/background\_playback/status.dart](../../../../clients/flutter/lib/src/features/voice/background_playback/status.dart), [clients/flutter/lib/src/features/voice/background\_playback/sync.dart](../../../../clients/flutter/lib/src/features/voice/background_playback/sync.dart)
- cmp.flutter.voice\_controller: [clients/flutter/lib/src/features/voice/lifecycle/controller.dart](../../../../clients/flutter/lib/src/features/voice/lifecycle/controller.dart)
- cmp.flutter.voice\_deafen\_api: [clients/flutter/lib/src/features/voice/microphone/deafen\_api.dart](../../../../clients/flutter/lib/src/features/voice/microphone/deafen_api.dart)
- cmp.flutter.voice\_deafen\_status: [clients/flutter/lib/src/screens/workspace\_ui/participant\_deafened/component.dart](../../../../clients/flutter/lib/src/screens/workspace_ui/participant_deafened/component.dart)
- cmp.web.auto\_preflight: [clients/web/src/voice/noise\_suppression/auto\_preflight/benchmark.ts](../../../../clients/web/src/voice/noise_suppression/auto_preflight/benchmark.ts), [clients/web/src/voice/noise\_suppression/auto\_preflight/client.ts](../../../../clients/web/src/voice/noise_suppression/auto_preflight/client.ts), [clients/web/src/voice/noise\_suppression/auto\_preflight/probe.worker.ts](../../../../clients/web/src/voice/noise_suppression/auto_preflight/probe.worker.ts), [clients/web/src/voice/noise\_suppression/auto\_preflight/worker\_runner.ts](../../../../clients/web/src/voice/noise_suppression/auto_preflight/worker_runner.ts), [clients/web/src/voice/noise\_suppression/microphone\_adapter/auto\_fixture.ts](../../../../clients/web/src/voice/noise_suppression/microphone_adapter/auto_fixture.ts)
- cmp.web.noise\_distribution\_notices: [clients/web/public/audio/deepfilternet/research-d375b2d/LICENSE-WorkAdventure.txt](../../../../clients/web/public/audio/deepfilternet/research-d375b2d/LICENSE-WorkAdventure.txt)
- cmp.web.voice\_controls: [clients/web/src/voice/VoiceDock.vue](../../../../clients/web/src/voice/VoiceDock.vue)
- cmp.web.voice\_deafen\_attribute: [clients/web/src/voice/voice\_deafen\_attribute.ts](../../../../clients/web/src/voice/voice_deafen_attribute.ts)
- cmp.web.voice\_deafen\_publisher: [clients/web/src/voice/voice\_deafen\_publisher.ts](../../../../clients/web/src/voice/voice_deafen_publisher.ts)
