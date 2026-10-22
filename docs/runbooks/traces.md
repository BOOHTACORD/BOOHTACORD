# Разбор пользовательской проблемы в Traces

Откройте [BOOHTACORD | Traces](https://grafana.fa.shaneque.ru/d/boohtacord-traces/boohtacord-7c-traces?orgId=1).
UID остаётся `boohtacord-traces`, org=1. Фильтры помогают искать, но не заменяют
ACL Grafana/Tempo. Не публикуйте snapshots, имена или диагностические ID.

## Найти действие и причину

1. Выберите время, пользователя, затем session → visit → flow/media. Старые ссылки
   `var-user`/`var-session` сохраняются. После изменения родительского фильтра
   проверьте зависимые значения; сбросьте недоступное значение в All. All включает
   legacy-записи без новых атрибутов; конкретный visit не может восстановить
   отсутствовавшую историческую корреляцию.
2. Начните с истории действий: operation, flow, attempt, stage, outcome, reason.
   Платформа клиента и producer service — разные фильтры: API может экспортировать
   измерение Web/Flutter. Client version и API service version также различаются.
3. Откройте trace выбранной попытки. Start/checkpoints — дочерние spans root-terminal
   этой попытки. Retry сохраняет flow ID, увеличивает attempt и имеет другой trace.
   Связанные traces/worker attempts открываются отдельно по links/flow. Совпадение
   flow ID не создаёт cross-trace waterfall и не доказывает причинность само по себе.
4. `failed`, `timeout`, `rejected`, `cancelled`, `superseded` — разные результаты.
   Отсутствие terminal/root — **неполное наблюдение**, а не доказанный сбой/успех:
   учитывайте окно поиска, поздний span, sampling, retention и лимит выборки.
5. Для HTTP возьмите серверный `X-Request-ID` и найдите `span.request_id` в Tempo
   или локальный безопасный access event. Cookie/токен/URL/query/body не нужны.
   Ошибка до login ищется в отдельной технической истории без фиктивного user.id.

История — ограниченная sampled-выборка (лимиты указаны на панели), не полный
аудитный журнал и не источник точных counters/SLO. Короткое действие с одним span
валидно. Для частоты/ошибок/p95 используйте aggregate metrics; WebSocket/SSE
request duration — время соединения, а не задержка handshake.

## Техническая история и media

Служебные HTTP, heartbeat/polling, raw media и legacy находятся в свёрнутых
технических разделах. Успешный unscoped presence GET/PUT не экспортируется как
клиентское действие. Серверные count/latency остаются; ошибки, stop и реальные
переходы состояния сохраняются. Native успешный auth/session poll также исключён
из spans; operational aggregates и его ошибки остаются.

Для просмотра экрана выберите viewer/session/visit/media, проверьте stage
`subscribe` → `track`/`decoded` → **first presented frame**. HTTP ack, connected
и подписка не доказывают предъявление кадра или слышимость. Message send success
после sender render не является receiver read receipt. Переключение fullscreen/mini
не означает новую media session. При неподдерживаемом сопоставлении нескольких
публикаций используйте конкретный trace и ограничение корреляции на панели.

`app.media.*` — flow schema, `media.*` — legacy API report; не складывайте их.
`app.media.bitrate_bps` имеет bit/s; legacy `media.bitrate_kbps` — kbit/s.
RTT/jitter/first-frame — ms; metric freshness в seconds. Проверяйте direction,
provenance, source, sample age/window/generation и время самой записи. Requested
profile, capture settings, encoded/decoded/presented FPS — разные слои. Target FPS
не заменяет измеренный FPS; неподвижный экран может давать меньше новых кадров.
Отсутствующее/stale/unknown не является нулём или healthy. Историческая последняя
строка не доказывает, что пользователь сейчас подключён. Показатели клиента не
являются измерением мощности оборудования или end-to-end latency.

## Отличить отсутствие telemetry от продуктового сбоя

Проверьте последовательно producer queue/dropped/retried → relay accepted/rejected
и receipt age **по источнику** → Collector refused/failed/queue/send → Tempo
доступность и query конкретного synthetic trace. Relay 202/last_accept доказывает
приём batch, а не хранение в Tempo. Исправный другой источник не должен скрывать
отказ выбранного. `up` означает только доступность scrape target; отсутствие
серии/активности и ошибка datasource — разные состояния. Не подставляйте zero.

Клиентская очередь 128, batch16, timeout3s, retry≤2; server SDK queue128/batch16,
export timeout3s; Collector queue128,2 consumers,retry horizon30s. Фактические
версии/конфиги и runtime результаты фиксируются отдельно в evidence. При outage
сама клиентская диагностика может теряться; продукт не ждёт её экспорта.
Head sampling может исключить всё действие вместе с ошибкой: обещания «все ошибки
сохраняются» нет. Web `VITE_TRACE_SAMPLE_RATIO`, Flutter `TRACE_SAMPLE_RATIO`,
server `OTEL_TRACES_SAMPLER`/`OTEL_TRACES_SAMPLER_ARG`; для изолированного pilot=1.

[Каталог сигналов](../observability/signal-catalog.json) связывает producer/hash,
сценарий, имя до/после экспорта, type/unit/labels, частоту, store, consumers и
решение. Native `voice_platform_*` private collectors не становятся OTLP сами.
Не суммируйте native scrape и mirror одного наблюдения. Каталог — source contract;
факт доставки после relay/Collector и final SHA подтверждает отдельное evidence.

## Проверка и безопасная поставка

```sh
python -m tools.observability.signal_catalog.build --check
python -m unittest tools.observability.signal_catalog.test_build tools.verify.trace_dashboard.test_traces_dashboard tools.verify.trace_dashboard.test_flow_dashboard
python tools/qa/trace_queries/check_trace_queries.py http://127.0.0.1:13200 docker/observability/dashboards/traces.json
```

[Изолированный runtime/fault harness](../../tools/qa/tracing_flow/README.md)
проверяет реальный SDK → sanitizing relay → Collector → Tempo. Его synthetic
principal и Flutter test engine не доказывают production cookie/native device
или физическую media-приёмку. Для клиентских изменений используйте также
`tools/qa/local_features/check.sh --feature telemetry --base <base> --real-stack`.

Перед поставкой прочитайте **действующий** JSON/version/resourceVersion/generation,
org, datasource UID и provisioning source; сохраните исходный JSON в закрытом
рабочем каталоге для возврата. Сверьте с Git и свежим чтением перед записью;
при конкурентном изменении остановите перезапись и согласуйте diff. Доставляйте
version-controlled source через существующий provisioning, тот же UID/org и
приватные `boohtacord_tempo`/`boohtacord_metrics`. ACL не меняются.

После записи перечитайте действующий UID/org, сравните содержимое с Git; проверьте
15m/6h/24h, All/конкретный user/session/visit, старую ссылку, пустую выборку,
multiselect/escaping, refresh, trace drill-down и технические разделы. Зафиксируйте
query latency/limits, версии и очищенный screenshot. JSON lint не заменяет smoke.

Rollback: проверьте отсутствие нового конкурентного изменения, верните сохранённый
предыдущий JSON тем же provisioning/API с текущим optimistic version token,
перечитайте тот же UID/org и проверьте прежние queries. Затем повторно доставьте
кандидат и выполните readback/smoke. Не удаляйте данные Tempo или схемы БД.
Production publish/readback/rollback получают отдельные PASS/FAIL/NOT_RUN; без
доступа к окружению задача не считается полностью выполненной.

### Отдельный monitor host

Если Collector/Tempo/Prometheus работают отдельно от API/LiveKit, используйте
версионный overlay, а не host-local SFU network из основного Compose:

```sh
docker compose -f docker/observability/compose.yaml -f docker/observability/compose.remote.yaml config
```

Compose ≥2.24.4 нужен для `!override`. При доставке сохраните текущие project name
и data-volume names; overlay сохраняет image pins, loopback-only ports, limits и
retention базового файла. Он заменяет только Prometheus mounts/network и удаляет
требование внешней Docker network приложения. Используйте ту же пару файлов при
применении; перед запуском сравните rendered config с read-only baseline.

`prometheus.remote.yaml` опрашивает только application OTLP exporter `collector:8889`,
Collector self `collector:8888`, Tempo и Prometheus. Arbitrary OTLP resource metadata
не переносится через `target_info`/`otel_scope_info`. API `/metrics` и LiveKit на
другом хосте **не опрашиваются**; неподдерживаемые SFU/API alert rules не монтируются.
Частные native collectors остаются частными; их отсутствие в этом Prometheus не
заменяется OTLP автоматически или нулевыми рядами. Базовые alert files для других
поддержанных топологий не удаляются.

Эта поставка не включает новую central installation/gateway consent из #336 и
не меняет режим `local_only`. Если fresh spans отсутствовали в baseline или API
не отправляет OTLP в этот monitor, новая конфигурация не создаёт исторические
данные задним числом. Fresh synthetic stored trace, старые retained series,
no-activity, disabled exporter и datasource failure фиксируются отдельно.
