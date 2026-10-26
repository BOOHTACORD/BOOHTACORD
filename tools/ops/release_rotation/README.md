# Ротация server artifacts — T-054

Host-owned systemd timer запускается каждые 15 минут. Он использует тот же
`/opt/voice-platform-releases/.install.lock`, что install/rollback; при занятом
lock ничего не удаляет и возвращает `SKIPPED_BUSY`.

Сохраняются десять последних подписанных выпусков по времени `manifest.json`,
текущий источник API/web, `previous_source_revision` из успешного deployment
readback и любые версии, связанные с контейнерами или их bind mounts.
При отсутствии достоверной текущей/предыдущей версии, подписи или обоих
архивов у сохраняемых версий очистка прекращается до удаления.

У остальных подписанных выпусков удаляются только `api.oci.tar` и `web.oci.tar`.
Манифесты, подписи, receipts, runtime, конфигурация и история остаются на месте.
Время манифеста не меняется при очистке, поэтому старый выпуск не становится
«новейшим» после удаления архива. Старый выпуск после ротации не считается
готовым к локальному reinstall/rollback: bundle нужно получить заново через
обычный проверяемый delivery workflow.

Из Docker удаляются только точные `voice-platform-{api,web}@sha256:...` ссылки
из подписанных устаревших манифестов. Сохраняются digest/ID всех оставляемых
версий и image ID любого контейнера, включая остановленные. Перед каждой
операцией ссылки контейнеров проверяются снова; `docker image rm --no-prune`
работает без `--force`. Произвольного image/system/volume/container prune нет.
Неиспользуемый build cache старше семи дней очищается штатным Docker builder
prune с целевым остатком 2 GB; свежий/активный cache этим правилом не удаляется.

Данные приложения, тома, контейнеры и сервисы не удаляются и не перезапускаются.
Ротация проверяет общую файловую систему и тот же attachment reserve:
`2 × max(2 GiB, ceil(total/10)) + 25 MB`. Неизменность контейнеров проверяется
после очистки. Рост пользовательских данных и чужих процессов этим правилом
не ограничивается; гарантировать отсутствие любого disk-full нельзя.

## Установка и проверка

После проверки изменений запустить на production-хосте из checkout:

```sh
sudo bash tools/ops/release_rotation/install-host.sh
systemctl start boohtacord-release-rotation.service
systemctl list-timers boohtacord-release-rotation.timer
journalctl -u boohtacord-release-rotation.service -n 10 -o cat
```

`install-host.sh` устанавливает root-owned версию инструмента, выполняет dry-run
и только затем включает timer. Приложение при этом не разворачивается.
`python3 -m tools.ops.release_rotation.run` по умолчанию только выводит план;
для удаления нужен `--apply`. В журнал попадает один JSON receipt со счётчиками,
source SHA, свободным местом и фиксированным статусом, без содержимого данных.

```sh
python3 -m unittest tools.ops.release_rotation.test_rotation -v
```
