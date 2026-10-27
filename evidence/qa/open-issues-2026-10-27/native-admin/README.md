# Физический Android: навигация и Back в админке

Production `https://v.bootybay.ru`; Samsung SM-A576B, Android16,
1080×2340/density450. Подписанный1.0.47+2082/source072426d6:
установленный APK SHA256 повторно совпал с проверенным кандидатом.
API source UNKNOWN. UTC каждого действия сохранён в receipts.

| Что защищает | Команда/действие | Платформа | Когда обязательно | Где результат |
|---|---|---|---|---|
| Доступность семи разделов при1.0/1.3/2.0 и sampled44dp targets | `python -X utf8 .out/qa-android-admin/admin_navigation.py`; observed горизонтальные swipes | Физический Android2082 | Перед приёмкой соответствующих частей I287.C14/I303.C2/C3 | `navigation-result.json`,21 PNG, `visual-review.json` |
| Back скрывает IME без потери локального поиска | `python -X utf8 .out/qa-android-admin/admin_followup.py` | Физический Android, font1.0 | Перед принятием admin IME/Back | `followup-attempt1.json#/IME_cases/0`: scoped PASS |
| Back отменяет popup без изменения роли и закрывает админку в исходный DM | `python -X utf8 .out/qa-android-admin/admin_back.py` | Физический Android, font1.0 | Перед принятием этих native Back переходов | `Back-result.json`: scoped PASS; точный focus return NOT_PROVEN |
| Ввод/Back при2.0 доказан точным собственным запросом | `admin_followup.py`, затем `admin_ime_retry.py`, `admin_ime_attempt3.py` | Физический Android, font2.0 | Перед large-text IME acceptance | FAIL_OR_CONTROLLER receipts; приёмка NOT_RUN, не PASS |

Runner sources сохранены как `runner-source/*.py.txt`; зависимости —
`../runner-source/native_sender_phone_common.py.txt` и
`../runner-source/android_permission_ui.py.txt`. Для воспроизведения восстановить
имена `.py` в исходном `.out` layout из import paths; private fixture содержит
только уже разрешённый собственный QA peer. Не публиковать fixture или native
cookies. Не запускать helpers с неизвестным непустым composer/фильтром.
`before.json` — исходное состояние, не перезаписывать при повторе.

Исходный сценарий: пустой собственный DM, действующая SHARE_TEST voice/mic80,
font1.0. `admin_entry.py` открыл наблюдённые «Настройки аккаунта» →
«Администрирование». Семантический selected подтверждён после каждого из21
переходов. CRUD/Save/Delete/role-change/logout/server switch не выполнялись.
Наличие admin menu/panel не заменяет серверную ACL-приёмку.

Все25 PNG просмотрены в исходном разрешении. Снимки содержат только статичный
заголовок и вкладки, исключают участников, историю, содержимое панелей и voice
dock. При2.0 заголовок сокращается до «Админ-панель». Соседние вкладки могут
выходить за горизонтальный viewport. Две крайние вкладки при1.3 и «Каналы»
при1.0/1.3 сначала частично обрезаны; дополнительные observed swipes раскрыли
выбранные подписи полностью. Первые снимки сохранены. Нового golden нет.

44dp проверены только для sampled selected-tab и Close bounds; округление
целочисленного Android AX допускает1 physical pixel. Пример Close123px при
dpr2.8125 =43.733dp; это не измерение всех целей панели или полной SafeArea.

При1.0 ввод — synthetic ASCII через ADB с настоящей открытой IME, не Gboard
composition. При2.0 три ошибки контроллера сохранены: первоначальная попытка,
fresh-instance retry и повтор с focus/empty/IME guards. В последнем readback
длина1 вместо23 и exact marker отсутствует. Причина не установлена, неизвестный
текст не очищался; admin unmount disposes локальный controller. Fresh-instance
readback подтверждает пустой фильтр и устраняет прежнюю неопределённость cleanup.
`hint-oracle-probe.json` не подтверждает гипотезу placeholder. JSON `status`
важнее exit0 helper, который сохраняет ошибку через exception handler.

Окончательное восстановление записано в `final-restoration.json`: исходный DM,
пустой фильтр/composer, Members selection, font1.0, скрытая IME, точные permission
flags, исходный voice/unmuted mic80; screen FGS/MediaProjection отсутствуют.
Сессия, server URL, TLS trust и router не менялись. Production faults/load нет.

Полные QA-gates остаются открыты: другие платформы, аппаратная клавиатура,
TalkBack/VoiceOver/NVDA, long strings, CRUD/conflicts/API content, live states,
contrast/reduced motion, resize/selection/reset URL и акустика не приняты.
Source-bound hashes — `source-fingerprints.json`; product/tests не менялись,
hosted CI для evidence head NOT_RUN.43 решения консолидации не затронуты.
