# Android: фокус поиска участников при настоящем вводе Gboard

**FAIL при2.0,2/2 прогона; PASS контрольного1.0.** Production
`https://v.bootybay.ru`, Samsung SM-A576B, Android16/API36,1080×2340,
density450, подписанный1.0.47+2082/source072426d6. Во всех трёх прогонах
installed APK SHA256 повторно совпал с кандидатом; Gboard18.5.4.993608717.
Исходная SHARE_TEST voice активна. API source UNKNOWN.

| Что защищает | Как запускается | Платформа | Когда обязательно | Где результат |
|---|---|---|---|---|
| Каждый символ сохраняет фокус поля и открытую IME при2.0 | `python -X utf8 .out/qa-admin-keyboard/gboard_filter_case.py runN 2.0`, затем `python -X utf8 .out/qa-admin-keyboard/assert_focus.py runN.json` | Физический Android, Gboard, actual observed key touches | Перед admin input/large-text acceptance, I287.C14/I301.C4/I303.C2/C3 | `run1.json`, `run2.json`; оба `*-focus-invariant.json` FAIL/exit1 |
| Четыре символа и явный Back сохраняют запрос при1.0 | Тот же helper с `run3 1.0`, затем `assert_focus.py run3.json` | Тот же телефон/Gboard | Контроль основного ввода и IME/Back | `run3.json`, `run3-focus-invariant.json` PASS/exit0 |
| Собственный фильтр/масштаб/исходный DM/voice восстановлены | `python -X utf8 .out/qa-admin-keyboard/restore_keyboard_packet.py` | Тот же физический клиент | После каждого пакета | `final-restoration.json`: PASS |

Воспроизведение через обычный UI:

1. Включить настоящий system font2.0. Открыть «Настройки аккаунта» →
   «Администрирование» → «Участники»; фильтр пуст, собственная сессия сохранена.
2. Коснуться поля поиска. Проверить focused=true и mInputShown=true.
3. На показанной русской Gboard нажать «т». До следующего наблюдения Back,
   смена раздела или иные действия не выполняются.
4. В обоих прогонах поле содержит ровно собственный первый символ, но
   focused=false и mInputShown=false; admin остаётся открыт. Последующие
   символы без повторного фокуса ввести нельзя. На crop исчез focused outline.
5. Контроль1.0: четыре отдельных нажатия «т»,«е»,«с»,«т» дали точные префиксы
   длиной1/2/3/4, focused=true и IME=true после каждого. Явный Back скрывает IME,
   сохраняет admin и весь запрос.

Runner sources сохранены как `runner-source/*.py.txt`. Перед input использованы
`keyboard_probe.py` и его1.0 вариант: только пустое поле; actual keyboard crops
просмотрены в исходном разрешении, по ним выбраны центры клавиш. Общие imports
восстанавливаются из `../native-admin/runner-source/`, а их зависимости из
`../runner-source/native_sender_phone_common.py.txt` и
`../runner-source/android_permission_ui.py.txt`. Сохранять исходный `.out` layout;
private fixture — только заранее разрешённый собственный peer, без native cookie.
Каждый runN должен иметь новое имя: существующие результаты не перезаписываются.

`gboard_filter_case.py` сохраняет JSON независимо от результата. Отдельный
`assert_focus.py` проверяет реальные observations: exit1/exit1/exit0, точные argv
и stdout статусы — `invariant-invocations.json`. Он не запускает widget/CI tests.
Предыдущие неоднозначные попытки ADB остаются в `../native-admin/`; новый реальный
Gboard контрпример не переписывает их в подтверждённые результаты задним числом.

В исходнике большой ListView содержит filters, а его PageStorageKey включает
search. Input вызывает parent rebuild. **Гипотеза причины:** смена ключа
пересоздаёт input subtree. [Flutter Widget.key](https://api.flutter.dev/flutter/widgets/Widget/key.html)
описывает замену element при смене ключа. Native instrumentation/mutation с
исправленным ключом не выполнялись; причинность patch не доказана. Exact layout
на master8a2cda38 совпал с installed source072426d6: `master-source-comparison.json`.
Это сравнение одного файла, не физический runtime нового APK.

Все8 crops просмотрены в исходных размерах. Только клавиши без suggestion strip
и поле собственного фильтра; account list/history/identities/raw XML не сохранены.
Fresh-instance readback подтвердил пустой фильтр; исходный DM, font1.0,
скрытая IME, пустой composer, permission flags и voice/unmuted mic80 восстановлены.
Нет screen FGS/Projection, server mutation, logout/server switch/TLS/router changes.

Fix acceptance: focused regression с посимвольным editing update без повторного
requestFocus; physical2.0 Gboard многосимвольный повтор, Back/query retention,
контроль1.0/1.3, role/status filters и list scroll-state. Остальные платформы,
TalkBack, hardware keyboard, человеческая приёмка и акустика остаются отдельными.
Golden не утверждался; product/tests не менялись, hosted CI NOT_RUN,43 решения
консолидации не затронуты. Полные QA-gates открыты.

Подтверждённый large-text input defect: [#585](https://github.com/Egkurilov/BOOHTACORD/issues/585). Exact bug/QA body readbacks: `github-updates.json`.
