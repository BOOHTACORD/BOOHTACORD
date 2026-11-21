# Статус отсутствия и AFK-канал

ID: `voice.idle-afk`

Описание: Статус отсутствия и AFK-канал

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

- cmp.backend.afk\_routing: [backend/internal/voice/route\_inactive\_members/service.go](../../../../backend/internal/voice/route_inactive_members/service.go), [backend/internal/voice/route\_inactive\_members/worker/worker.go](../../../../backend/internal/voice/route_inactive_members/worker/worker.go)
- cmp.backend.afk\_settings: [backend/internal/guild/update\_settings/api/patch.go](../../../../backend/internal/guild/update_settings/api/patch.go), [backend/internal/guild/update\_settings/postgres/repository.go](../../../../backend/internal/guild/update_settings/postgres/repository.go)
- cmp.backend.idle\_afk\_migration: [backend/internal/database/migrate/migrations/0068\_idle\_presence\_afk\_voice.sql](../../../../backend/internal/database/migrate/migrations/0068_idle_presence_afk_voice.sql)
- cmp.backend.idle\_presence: [backend/internal/realtime/event\_hub/activity.go](../../../../backend/internal/realtime/event_hub/activity.go), [backend/internal/realtime/event\_hub/activity\_inactive.go](../../../../backend/internal/realtime/event_hub/activity_inactive.go), [backend/internal/realtime/event\_hub/reconnect\_history.go](../../../../backend/internal/realtime/event_hub/reconnect_history.go), [backend/internal/realtime/connect\_session/event\_stream.go](../../../../backend/internal/realtime/connect_session/event_stream.go), [backend/internal/realtime/connect\_session/stream\_helpers.go](../../../../backend/internal/realtime/connect_session/stream_helpers.go)
- cmp.flutter.idle\_afk: [clients/flutter/lib/src/guild\_presence\_state.dart](../../../../clients/flutter/lib/src/guild_presence_state.dart)
- cmp.flutter.voice\_activity\_heartbeat: [clients/flutter/lib/src/features/realtime/lifecycle/voice\_activity\_heartbeat.dart](../../../../clients/flutter/lib/src/features/realtime/lifecycle/voice_activity_heartbeat.dart)
- cmp.flutter.windows\_system\_activity: [clients/flutter/lib/src/features/realtime/system\_activity/windows.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/windows.dart), [clients/flutter/lib/src/features/realtime/system\_activity/capabilities.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/capabilities.dart), [clients/flutter/lib/src/features/realtime/system\_activity/inactivity\_reporter.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/inactivity_reporter.dart), [clients/flutter/lib/src/features/realtime/system\_activity/poller.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/poller.dart), [clients/flutter/lib/src/features/realtime/system\_activity/reporter.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/reporter.dart), [clients/flutter/lib/src/features/realtime/system\_activity/throttle.dart](../../../../clients/flutter/lib/src/features/realtime/system_activity/throttle.dart)
- cmp.web.idle\_afk: [clients/web/src/identity/guild\_presence.ts](../../../../clients/web/src/identity/guild_presence.ts)
- cmp.web.system\_activity: [clients/web/src/realtime/system\_activity/controller.ts](../../../../clients/web/src/realtime/system_activity/controller.ts), [clients/web/src/realtime/system\_activity/Settings.vue](../../../../clients/web/src/realtime/system_activity/Settings.vue), [clients/web/src/realtime/system\_activity/app\_interaction.ts](../../../../clients/web/src/realtime/system_activity/app_interaction.ts), [clients/web/src/realtime/system\_activity/browser.ts](../../../../clients/web/src/realtime/system_activity/browser.ts), [clients/web/src/realtime/system\_activity/realtime\_reporter.ts](../../../../clients/web/src/realtime/system_activity/realtime_reporter.ts), [clients/web/src/realtime/system\_activity/throttle.ts](../../../../clients/web/src/realtime/system_activity/throttle.ts)
- cmp.web.voice\_activity\_heartbeat: [clients/web/src/realtime/voice\_activity\_heartbeat.ts](../../../../clients/web/src/realtime/voice_activity_heartbeat.ts)
