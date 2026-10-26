# Подписанные server releases

## Обычная поставка

1. GitHub `master` запускает [Build server](../../.github/workflows/build-server.yaml).
   Backend, web и contracts формируют PASS receipts для того же полного SHA.
2. GitHub-hosted Linux bundle job создаёт OCI archives, SBOM/provenance и smoke-проверяет
   собранные API/web images. Подписанный bundle сохраняется в Actions 30 дней.
3. [Deploy production](../../.github/workflows/deploy-production.yaml) проверяет
   происхождение producer run и устанавливает именно его artifact.

Production environment разрешает только `master`. Его секрет
`RELEASE_SIGNING_PRIVATE_KEY` доступен только GitHub-hosted bundle job;
`DEPLOY_SSH_PRIVATE_KEY` — установщику. Public trust anchor заранее находится на host:
`/etc/voice-platform/release-signing.pub.pem`. Полученный bundle не может
назначить собственный ключ доверия. Staging имеет отдельную пару ключей.

Для проверки retained source bundle builder принимает `--source /path/to/repo`:
это должен быть корень чистого Git checkout, а PASS receipts должны относиться
к его точному `HEAD`. Без параметра собирается репозиторий самого builder.
Smoke ожидает готовности PostgreSQL по TCP перед двумя проходами миграций.

Bundle job uses the repository's pinned `ubuntu-24.04` image. It does not depend
on a persistent builder account or Docker socket on the production host. Its
exact-source receipts, production environment guard and non-cancellable build
queue remain required.

Host prerequisites: Python 3, OpenSSL, Docker с OCI storage, Compose, Bash и
действующий `.env` в `/opt/voice-platform/.env`. Install не загружает SDK,
не компилирует исходники и не пересобирает images.

## Повторная установка сохранённого artifact

Запустите [Install retained release](../../.github/workflows/install-retained-release.yaml)
на `master`, указав успешный Build server run ID и его полный SHA. Workflow
проверит соответствие run/revision и точный checksum; новый build не запускается.

Нативные команды для контролируемого стенда (из checkout этой же ревизии):

```sh
task release:verify -- BUNDLE_DIRECTORY FULL_SHA --public-key PUBLIC_KEY
task release:install -- BUNDLE_ARCHIVE FULL_SHA SHA256 --public-key PUBLIC_KEY --expected-current-revision CURRENT_SHA
```

Опции `--release-root` и `--environment` выбирают изолированный контур. На
production используйте workflow с общей очередью установки, а не параллельную
ручную команду. Host `.install.lock` дополнительно сериализует операции.

Передача release bundle ограничена 15 минутами: при медленном SSH-маршруте
85 MB могут не успеть за прежние 5 минут. Общий job остаётся ограничен
30 минутами; лимиты установки и свежего readback не расширяются. После
таймаута передачи installer не запускается. Для повторной доставки используйте
тот же успешный Build server run ID и SHA через `Install retained release`.

## Совместимый откат

Откат использует два уже сохранённых подписанных выпуска. Backend tree,
contracts, migrations и deployment topology должны совпадать. Это допускает
возврат совместимого web-выпуска и запрещает неявные обратные миграции.

```sh
task release:rollback -- CURRENT_SHA PREVIOUS_SHA --rehearse
```

`--rehearse` возвращает текущий выпуск после проверки; без флага предыдущий
остаётся рабочим. [Workflow rehearsal](../../.github/workflows/rehearse-compatible-rollback.yaml)
использует ту же production queue. Данные и volumes не удаляются и не восстанавливаются.

При несовпадении подписи, checksum, receipt SHA, running digest, migration
inventory или нехватке диска установка останавливается. После успешной проверки
пишется `installed.json` в `/opt/voice-platform-releases/FULL_SHA`.
Записывайте SHA, artifact digest, run ID, окружение и ограничения в evidence.
Physical media acceptance остаётся отдельной проверкой.

## Локальная репетиция с двумя браузерами

[Раннер QA-12](../../tools/qa/compatible_rollback/README.md) собирает две
совместимые подписанные QA-поставки и выполняет эту же команду rollback на
отдельном Docker-демоне. Два браузера наблюдают maintenance и отказы новым
входам/voice admissions; после отката и возврата проверяются сессии, данные,
вложения, schema и идентичность persistent resources. Его отдельный временный
ключ предназначен для тестового контура. Прогон не меняет production trust anchor
и не выполняет production maintenance.

## Ротация локальных артефактов

На host работает [release artifact rotation](../../tools/ops/release_rotation/README.md):
каждые 15 минут сохраняет последние 10 подписанных выпусков, текущую версию,
предыдущую из успешного readback и используемые контейнерами версии. У старых
выпусков удаляет OCI archives и только их неиспользуемые image references;
metadata и runtime остаются. Общая `.install.lock` исключает пересечение с
install/rollback. Timer устанавливается отдельно от приложения и не зависит
от успешного следующего деплоя. Старые удалённые bundles следует получать
через обычный подписанный delivery workflow, а не обходить проверку целостности.
