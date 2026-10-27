# Локальный QA-стенд BOOHTACORD

Стенд работает на этом ПК в Docker Desktop, контекст desktop-linux, namespace `boohtacord-local-qa`.
Исходники: `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.

- Приложение: http://localhost:18088
- Grafana: http://127.0.0.1:13000 — папка BOOHTACORD QA, шесть дашбордов.
- Prometheus: http://127.0.0.1:19091
- Tempo: http://127.0.0.1:13200
- PostgreSQL 17.6: 127.0.0.1:15436, база/пользователь boohtacord_qa.

Учётные данные: `C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD/.out/local-qa/credentials.private.json` (только локальный файл) рядом с этой инструкцией.
Для приложения используйте admin_login/admin_password; для Grafana — grafana_login/grafana_password.
qa_alpha и qa_beta — отдельные синтетические пользователи для повторяемых проверок.
Не переносите этот файл с credentials, runtime.private.env, compose.private.json, private-логи и пароли в GitHub.

## Управление

PowerShell, рабочий каталог: C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD.

```powershell
python -X utf8 .out/local-qa/manage.py status
python -X utf8 .out/local-qa/verify_deployment.py
node .out/local-qa/smoke_final.mjs
```

Браузерная проверка использует установленный Chrome и Playwright из соседнего android-qa worktree.
Частые повторные входы могут штатно получить 429; учитывайте Retry-After, не отключайте лимиты.

Остановка сохраняет именованные тома:

```powershell
python -X utf8 .out/local-qa/manage.py stop proxy web api livekit postgres collector tempo prometheus grafana
```

Запуск уже созданного стенда:

```powershell
python -X utf8 .out/local-qa/manage.py start postgres tempo collector livekit prometheus grafana api web proxy
python -X utf8 .out/local-qa/verify_deployment.py
```

После запуска дождитесь readiness компонентов. Перезапуск выбранного сервиса:

```powershell
python -X utf8 .out/local-qa/manage.py restart api
```

Не повторяйте infra, bootstrap или старый smoke_browser.mjs: это первичная инициализация.
Не архивируйте этот worktree: контейнеры используют его конфигурацию через bind mounts.
Удаление томов не входит в команды управления. Перезагрузка ПК не проверялась; контейнеры имеют
restart unless-stopped, но Docker Desktop должен быть запущен.

## Границы приёмки

Все опубликованные порты привязаны к loopback. БД, storage, учётные записи и ключи отдельные.
LiveKit объявляет 127.0.0.1; профиль предназначен для клиентов на этом ПК.
Сетевой bridge отдельный, но исходящий трафик Docker не блокируется политикой этого профиля.
Production URL, credentials и support provider в профиль не передавались.

HTTP localhost подходит для браузерного теста; production TLS и native Android приёмка требуют отдельных проверок.
Для телефона нужен отдельный проверенный профиль доступа; его production-сервер не перенастраивался.
Два SDK-клиента проверяются без микрофона. Слышимость, экран, нагрузка и capacity этим тестом не проверяются.
Отказы, давление на диск, нагрузка, rollback и alert delivery остаются отдельными NOT_RUN/BLOCKED сценариями
до выполнения точного протокола. Issue #240/#241/#272 остаются открытыми.

Evidence: deployment-readiness.json, browser-final-smoke.json, voice-smoke.json,
profile-receipt.json, dashboard-bindings.json и screenshots в этой папке.
Публичная обезличенная копия: evidence/qa/open-issues-2026-10-27/local-staging в соседнем android-qa worktree.
