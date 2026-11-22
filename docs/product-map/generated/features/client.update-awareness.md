# Доступное обновление

ID: `client.update-awareness`

Описание: Detect an available version without discarding drafts; use reload on Web, approved installer on Android and signed distribution on iOS.

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

- cmp.delivery.windows\_catalog\_promotion: [tools/release/windows\_promotion/intent.py](../../../../tools/release/windows_promotion/intent.py), [deploy/client-updates/catalog.json](../../../../deploy/client-updates/catalog.json)
- cmp.flutter.update\_controller: [clients/flutter/lib/src/features/updates/controller.dart](../../../../clients/flutter/lib/src/features/updates/controller.dart)
- cmp.flutter.update\_evaluator: [clients/flutter/lib/src/features/updates/evaluator.dart](../../../../clients/flutter/lib/src/features/updates/evaluator.dart), [clients/flutter/lib/src/features/updates/identity\_match.dart](../../../../clients/flutter/lib/src/features/updates/identity_match.dart)
- cmp.web.update\_evaluator: [clients/web/src/updates/update\_store.ts](../../../../clients/web/src/updates/update_store.ts), [clients/web/src/updates/evaluator.ts](../../../../clients/web/src/updates/evaluator.ts)
- cmp.web.workspace: [clients/web/src/workspace/WorkspaceApp.vue](../../../../clients/web/src/workspace/WorkspaceApp.vue)

## Связи компонентов

- cmp.flutter.update\_controller → cmp.flutter.update\_evaluator (зависит от)
