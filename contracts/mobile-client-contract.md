# Контракт backend для мобильного клиента

**Статус:** интеграционный контракт для текущего backend. Он не разрешает реализацию мобильного приложения, не добавляет bearer-token flow и не меняет продуктовую границу одной гильдии.

## Канонические источники

- Схемы HTTP-запросов и ответов: [`openapi.yaml`](openapi.yaml) — JSON-документ OpenAPI 3.1, несмотря на расширение файла.
- Схемы realtime-событий: [`realtime.schema.json`](realtime.schema.json).
- Эксплуатационное и media-поведение: [`../docs/API_AND_REALTIME.md`](../docs/architecture/api-and-realtime.md).

Генерируйте REST-модели из `openapi.yaml`; этот документ объясняет мобильный lifecycle и не должен считаться дублирующим источником схем. Все идентификаторы — UUID-строки, timestamps — RFC 3339 `date-time`-строки, а request-схемы отклоняют дополнительные поля, если каноническая схема явно не разрешает иное.

## Транспорт и версионирование

- Базовый URL: `https://<public-host>`; все задокументированные маршруты начинаются с `/api/v1`.
- Используйте HTTPS и проверяйте сертификат публичного хоста. Приватные PostgreSQL, storage, LiveKit management, metrics и `/internal/*` не являются мобильными API.
- Отправляйте JSON как `application/json`, кроме загрузки вложения: её точный multipart-запрос определён канонической OpenAPI-операцией `uploadTextAttachment`.
- Считайте отсутствие или изменение поля изменением контракта. Привязывайте сгенерированный клиент к проверенной ревизии `openapi.yaml` и сохраняйте неизвестные realtime-события для прямой совместимости.

## Аутентификация и владение сессией

Текущий API использует непрозрачные server-side sessions, выдаваемые как secure cookies. Для мобильных клиентов **нет контракта bearer-token, OAuth, device-code или API-key**.

1. Вызывайте `POST /api/v1/auth/register` только при открытой регистрации либо `POST /api/v1/auth/login` с каноническим телом запроса.
2. Сохраняйте возвращённую session cookie только в управляемом платформой безопасном cookie store публичного хоста. Никогда не сохраняйте пароль, reset token, LiveKit token или token в WebSocket URL.
3. Начинайте каждый запуск приложения с `GET /api/v1/auth/session`; трактуйте `401` как состояние без входа и очищайте platform cookie store при `POST /api/v1/auth/logout`.
4. Каждый изменяющий состояние запрос обязан пройти production-проверки secure-cookie, CSRF и Origin. Native origin/header поведение отдельно не определено текущим backend: не обходите эти проверки и не изобретайте header. Реализация mobile заблокирована до явного backend-решения об auth transport, если платформа не может им соответствовать.

`GET /api/v1/auth/session` возвращает только идентичность и роль текущего account. Для редактируемых данных используйте `GET /api/v1/me` и `PATCH /api/v1/me`: профиль всегда определяется текущей server-side session; `login` и `role` доступны только для чтения, а PATCH принимает только `display_name` длиной 1–64 Unicode-символа. `POST /api/v1/me/password` принимает текущий и новый пароли по 12–128 Unicode-символов; текущая session сохраняется, остальные отзываются вместе с их voice leases. `PUT`/`DELETE /api/v1/me/avatar` меняют только аватар вызывающего; загрузка принимает PNG/JPEG до 2 MiB, а нормализованные PNG доступны участникам с действующей session через URL из профиля/списка участников. Никогда не журналируйте пароли. Не выводите из ошибок или отсутствующих полей роль другого пользователя, block state, состояние пароля/сессии или membership в direct message.

## Карта REST-операций

Используйте именованный `operationId` из OpenAPI для методов сгенерированного клиента. Все защищённые маршруты применяют server-side ACL; идентификатор или кэшированный экран не дают доступа.

| Область | Операции мобильного клиента | Примечания |
| --- | --- | --- |
| Начальная загрузка | `getHealth`, `getMaintenanceAdmission`, `getCurrentSession` | `maintenance.active` управляет только новыми подключениями; это metadata, а не расписание выкладки. |
| Аутентификация | `register`, `login`, `logout`, `completePasswordReset` | Ссылки сброса пароля создаёт администратор; клиент не создаёт такую ссылку для себя. |
| Профиль | `getMe`, `updateMe`, `changePassword`, `uploadAvatar`, `deleteAvatar` | Профиль относится только к вызывающей session; логин не изменяется через UI. Аватары не являются публичными файлами. |
| Client update policy | `getClientUpdatePolicy` | Публичный metadata-only endpoint без session. Клиент передаёт точный platform/distribution/channel/arch selector, валидирует ответ, повторно проверяет policy непосредственно перед пользовательским действием и никогда не запускает установку автоматически. |
| Участники | `listMembers`, `getMember`, `getMemberAvatar` | Только активные аккаунты; стабильная UUID-пагинация и безопасная проекция login/display name/role/avatar URL/presence. Presence online означает хотя бы один активный authenticated realtime WebSocket; unknown не считать offline, Away отсутствует. |
| Каналы | `getChannelTopology`, `advanceTextChannelReadCursor` | Deployment содержит ровно одну гильдию. При admin-изменениях topology используйте `revision`. У каждого TEXT-канала `unread_count`, `mention_count` и необязательный `first_unread_message_id` относятся только к вызывающему аккаунту; после показа сообщения передавайте его ID в монотонный read cursor. У VOICE этих полей нет. |
| Разрешения и topology-команды | `getEffectivePermissions`, `createMemberCategory`, `createMemberChannel`, `deleteMemberCategory`, `archiveMemberTextChannel`, `closeMemberVoiceChannel`, `getTopologyCommand` | Загружайте шесть effective permissions при входе, foreground и permission hint. Сохраняйте UUID `client_request_id` до определённого результата; после потери ответа разрешено прочитать только собственную receipt. `403` требует обновить права, `409` — topology. |
| Текстовые сообщения | `listTextMessages`, `createTextMessage`, `searchTextMessages`, `editTextMessage`, `deleteTextMessage` | История и поиск — cursor-страницы от новых к старым. Удалённые строки сохраняют identity и marker, но не прежний текст. |
| Вложения | `uploadTextAttachment`, `downloadTextAttachment`, `previewTextAttachment`, `uploadDirectMessageAttachment`, `downloadDirectMessageAttachment`, `previewDirectMessageAttachment` | Загружайте файл только в выбранную доступную TEXT-беседу или собственный DM; attachment ID не обходит ACL. Связывайте до 10 ID в `createTextMessage` или `sendDirectMessage` по OpenAPI. Для DM история выдаёт только метаданные, а download/preview каждый раз перепроверяют участие в паре и живую связь. |
| Личные сообщения | `listDirectMessageCandidates`, `openDirectMessage`, `listDirectMessages`, `listDirectMessageHistory`, `searchDirectMessageHistory`, `sendDirectMessage`, `editDirectMessage`, `deleteDirectMessage`, `advanceDirectMessageReadCursor` | Direct message принадлежит только двум участникам. Роль администратора не даёт доступа к истории третьей стороны. `unread_count`, `mention_count` и необязательный `first_unread_message_id` всегда относятся к caller. |
| Общий поиск | `searchMessages` | Ищет по неудалённому тексту активных текстовых каналов и только собственных DM. `channel_id` или `direct_message_id` ограничивает текущую беседу; передавайте не более одного фильтра. Используйте непрозрачный `next_cursor` из ответа. |
| Голос и media | `listConnectedVoiceParticipants`, `watchConnectedVoiceParticipants`, `acquireVoiceLease`, `releaseVoiceLease`, `issueLiveKitCredential` | Roster reads доступны аутентифицированному незаблокированному участнику без voice lease и всегда повторно проходят серверную ACL-проверку. Используйте короткоживущий SSE snapshot stream для prejoin/live roster; webhook — только private backend invalidation signal. Участник включает `microphone_muted` и `screen_sharing`; speaking из roster не выводится. Voice media используйте по упорядоченному lifecycle ниже; это не универсальные LiveKit management API. |
| Администрирование | `listAdminAccounts`, `listAudit`, `listRolePolicies`, `updateMemberRolePolicy`, `createCategory`, `createChannel`, `reorderCategories`, `renameCategory`, `renameChannel`, `deleteEmptyCategory`, `moveChannel`, `reorderChannels`, `archiveTextChannel`, `closeVoiceChannelAdmission`, `updateAdminAccountState`, `kickVoiceParticipant`, `createPasswordResetLink` | Показывайте UI или вызывайте только для `ADMINISTRATOR`; всё равно обрабатывайте отказ. MEMBER policy заменяется полной картой шести ключей с revision; ADMINISTRATOR preset неизменяем. |

Для каждого endpoint используйте точные request/response-схемы и задокументированные status codes из `openapi.yaml`. Не создавайте mobile-only routes или поля.

## Правила сообщений, cursor и конфликтов

- Создавайте UUID `client_message_id` один раз для каждого нового text или direct message. Используйте его повторно только при retry той же логической отправки; не создавайте новый после неопределённого network outcome.
- Для create/archive/close/delete topology создавайте UUID `client_request_id` один раз на намерение. Не меняйте его при точном retry; изменение имени, типа, parent, revision или confirmation создаёт новый UUID.
- Отправляйте text body в канонических пределах `1…8000`. ID ответа должен оставаться в том же text channel или той же direct-message паре.
- Используйте `before` и `next_cursor` для страниц history/search. Там, где параметр определён, `limit` ограничен `1…100` и по умолчанию равен `50`.
- Редактируйте с последним `expected_revision`. При `409` обновите затронутую строку/страницу history перед предложением повторить действие; не перезаписывайте локально более новую revision.
- Передавайте упоминания как `mention_user_ids` (не более 100 уникальных UUID) в create/edit; при edit это полный новый набор. Для TEXT адресат должен быть активным участником одной гильдии, для DM — только вторым участником пары. Не выводите ID из текущего display name и не создавайте `@everyone`/`@here`; history возвращает стабильные ID, а удалённое сообщение — пустой массив.
- Удаление — soft deletion. Очистите локальный отображаемый текст, когда сервер вернёт deletion marker; не сохраняйте удалённый remote body в постоянном mobile cache.
- Продвигайте DM read cursor только для сообщения, видимо отрисованного в выбранной foreground conversation. Сервер перемещает его монотонно; retry не может сдвинуть cursor назад.

## Неопределённая доставка сообщения

При timeout/lost response сначала вызовите caller-only
`GET /api/v1/channels/{channelID}/message-delivery/{clientMessageID}` либо
`GET /api/v1/direct-messages/{directMessageID}/message-delivery/{clientMessageID}`.
Проверьте `account_id` ответа. Если `message_id` существует, загрузите историю
с `at=message_id` и подтвердите author/client UUID; повторный POST не нужен.
Удалённая серверная запись тоже подтверждает доставку и не должна воскресать.
При `message_id: null` пользователь может повторить точный payload с тем же UUID;
изменение payload создаёт новый UUID. Не повторяйте после 400/403/409/507 автоматически.
При недоступной проверке остаётся локальная неопределённость; отсутствие ответа
не доказывает отсутствие записи. Показывайте sending/checking/failed по беседам,
убирайте optimistic row локально без server DELETE и очищайте очередь при смене
аккаунта/сервера. Ограничение ожидания запроса — 20 секунд, после POST timeout
проверка также ограничена. Поздний commit согласуется по прежнему UUID.

## Собственные активные сеансы

`GET /api/v1/me/sessions` возвращает только сеансы владельца secure cookie:
публичный UUID, общую метку, даты входа/активности и отметку `current`.
Список не содержит cookie, digest, IP или fingerprint и не кэшируется.
Проверяйте `account_id` ответа перед отображением; при смене аккаунта или сервера
отбрасывайте незавершённые запросы и очищайте список.
`DELETE /api/v1/me/sessions/{sessionID}` завершает выбранный собственный сеанс;
`POST /api/v1/me/sessions/revoke-others` сохраняет сеанс инициатора.
Обе операции требуют доверенный Origin и `X-Account-ID` отображаемого владельца.
Заголовок защищает от устаревшего экрана, право доступа определяется cookie.
При `409 SESSION_ACCOUNT_CHANGED` не повторяйте действие для нового аккаунта.
Приватный пустой hint `session.state_changed` обновляет открытый список;
отозванный WebSocket закрывается, voice lease отзывается сервером.

## Realtime-контракт

Открывайте same-origin WebSocket на `GET /api/v1/realtime?capabilities=role_permissions_v1` только после установки cookie session. Capability не является credential и только разрешает новые permission hints; старый клиент без неё их не получает. Cookie аутентифицирует upgrade; никогда не добавляйте authentication token в URL, query, log или event payload.

Поддерживаемые значения `kind` определены в `realtime.schema.json`:

| Вид события | Действие мобильного клиента |
| --- | --- |
| `connection.ready` | Отметить realtime transport готовым после валидации event schema. |
| `connection.resync_required` | Обновить защищённую topology и активную видимую history через REST; не утверждать, что replay удался. |
| `presence.snapshot` | Полный список `online_user_ids` активных WebSocket-подключений гильдии; отсутствующий в snapshot участник offline только до следующего события/снимка. |
| `presence.changed` | Payload `user_id` и `presence` (`online`/`offline`); обновить только этот статус, не выводить его из роли или voice membership. |
| `voice.lease_revoked` | Адресное событие владельцу: `{lease_id, reason}`. Остановите только совпадающий локальный lease; reason объясняет transfer/kick/ban/logout/reset/закрытие канала. Событие не доказывает, что SFU уже завершил удаление участника. |
| `channel.updated` | Payload `{revision}` содержит новую ревизию topology; если она новее локальной, перечитать topology через авторизованный REST. Не считать событие заменой серверной ACL. |
| `role.permissions.updated` | Ephemeral payload `{role:"MEMBER",revision}`. Перечитать effective permissions; payload не является policy. |
| `auth.permissions.invalidated` | Адресная ephemeral подсказка с пустым payload после изменения роли/доступа. Перечитать session и effective permissions. |
| `message.created` | Payload содержит только UUID `channel_id` и `message_id`; перечитать историю через авторизованный REST только для уже выбранного текстового канала. Текст и DM через событие не передаются. |
| `message.updated` | Payload содержит только UUID `channel_id` и `message_id`; перечитать историю через авторизованный REST только для уже выбранного текстового канала. Текст и DM через событие не передаются. |
| `message.deleted` | Payload содержит только UUID `channel_id` и `message_id`; перечитать историю через авторизованный REST только для уже выбранного текстового канала. Текст и DM через событие не передаются. |
| `direct_message.message_created` | Payload содержит только UUID `direct_message_id` и `message_id`; обновить лишь собственный список DM и выбранную беседу через защищённый REST. Повторный send может дать ещё одну подсказку для того же message ID. |
| `direct_message.message_updated`, `direct_message.message_deleted` | Payload содержит только UUID `direct_message_id`, `message_id` и `revision`; перечитать доступную участнику историю и применить новую ревизию. Тело и preview не передаются. |

Дедуплицируйте по `event_id`, используйте `occurred_at` только как server event time и принимайте будущие event kinds, не считая их авторизацией. Realtime reconnect не создаёт новую session, новый Voice lease или новый LiveKit credential. Здоровый WebRTC call не должен закрываться только из-за reconnect этого WebSocket.

Для возобновления передайте `after=<event_id>` последнего **обработанного durable hint**. Это подтверждение обработки, а не credential; `connection.*`, `presence.*`, `role.permissions.updated` и `auth.permissions.invalidated` не подходят в качестве курсора. Сервер хранит журнал 7 дней, выдаёт не более 512 событий и повторно проверяет текущую session и ACL каждого события. Дубликаты после reconnect допустимы: дедуплицируйте по `event_id`, а DM также по message ID/revision после idempotent retry. При переполнении, истечении курсора, смене boot epoch или недоступности журнала сервер отправляет `connection.resync_required`; клиент перечитывает защищённые topology и видимую history через REST. DM-подсказки адресуются только двум текущим участникам пары и не заменяют REST-проверку доступа.

## Lifecycle Voice lease и LiveKit credential

1. Вызовите `POST /api/v1/voice/channels/{channelID}/leases` с `{"transfer": false}` для выбранного пользователем доступного для чтения `VOICE`-канала.
2. Если сервер вернул `409 ACTIVE_VOICE_LEASE`, покажите, что существует другое logical voice connection. Передавайте подключение только после явного намерения пользователя, повторив запрос с `{"transfer": true}`.
3. С возвращённым lease ID вызовите `POST /api/v1/voice/leases/{leaseID}/credential` непосредственно перед подключением к LiveKit.
4. Используйте возвращённые `url`, short-lived `token` и `expires_at` только в in-memory LiveKit client. **LiveKit credential** нельзя логировать, сохранять, помещать в deep link или отправлять в analytics.
5. Подключайтесь только к room, разрешённой этим credential. Backend, а не mobile client, владеет channel admission, проверками ban/logout, подписанием credential и SFU revocation.
6. При явном выходе вызовите `DELETE /api/v1/voice/leases/{leaseID}`; операция idempotent. При kick, logout, session invalidation или terminal SDK disconnect остановите local media и получайте новый lease только после явного действия пользователя.

Mobile client может публиковать microphone и screen-share media только если выданный credential это разрешает. Camera, recording, custom SFU, group DM, cross-guild voice и public LiveKit management не поддерживаются.

## Политика ошибок и retry

- Разбирайте канонический ответ `Error`, не раскрывая его содержимое analytics или logs, если оно может содержать пользовательские данные.
- `400`: исправьте локальный запрос; не делайте слепой retry.
- `401`: очистите защищённое локальное состояние и начните обычный sign-in flow.
- `403`/`404`: удалите или обновите недоступный resource; не различайте скрытые ACL-условия для пользователя подробнее безопасного server message.
- `409`: следуйте resource-specific flow выше (`ACTIVE_VOICE_LEASE`, stale revision или topology revision) и обновите состояние перед retry.
- `429`: соблюдайте `Retry-After`, когда он есть; не разветвляйте retries.
- `5xx` или transport loss: повторяйте только idempotent reads и запросы с исходным message idempotency key; применяйте exponential backoff с отменой при logout/background.

## Неподдерживаемые или намеренно отсутствующие контракты

- Native bearer/mobile auth transport пока не определён.
- Нет API для push-notification, presence, typing, global user search, server discovery, federation или cross-deployment взаимодействия.
- Этот документ не подразумевает camera, recording, group-DM, mobile UI, backup, snapshot или custom-SFU capability.
- Mobile telemetry не может содержать passwords, sessions, reset/media tokens, message bodies, attachment contents или высококардинальные account/DM identifiers.

## Диагностические user-flow traces v1

Каноническая схема: [telemetry-flow-v1.json](telemetry-flow-v1.json).
После authenticated restore/login сервер сообщает X-Telemetry-Schema=1 и
X-Telemetry-Session. Это не credential; cookie/Origin/ACL продолжают проверяться.
Visit создаётся на запуск, flow — на намерение, attempt растёт для точного retry.
Account/logout/origin boundary очищает очередь; старый callback не становится
событием следующего аккаунта. Preauth и postlogout наблюдения не экспортируются.
Передавайте диагностические HTTP/WS поля только собственному API origin;
не пересылайте baggage, cookies или LiveKit tokens ради корреляции.

Realtime telemetry envelope optional; он не меняет required бизнес-поля.
Ссылки причинности принимаются только с audience-bound server proof и текущим ACL.
Render/readiness/first_frame завершаются по наблюдению компонента, а не HTTP 200.
Производительность/звук/кадры требуют отдельного device evidence. Клиентские
health checkpoints также могут потеряться во время outage; absence означает unknown.

## Политика изменений

Mobile implementation обязан использовать проверенную ревизию OpenAPI/JSON Schema. Изменение endpoint method/path, required field, enum, authentication transport, ACL outcome, websocket event, LiveKit credential claim или error semantics требует согласованного изменения канонических contracts, этого руководства, contract verifier и release notes.

### Desktop install artifact extension (#337)

A native client update target may carry optional `install_artifact` without
changing existing `action` fallback semantics. The envelope binds exact decoded
`desktop-update-artifact.schema.json` bytes using Ed25519 with the domain
`BOOHTACORD-DESKTOP-ARTIFACT-v1` followed by a newline. Publisher roots are
embedded in the application, never supplied by the deployment. A successful
policy response or SHA256SUMS alone does not authorize executable installation.
Android/iOS/web retain their existing action handling. Desktop updater capability
must fail closed if native adapter/package trust or supported installation
location is unavailable. No command/script field is accepted.
