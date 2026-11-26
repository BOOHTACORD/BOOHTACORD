# Текстовые каналы и личные сообщения

ID: `chat.text-dm`

Описание: Pair-only DM and TEXT support history, protected files, reply/edit/delete, unread, reactions and pins; retry never duplicates a user command.

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

- cmp.flutter.conversation: [clients/flutter/lib/src/features/conversation/lifecycle/controller.dart](../../../../clients/flutter/lib/src/features/conversation/lifecycle/controller.dart)
- cmp.web.attachment\_upload\_queue: [clients/web/src/conversation/TextMessageAttachmentPicker.vue](../../../../clients/web/src/conversation/TextMessageAttachmentPicker.vue), [clients/web/src/conversation/upload\_queue/failure.ts](../../../../clients/web/src/conversation/upload_queue/failure.ts), [clients/web/src/conversation/upload\_queue/text\_layout.css](../../../../clients/web/src/conversation/upload_queue/text_layout.css), [clients/web/src/conversation/upload\_queue/queue.ts](../../../../clients/web/src/conversation/upload_queue/queue.ts), [clients/web/src/conversation/upload\_queue/runner.ts](../../../../clients/web/src/conversation/upload_queue/runner.ts), [clients/web/src/conversation/upload\_queue/types.ts](../../../../clients/web/src/conversation/upload_queue/types.ts), [clients/web/src/conversation/upload\_queue/transport.ts](../../../../clients/web/src/conversation/upload_queue/transport.ts), [clients/web/src/conversation/upload\_queue/drop.ts](../../../../clients/web/src/conversation/upload_queue/drop.ts), [clients/web/src/conversation/upload\_queue/QueueList.vue](../../../../clients/web/src/conversation/upload_queue/QueueList.vue)
- cmp.web.dm\_attachment\_upload: [clients/web/src/direct\_message/attachment\_upload/client.ts](../../../../clients/web/src/direct_message/attachment_upload/client.ts), [clients/web/src/direct\_message/direct\_message\_attachment\_upload\_client.ts](../../../../clients/web/src/direct_message/direct_message_attachment_upload_client.ts), [clients/web/src/direct\_message/DirectMessageAttachmentPicker.vue](../../../../clients/web/src/direct_message/DirectMessageAttachmentPicker.vue)
- cmp.web.history\_measurements: [clients/web/src/conversation/history\_window/use.ts](../../../../clients/web/src/conversation/history_window/use.ts), [clients/web/src/conversation/history\_window/measurement\_delivery/frame.ts](../../../../clients/web/src/conversation/history_window/measurement_delivery/frame.ts)
- cmp.web.protected\_image\_viewer: [clients/web/src/conversation/ProtectedImageViewer.vue](../../../../clients/web/src/conversation/ProtectedImageViewer.vue), [clients/web/src/conversation/protected\_image\_preview/use\_protected\_image\_preview.ts](../../../../clients/web/src/conversation/protected_image_preview/use_protected_image_preview.ts), [clients/web/src/conversation/protected\_image\_preview/viewer.css](../../../../clients/web/src/conversation/protected_image_preview/viewer.css), [clients/web/src/conversation/protected\_image\_viewer/component.vue](../../../../clients/web/src/conversation/protected_image_viewer/component.vue), [clients/web/src/conversation/protected\_image\_viewer/dialog.ts](../../../../clients/web/src/conversation/protected_image_viewer/dialog.ts), [clients/web/src/conversation/protected\_image\_viewer/preview.ts](../../../../clients/web/src/conversation/protected_image_viewer/preview.ts), [clients/web/src/conversation/protected\_image\_viewer/viewer.css](../../../../clients/web/src/conversation/protected_image_viewer/viewer.css)
- cmp.web.workspace: [clients/web/src/workspace/WorkspaceApp.vue](../../../../clients/web/src/workspace/WorkspaceApp.vue)
