# Физический Android ADMIN: чужой DM и удалённые сообщения в поиске

Две **scoped PASS** проверки на production `https://v.bootybay.ru`.
Samsung SM-A576B / Android16 / signed1.0.47+2082/source072426d6,
1080×2340/density450/font1.0. Installed APK SHA256 повторно проверен.
Web receipt8a2cda38 записан отдельно; API source UNKNOWN.

| Что защищает | Команда/действие | Платформа | Когда обязательно | Где результат |
|---|---|---|---|---|
| ADMIN видит разрешённое сообщение, чужой двухсторонний DM исключён | `python -X utf8 .out/qa-native-admin-privacy/native_search_v2.py run`; API fixtures и visual review по шагам ниже | Физический Android; Windows APIRequestContext только для собственных fixtures | Перед native foreign-DM search ACL в I287.C3; supplement I53.C1 | `native-search-result.json` PASS_SCOPED; `native-static-result-count.png` |
| Новый поиск исключает подтверждённо удалённые сообщения | `node .out/qa-native-admin-privacy/cleanup_fixtures.mjs`; `python -X utf8 .out/qa-native-admin-privacy/native_deleted_search.py`; crop review/confirm_empty_pixels | Тот же реальный Android | Перед native deleted-message search acceptance | `native-deleted-search-result.json` PASS; `native-deleted-search-empty-full.png` |
| Восстановлены исходные scope/DM/draft/font/voice/permission | `python -X utf8 .out/qa-native-admin-privacy/native_search_v2.py clear_close`; `python -X utf8 .out/qa-native-admin-privacy/final_native_readback.py` | Тот же телефон | После проверки | `final-native-readback.json` PASS |

Реальные шаги и атрибуция:

1. Существующие secure HttpOnly сессии собственных B/C проверены через API.
   Retained own-DM binding сопоставлен приватно; текущий `/members/<phone>`
   подтвердил ADMINISTRATOR. Телефон отличается от обоих участников B/C.
   Native cookies/credentials не извлекались. Windows browser/UI не использовался.
2. Через наблюдённые «Открыть навигацию» → «Поиск сообщений» открыт native поиск.
   Исходный query пуст; область была current. Временно выбрано «Везде».
3. Созданы два собственных сообщения с общим уникальным запросом: разрешённое
   B→телефон и запрещённое для телефона B→C. API поиска B видит оба IDs, C только
   своё; C получает404 для исходного phone DM. Оба сообщения доступны поиску
   участников как до, так и после native наблюдения.
4. ADB ввёл только собственный query; реальная кнопка «Найти» запустила native
   запрос. Разрешённый fixture виден, чужой отсутствует, actual result button1.
   Исходный снимок статичного счётчика показывает «Найдено1 сообщения».
5. У обоих собственных сообщений DELETE204 и подтверждённый tombstone; API
   запрос B/C возвращает0. Повторный native «Найти» с тем же query даёт0 result
   buttons и отсутствие обоих тел; generic crop показывает «Совпадений нет».
6. Свежие native crop pixels совпали с просмотренным empty-state image.
   Собственный query очищен, original current scope возвращён и поиск закрыт.
   Independent readback подтвердил исходный DM, empty composer, font1.0, точные
   permission flags, действующий unmuted voice/mic80 и отсутствие screen FGS/Projection.

Команды выполнялись из local-qa-stack worktree; источники — `runner-source/`
с суффиксом `.txt`, восстанавливаемым в `.py`/`.mjs` внутри `.out/qa-native-admin-privacy`.
Зависимости Python: `../native-admin/runner-source/admin_common.py.txt`,
`../runner-source/native_sender_phone_common.py.txt`,
`../runner-source/android_permission_ui.py.txt` с исходным import layout.
Node использует существующий Playwright runtime и private controlled fixture/session
paths из `api_context.mjs`. Private файлы не публикуются; неизвестный query не очищать.

Порядок воспроизведения: API preflight → `native_search.py open` →
`native_search_v2.py set_all` → seed → native run → observe → live-fixture readback →
cleanup → native_deleted_search → capture_empty_full + visual review →
confirm_empty_pixels → clear_close → final_native_readback. Новый fixture запускать
в новом приватном каталоге: helper не перезаписывает существующий fixture receipt.

История ограничений контроллера сохранена. `native-run.json` завершился
FAIL_OR_CONTROLLER: числовая строка находится под ExcludeSemantics и отсутствует
в AX tree. Исходный count gap crop, исключающий query/author/body, просмотрен в
исходном размере и показывает1; результат принят по combined UI/API/visual evidence.
Первый empty crop обрезан после иконки и не является доказательством результата.
Второй показывает generic No matches; capture_empty_full.py — сохранённая
реконструкция выполненного inline шага без before-file hash. Отдельный
confirm_empty_pixels.py хеширован перед выполнением и подтвердил свежие пиксели.
Диагностическая подпись тестового контакта удалена из scope-observation.json до публикации.

Все3 безопасных crops просмотрены в исходном разрешении. Нет identity/account list,
private body/ID, raw hierarchy, native auth или media в публичных артефактах.
Тестовые сообщения удалены; пустой/существующий B↔C DM сохранён. Нет мутации
аккаунтов/ролей/block/revoke, logout/server switch, TLS/router change или fault/load.

Это native rendered search. Browser third ADMIN, socket create/edit/delete hints,
unread, OS notifications, attachments после revoke/block, остальные search filters,
DST/cursors/plans/platforms/AT и слышимость остаются отдельными gates. Явный поиск
после удаления не доказывает автоматическую инвалидацию search cache. Product/tests
не менялись, hosted CI evidence head NOT_RUN;43 решения консолидации не затронуты.
