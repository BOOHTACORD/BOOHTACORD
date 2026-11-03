# ADR-011: GitHub `master` — маршрут CI и production-доставки

- Статус: принят владельцем 30.09.2026; заменяет ADR-010 для будущих запусков
- Связанные задачи: T-054, QA-11, QA-12, QA-14; REQ-DEPLOY-01

## Контекст

Владелец создал `github.com/BOOHTACORD/BOOHTACORD` и потребовал перенести репозиторий, runners и инфраструктуру с GitVerse. До миграции GitVerse `master` имел доверенный deploy run #1653749 с проверенными локальными OCI digest, SBOM, provenance и health. Это историческое доказательство прежнего маршрута; оно не подтверждает новый GitHub run.

## Решение

GitHub `master` становится единственным source и автоматическим production writer. `.github/workflows/deploy-production.yaml` сохраняет обязательные backend/PostgreSQL, frontend и release-guard jobs перед SSH-доставкой точного source archive. Сервер продолжает собирать локальные OCI-образы, фиксировать digest/SBOM/provenance и проверять running images и health. `.github/workflows/ci.yaml` публикует GHCR-образы по SHA после CI, но не запускает второй deploy. Переход production на pull образов из GHCR потребует отдельного проверенного изменения release scripts и evidence; опубликованный GHCR digest сам по себе не является развернутым образом.

GitHub release workflows публикуют Android и macOS assets с `GITHUB_TOKEN` и `contents: write`. GitVerse workflows удалены. Self-hosted Linux и Windows runners должны быть зарегистрированы именно в новом GitHub-репозитории с метками, указанными в workflows. Не переносить registration token или секреты через Git.

GitHub не принимает 14 исторических Git-объектов APK размером 107–108 МБ. Для нового remote история `master` и release tags переписывается только с исключением `artifacts/android/*.apk`; остальные файлы и последовательность изменений сохраняются. Старые commit SHA и теги в GitVerse остаются доступными там, но соответствующие GitHub commit SHA изменятся. Подписанные APK остаются в исторических GitVerse Releases; новые публикуются в GitHub Releases. `artifacts/android/*.apk` добавлен в `.gitignore`.

`production` environment и `DEPLOY_SSH_PRIVATE_KEY` должны быть настроены в GitHub до первого production run. До завершения регистрации runners, переноса secrets и доверенного GitHub run статус нового delivery route остаётся **NOT_RUN**. Исторический QA-11 PASS сохраняется только как результат GitVerse; QA-12, QA-14 и аппаратные/нагрузочные gates остаются отдельными.

## Проверка

Локальные workflow/source tests и native release guards проверяют конфигурацию и fail-closed поведение. Для подтверждения работающей миграции нужен GitHub run на `master` с зелёными обязательными jobs, artifact digests и post-rollout smoke/evidence. Один только push исходников не закрывает этот пункт.
