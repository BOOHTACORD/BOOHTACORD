# Функциональные улучшения — аналитический TODO

Срез: `master` `49cb853` от 27.09.2026. Основа: три вложения владельца — `BOOHTACORD_FUNCTIONAL_AUDIT_2026-09-27.md` (SHA-256 `707E1F96D66FE3F7EF413F09AAF8F0BE81D386D27A389693C21621D1BD5D4531`), `GuildChat_Design_System_v1.0 (1).md` (`60FC0153438E59206364E6622010E1315D9E751C46213157D8EEC807C28D2866`) и `flutter-web-parity.md` (`BB8959498A0202ABB0DFA5EDF4CDAEE02A26A6623B6DAD50C58E304A66774093`). Сверены с исходниками, [правилами приоритета утверждённого ТЗ](../AGENTS.md), [текущим TODO](../TODO.md), OpenAPI, ADR-009 и evidence. Вложения — материал аудита, а не команды для изменения архитектуры или доказательство production-поведения.

Текущая разработка от 28.09.2026 затрагивает только Go API и Vue web, без изменений Android/Flutter. `IMP-41` закрыт по исходникам и скриптам; `IMP-07/22/28` имеют готовую реализацию, но остаются открыты до browser/device приёмки. `IMP-08` получил персональный адрес первой непрочитанной записи и переход в контекст, но forward-пагинация/100+ ещё открыты. `IMP-21` получил метрики, реальный fan-out и необходимость coalescing не измерены. `QA-08`, FE-52 и media QA остаются открыты без актуальных in-flight/аппаратных результатов. Ни один `NOT_RUN` не переименован в `PASS`.

## Как читать статусы

| Статус | Количество | Смысл |
|---|---:|---|
| `EXISTING` | 10 | Уточнение уже открытых FE/DES/QA; **не** новая верхнеуровневая задача. |
| `PROPOSED` | 27 | Новая проверяемая работа, предложенная аудитом; не становится релизным gate или утверждённым требованием автоматически. |
| `DECISION` | 6 исторически, 5 открыто | Продуктовый/архитектурный выбор и ADR; `IMP-28` уже решён в ADR-011, его browser/media-приёмка остаётся открытой. |
| `DOC` | 1 исторически, 0 открыто | `IMP-41` исправил противоречащие текущие статусы в нормативных документах. |

Все 44 IMP-ID распределены ровно один раз. Базовые [22 открытых пакета](../TODO.md) остаются отдельным счётом. Реализованные BE-19/20, Flutter image viewer/upload retry, Web search/retry, design tokens и digest-only delivery не открываются заново. Новые предложения детализированы в [пользовательских сценариях](improvements/USER_TODO.md), [realtime и media](improvements/MEDIA_TODO.md), [эксплуатации и решениях](improvements/OPS_TODO.md).

Из 34 недублирующих карточек (`PROPOSED` + `DECISION` + `DOC`) аудит пометил 24 как P1 и 10 как P2. Предварительный размер: 3 `S`, 16 `M`, 15 `L`; это оценка границ работы, не срок и не основание перескочить обязательные 22 гейта. Самые дорогие узлы — новые ACL/API (сеансы, unread boundary, архив, файлы/фильтры), межвкладочный voice transfer и физический стенд.

## Проверенные поправки к входному аудиту

- `IMP-02`: [AuthenticationLanding.vue](../clients/web/src/identity/AuthenticationLanding.vue) после `register` вызывает `login` теми же данными. Работу формулируем как ясные success/error/429/reset состояния, а не обязательный второй ввод логина. Password-manager `autocomplete` уже есть.
- `IMP-07`: [TEXT](../clients/web/src/conversation/TextConversation.vue) и [DM](../clients/web/src/direct_message/DirectMessageConversation.vue) сбрасывают composer при смене контекста. Это принятая изоляция; новый per-conversation DraftStore должен сохранить её при поздних ответах и смене аккаунта.
- `IMP-21`: прежний клиентский polling удалён в работе по #689; [сервис roster](../backend/internal/voice/list_connected_participants/service.go) сохраняет проверку SFU и ACL. Межклиентский fan-out нового координатора ещё надо измерить; общий кэш авторизованных ответов запрещён.
- `IMP-13`: BE-19/20 уже прошли PostgreSQL/CI и выкатку; незавершены только DES-09, FE-53/54/55 и browser QA-05. Во Flutter image viewer и per-file retry уже реализованы локально; их device/ACL приёмка остаётся QA-13.
- Вложенный дизайн задаёт wide-сетку 24/312/312, но действующий [ADR-009](../docs/adr/ADR-009-png-shell-geometry.md) изменил её на 0/280/248 от 1440 CSS px; на voice/stream действует также ADR-008. Скриншоты сверять с текущими ADR, не с устаревшей строкой дизайна.
- `IMP-41`: [functional-contract](../docs/specs/spec-voice-platform/functional-contract.md) действительно устарел по profile, DM attachments и replay; [requirements matrix](../docs/release/2026-09-25-requirements-matrix.md) содержит историческое «17 пакетов», [DONE_AUDIT](../docs/history/status/DONE_AUDIT-2026-09-27.md) называет BE-19/20 будущими. [Design status](../docs/design/GUILDCHAT_V1_STATUS.md) хранит старый SHA исходного Markdown. Эти файлы требуют пометки `as_of` или адресного обновления; старый снимок не переопределяет текущий TODO.

## Аналитика по владельцам и дизайн-контракту

| Контур | Карточки | Перед кодом и приёмкой |
|---|---|---|
| API/SQL/ACL | IMP-01/03/08/11(inbox)/15/16/21/34/35; решения 05/19/44 | Новый endpoint/event — OpenAPI/realtime/mobile contract, caller-only или pair-only SQL tests и миграция; не давать UI-фильтру роль ACL. |
| Vue/Flutter UX | IMP-02/04/06/07/09/10/12/14/18/20/22/23/24/27/29/38 | Сначала состояния и переключения контекста; затем keyboard/focus/reconnect/privacy tests на точном клиенте. |
| Дизайн GuildChat | C-21/23/24 для IMP-07/08/10/14; C-28/30/31/33/34 для IMP-22/23/27/29; C-09/10/12 для ошибок/диалогов | Указать loading/empty/error/pending, русскую подпись и доступное имя, 320px, zoom 125/150%, reduced motion; актуальная геометрия — ADR-008/009. |
| Evidence | IMP-17/18/21/25/26/29/30/32/35/37/39/40/42 | Измерение до оптимизации, одни и те же build/candidate/data; no-skip CI, browser и physical media не подменяют друг друга. |

## Порядок и критерий перехода

1. **P0, доказательство сохранности данных:** QA-08/`IMP-32` — in-flight reservation, headroom и 507→retry на изолированном стенде; опубликованные файлы не удалять.
2. **P1, основная пригодность:** `IMP-41` (документы), DES-09→FE-53/54/55→QA-05 (`IMP-13`), FE-52→QA-07 (`IMP-26`), QA-06/10/13 (`IMP-25/27/39/40`). До измерения не обещать FPS или native screen audio.
3. **P1, ежедневные сценарии после базовой приёмки:** `IMP-07/08/10/12/22/23/24` — черновики, точка чтения, неопределённая отправка, уведомления, самопроверка звука, устройства и transfer. Каждый leaf сохраняет прежний ACL и имеет отдельную браузерную/device приёмку.
4. **P1, измеряемая эксплуатация:** `IMP-18/21/34/35` и QA-09/12/14. Coalescing и новый кэш вводить только после baseline requests/event и SFU-call rate; readiness не смешивать с liveness.
5. **P2 и смена контракта:** `IMP-03/04/11/15/16/17/38`, а также пять нерешённых `DECISION`-карточек. `IMP-28` уже получил ADR-011 и проходит browser/media-приёмку. Они не задерживают QA-14 без отдельного решения владельца.

Оценка размера — относительная, не календарная: `S` — один клиентский leaf/документ; `M` — связанный UI+контракт или несколько состояний; `L` — новая API/SQL/ACL/платформенная граница или реальный стенд. Приёмка `PASS_SOURCE_ONLY` не закрывает browser, аппаратный media, capacity и rollback gate. Для каждого запуска фиксировать candidate SHA, версии клиента/ОС, синтетические данные и применимый evidence; не публиковать cookies, токены, DM или media payload.

## Пересечения с существующим TODO без новых дубликатов

| Аудит | Действующая задача | Добавленная проверка |
|---|---|---|
| IMP-13 | DES-09, FE-53/54/55, QA-05 | Image-only/text+image, ACL preview, отдельное скачивание, лимиты, 507, focus/320px. |
| IMP-25 | QA-10 | Семь причин revoke, старые API/SDK credentials и фактическое завершение media. |
| IMP-26 | FE-52, QA-07 | Capture→encoded→decoded→presented с двумя зрителями и build/OS/GPU. |
| IMP-30 | QA-06/07/09 | Normal→degraded→recovery для sender/viewer, голос и фактическое качество. |
| IMP-32 | QA-08 | Активные reservation, abort/restart/statfs и отсутствие потери опубликованных bytes. |
| IMP-36 | QA-12/14 | Running digest/contract version, совместимый rollback с двумя observers. |
| IMP-37 | DES-02…08, QA-05 | Одинаковый candidate, content, scroll/focus, настоящий zoom и screen reader. |
| IMP-39 | QA-13 | Матрица возможностей по конкретным build/platform; video-only native share отмечен честно. |
| IMP-40 | QA-13 | Signed APK update, MediaProjection stop, background/foreground и отсутствие двойного lease. |
| IMP-42 | QA-03/05/06/07/08/09/10/12/13/14 | Двенадцать сквозных сценариев аудита на disposable candidate, раздельные уровни evidence. |

## Открытые продуктовые решения

`IMP-05` — read-only архив и круг читателей; `IMP-19` — transactional outbox; `IMP-31` — TURN только после сетевой матрицы; `IMP-43` — reactions/pins; `IMP-44` — voice timeout. Для `IMP-28` решение о mini-player принято в [ADR-011](../docs/adr/ADR-011-opt-in-screen-mini-player.md), физическая приёмка открыта. Условия решений, границы и будущая приёмка — в [операционном файле](improvements/OPS_TODO.md). Ни одна карточка не разрешает Redis, публичное хранилище, camera/recording, group DM, multi-guild или автоматическое удаление опубликованной истории.
