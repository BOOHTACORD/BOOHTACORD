# Bootstrap и recovery администратора

Настройки гильдии, welcome и диагностика регистрации описаны в
[Guild lifecycle](guild-lifecycle.md).

## Настройка разрешений участников

Откройте **Администрирование → Роли → Пользователь**. Редактор содержит ровно шесть разрешений создания и удаления TEXT, VOICE и категорий. **По умолчанию** меняет локальный черновик; **Отмена** возвращает последнюю загруженную policy; сервер меняется только после **Сохранить**. Включение любого права удаления требует отдельного подтверждения и действует на все подходящие каналы одной гильдии. Роль администратора показывает неизменяемый полный preset.

При конфликте revision сохраните смысл черновика, нажмите **Обновить**, сравните актуальную policy и повторите осознанное изменение. Capability-aware клиенты получают refresh hint; polling и foreground refresh восстанавливают состояние при его потере. Backend проверяет право в каждой операции.

Пользователь создаёт категорию или канал через глобальный `+` либо `+` раздела. Удаление вызывается через `⋯`, ПКМ или touch menu и подтверждает конкретный объект. TEXT исчезает из навигации с сохранением истории, пустая категория удаляется без каскада, VOICE остаётся `CLOSING` до подтверждённой сервером финализации.

Команды ниже относятся к установленному подписанному выпуску. С trusted
checkout на host сначала определите текущую ревизию:

```sh
revision="$(sudo bash tools/release/delivery/current_revision.sh)"
release="/opt/voice-platform-releases/$revision"
```

Compose и runtime environment берутся именно из этого сохранённого выпуска.

Запускайте migrations до любой recovery command. Ни одна command не принимает password как command-line flag. Выполняйте эти one-shot commands в terminal владельца сервера; передавайте password через standard input, чтобы process arguments, application logs и Compose files не содержали secret.

Выполните bootstrap первого администратора до открытия регистрации:

```bash
read -rsp 'Initial administrator password: ' BOOTSTRAP_PASSWORD; echo
printf '%s\n' "$BOOTSTRAP_PASSWORD" | sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm -T bootstrap-admin --login owner --password-stdin
unset BOOTSTRAP_PASSWORD
```

Первый успешный bootstrap создаёт `ADMINISTRATOR` и audit event. Любой последующий bootstrap успешно завершается с сообщением «already initialized» и не меняет ни role, ни password.

Если command сообщает о неполном bootstrap state, не повторяйте её, не используйте administrator recovery и не создавайте account напрямую в PostgreSQL. Сначала deploy current repair migration: она связывает только singleton state без administrator с ровно одним существующим active administrator и записывает отсутствующий initial-bootstrap audit event. State, не соответствующий этим точным условиям, остаётся неизменным для investigation владельцем.

Emergency recovery доступен только при отсутствии active administrator. Он восстанавливает существующий account как unblocked `ADMINISTRATOR`, заменяет его password, отзывает прежние sessions и создаёт audit event `ADMINISTRATOR_RECOVERED`:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm -T recover-admin --login owner --password-stdin
unset RECOVERY_PASSWORD
```

Если единственный active administrator утратил password, используйте отдельную command ниже с явным acknowledgement. Она работает только когда `owner` — единственный active, unblocked `ADMINISTRATOR`; она не повышает другой account и не меняет role. Command заменяет password, отзывает active sessions и voice leases account и создаёт `LAST_ADMINISTRATOR_ACCESS_RECOVERED`:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm -T recover-last-admin-access --login owner --password-stdin --confirm-sole-active-administrator-access-recovery
unset RECOVERY_PASSWORD
```

Владелец сервера обязан передавать password через controlled channel. Эти owner-operated commands не предоставляют backup, account discovery или обычный administration workflow.

## Входные параметры GitHub Actions

### GitHub-hosted CI и release workflows

Все jobs в репозиторных workflows запускаются на GitHub-hosted образах: Linux — `ubuntu-24.04`, Windows — `windows-2022`, macOS — `macos-26` и явный `macos-26-intel` для соответствующей матрицы. Регистрировать self-hosted runners для workflow не нужно. Оставшиеся службы старого Hetzner CI pool описаны в отдельном legacy runbook и не останавливаются изменением `runs-on`.

`deploy-production.yaml` запускается после успешного trusted Build server run на `master`. Для установки требуется GitHub environment `production` с owner-controlled защитой и секрет `DEPLOY_SSH_PRIVATE_KEY`, соответствующий `authorized_keys` пользователя `shaneque` на утверждённом production-хосте `176.108.242.211`. PostgreSQL, LiveKit и `.env` остаются приватными на сервере.

Linux bundle job собирает и проверяет OCI artifacts на `ubuntu-24.04`; production host получает только проверенный retained bundle по SSH. Windows и macOS release workflows используют соответствующие GitHub-hosted платформы. Подписанные releases по-прежнему требуют настройки существующих `BOOHTACORD_ANDROID_*` и других release secrets в защищённых GitHub environments и запуска из разрешённых тегов или `master`; отдельный `RELEASE_API_KEY` не нужен.

Workflow закрепляет проверенный ED25519 host key deployment-сервера в `known_hosts`; он не использует `ssh-keyscan`, `StrictHostKeyChecking=accept-new` или интерактивный SSH. Изменение host key намеренно останавливает поставку до отдельной owner-проверки и обновления workflow.

Сервер не обязан быть Git-клоном и не получает registry credential. Pipeline тестирует точный checkout, передаёт `.env`-free source archive, проверяет его SHA-256 и распаковывает в `/opt/voice-platform-releases/<commit-sha>`, сохраняя server-local `.env` с правами `0600`. API и web собираются в локальные OCI-архивы с индексными digest, SPDX SBOM и SLSA provenance; Compose запускает совместимую пару `name@sha256`. Связь source revision → build → digest → running image проверяет [QA-11 evidence](../../evidence/release/qa11-gitverse-oci-2026-09-26-001.json). `latest` и смешение ревизий запрещены.

После сборки workflow вызывает guard script с `VOICE_PLATFORM_DIR` нового release directory. Guard включает maintenance, запускает миграции, переключает только API/web/proxy и проверяет Caddy, сети, digest запущенных образов и public health; volumes PostgreSQL, attachments, LiveKit и Caddy не удаляются. Каталоги прошлых releases не удаляются автоматически: их очистка требует отдельного решения владельца.

## Maintenance admission во время trusted release

Release script включает maintenance admission, ждёт 15 секунд, чтобы предупреждение дошло до browsers, проверяет digest-qualified локальные OCI images, запускает миграции, переключает API/web/proxy и проверяет public health. Он отключает admission только после успешного health check. Неудачный release оставляет admission active; исследуйте и восстановите deployment до его отключения. Совместимый live rollback с проверкой идентичности volumes остаётся отдельным QA-12, а не следствием успешной поставки.

Первый release, добавляющий эту capability, требует одноразовой schema preparation, потому что его admission row ещё не существует. Подтвердите, что candidate migration — единственная ожидающая compatible migration, выполните её отдельным проверенным шагом, затем запустите normal release script. Не утверждайте, что эта одноразовая preparation была защищена maintenance; каждый дальнейший release использует normal sequence enable-before-pull.

Для controlled verification используйте второй browser как observer. Во время warning подтвердите, что новая registration, login и voice lease получают maintenance refusal, тогда как существующая session продолжает читать protected data, а существующее media connection не отключается намеренно до restart. После успешного health и отключения admission обновите оба browser и подтвердите, что banner исчез, а новые admissions снова доступны. Фиксируйте только image digests, UTC times и pass/fail outcomes — никогда не cookies, passwords, media credentials, private keys или host fingerprints.

## Очистка устаревшего staging

Следующая явная owner-operated command удаляет только прямые regular files `staging/upload-*.part`, строго старше одного часа:

```bash
sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm cleanup-stale-staging
```

Она сохраняет symlinks, directories, unexpected names, данные ровно на one-hour cutoff, опубликованные attachments, unattached objects и все database rows. Она намеренно не scheduled и запускается только после решения владельца о допустимости удаления. Её output сообщает только aggregate count; имена и contents attachments не раскрываются.

## Очистка старых unattached-вложений

Отдельная команда обрабатывает не более 100 объектов за запуск и только `UNATTACHED` старше 24 часов. Перед удалением файл получает retryable состояние `DELETING`; живые связи TEXT и DM защищены транзакционной проверкой. Ошибка unlink или БД оставляет запись для повторной попытки с долговечным интервалом 5–60 минут; свежие и повторные кандидаты чередуются, чтобы сбойные файлы не блокировали всю очередь. Audit содержит только агрегаты:

```bash
sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm cleanup-unattached-attachments --limit=100
```

Для редкого файла, перемещённого из staging до сбоя записи metadata, оператор может указать ровно один известный UUID storage key через `--orphan-key=<uuid>`. Команда удалит его только если это regular file старше 24 часов и записи БД для ключа нет. Она не обходит каталог автоматически и не удаляет опубликованную историю по возрасту. `Claimed: 0` во время backoff не доказывает отсутствие ожидающих повторов; после ошибок запускайте команду вновь после истечения интервала. Перед запуском проверьте текущие `DATABASE_URL` и `ATTACHMENTS_DIRECTORY` для этого deployment; содержимое файлов и идентификаторы вложений не выводите в общий журнал.

## Очистка вложений скрытых сообщений

После soft delete TEXT или DM отдельная команда удаляет файл только тогда, когда у вложения нет ни одной живой связи. Транзакционный claim защищает от конкурентного запуска; удаление связей, metadata и запись metadata-only audit совершаются одной транзакцией после unlink. Ошибка файла или БД оставляет `HIDDEN` объект для безопасного повторного запуска после истечения пятиминутного claim. Возраст опубликованной истории не является основанием для удаления.

```bash
sudo docker compose --project-directory "$release/deploy" --env-file "$release/.env" -f "$release/deploy/compose.yaml" --profile operator run --rm cleanup-hidden-attachments --limit=100
```

Повторяйте ограниченный запуск, проверяя `retryable failures` после каждого прохода. После такой ошибки claim сохраняется на пять минут, а следующая попытка сначала обрабатывает ещё не проверенные файлы; `Claimed: 0` во время активной lease не доказывает полного завершения. Повторите запуск после истечения lease. Значение `--limit` допускает 1…100; команда не раскрывает имена файлов, содержимое или ID сообщений.

## Проверка места для вложений

На deployment host определите точный путь тома командой `sudo docker volume inspect voice-platform_attachments-data --format '{{.Mountpoint}}'`. Для полученного пути выполните read-only `df -B1 <mountpoint>` и `findmnt -T <mountpoint>`; не подменяйте его измерением другого filesystem. Приватный API `/metrics` выводит `voice_platform_attachment_filesystem_available_bytes`, `voice_platform_attachment_filesystem_total_bytes` и после rollout BE-15 — `voice_platform_attachment_upload_reserved_bytes`. Перед новым upload требуется доступное место не менее `max(2 GiB, ceil(total/10)) + reserved + 25 000 000` байт. Если порог не выполнен, сохраните отказ HTTP 507 и увеличьте доступное место на этом filesystem. Опубликованную историю не удаляйте ради освобождения места.

Для оценки fan-out списка голосовых участников приватный `/metrics` выводит `voice_platform_voice_roster_snapshots_total{outcome}`, `voice_platform_voice_roster_snapshot_seconds`, `voice_platform_voice_roster_requested_rooms` и `voice_platform_voice_roster_failures_total{stage}`. Failure stages ограничены `visibility_initial`, `presence_snapshot` и `visibility_recheck`; метрика не записывает текст ошибок или account/channel/room/lease ID и помогает отличить ACL/PostgreSQL ошибки от недоступности LiveKit presence. Снимайте rate, latency и HTTP p95 при 1/20/100 одновременных клиентах на одном candidate до решения о single-flight или коротком metadata-кэше.
