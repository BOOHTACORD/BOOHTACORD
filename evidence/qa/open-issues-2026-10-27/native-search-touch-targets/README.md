# Android: область нажатия «Область поиска»

**FAIL** физического Android48dp gate I301.C6. Samsung SM-A576B,
Android16/API36, signed1.0.47+2082/source072426d6,1080×2340,font1.0.
Эффективная density450, dpr2.8125. Installed APK SHA256 повторно совпал.
Production `https://v.bootybay.ru`; API source UNKNOWN.

| Что защищает | Команда | Платформа | Когда обязательно | Где результат |
|---|---|---|---|---|
| Активная native цель соответствует48dp; малая визуальная рамка требует расширенной hit area | `python -X utf8 .out/qa-native-search-targets/probe_targets.py`; `python -X utf8 .out/qa-native-search-targets/assert_target.py` | Физический Android/density450/font1.0 | Перед I301.C6 и соответствующей физической UX-приёмкой #303 | `touch-probes.json`, `target-invariant.json` FAIL/exit1 |
| Popup/Back сохраняют пустой query и выбранную область | Те же8 probes, только наблюдённый Back после открытого popup | Тот же телефон | При приёмке реального dropdown | `touch-probes.json`, все state guards true |
| Исходный DM/font/voice/permission/composer восстановлены | `python -X utf8 .out/qa-native-search-targets/restore_targets.py` | Тот же телефон | После проверки | `final-restoration.json` PASS |

Измерение: scope `[45,468,746,558]` =701×90px =249.244×**32dp**.
Соседняя disabled «Найти» `[780,446,1035,581]` =255×135px, высота**48dp**;
это только геометрический reference, disabled action не нажималась.
Product gate48dp задан #301; [Android accessibility guidance](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views)
рекомендует такую touch/focus area и допускает меньший рисунок при увеличенном
окружении для касания. Поэтому одной визуальной/AX рамки недостаточно: выполнены
настоящие точки активации. Это не утверждение об OS-enforced minimum.

| Проба при x395 | y | Popup |
|---|---:|---|
| center before | 513 | открыт |
| внутри сверху | 470 | открыт |
| внутри снизу | 556 | открыт |
| на2px выше | 466 | не открыт |
| на2px ниже | 560 | не открыт |
| на9px выше | 459 | не открыт |
| на9px ниже | 567 | не открыт |
| center after | 513 | открыт |

Это одна последовательность из8 точек, а не8 независимых запусков приложения.
Обе центральные проверки прошли; за границей не обнаружено расширения на
проверенных точках. Другие actionable controls не пересекались ни с одной
точкой. После4 открытий использован настоящий Android Back; selected scope,
пустой query и открытый search сохранились. Search Submit не выполнялся.

Воспроизведение из local-qa-stack worktree: проверить собственный пустой DM,
font1.0/density450; `open_targets.py` открывает наблюдённую навигацию → поиск;
`probe_targets.py` берёт свежие границы перед каждым касанием;
`capture_target_strip.py` сохраняет strip; `assert_target.py` выдаёт exit1;
`restore_targets.py` закрывает search и проверяет исходное состояние.
Исходники — `runner-source/*.py.txt` с восстановлением `.py` в
`.out/qa-native-search-targets`. Общие зависимости:
`../native-admin/runner-source/admin_common.py.txt`,
`../native-admin/runner-source/admin_ime_retry.py.txt`,
`../runner-source/native_sender_phone_common.py.txt`,
`../runner-source/android_permission_ui.py.txt`; сохранить исходный import layout.
Private config содержит только заранее разрешённый own peer и не публикуется.
Не продолжать при неизвестном query, scope, чужом control overlap или закрытом search.

Crop просмотрен в исходном размере1080×151, без resampling. Весь interior dropdown
закрыт privacy mask, оставлены рамка и disabled Find reference. Mask/crop/source hash
записаны в `target-strip-capture.json`; query/body/identity и popup не захвачены.
Нового golden нет. Actual hit-test evidence —8 input observations, не одна картинка.

Source `scope_field/handler.dart:33` фиксирует высоту32; этот exact файл на
master8a2cda38 совпал с installed source. `master-source-comparison.json` не является
runtime новым APK. Ближайший typed search-context тест не проверяет target size.
Fix acceptance: добавить target/hit regression с active dropdown, обеспечить
48dp actual target и повторить native край/центр/Back без изменения scope/query.

Исходный DM, font1.0, empty composer/query, current scope, permission flags и
unmuted voice/mic80 восстановлены. Нет screen FGS/Projection, resource mutation,
server/TLS/router changes или Windows UI. Полный hit map, все остальные controls,
font1.3/2.0, TalkBack, другие платформы и акустика не приняты. Исторические scoped
44dp passes не переписаны. Product/tests не менялись, hosted CI NOT_RUN,
43 решения консолидации не затронуты; полные QA-gates открыты.

Physical Android search target defect: [#586](https://github.com/Egkurilov/BOOHTACORD/issues/586). Exact bug/QA readbacks: `github-updates.json`.
