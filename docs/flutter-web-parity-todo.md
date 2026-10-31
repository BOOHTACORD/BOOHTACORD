# Current follow-up status (#518)

Confirmed realtime/admin/viewer source gaps from #518 are handled by PAR-001.
The existing feature registry is the authoritative scenario matrix; see
[parity contract](flutter-web-parity.md) and [run/build report](../evidence/qa/issue518-client-parity.md).
Earlier TODOs below are historical unless their current matrix row still has
GAP/PLANNED status. Do not reimplement #499–502/#516 or infer missing behavior
from old TODO text. Physical capture/audio/background acceptance (#62/#132/#303)
remains separate from implementation and simulator/emulator UI/API evidence.

# Flutter ↔ web parity — только открытые задачи

Source of truth: [parity map](flutter-web-parity.md). Реализованные admin, conversation и release APK leaves перенесены в [DONE_AUDIT_2026-09-27.md](history/status/DONE_AUDIT-2026-09-27.md). Этот checklist входит в QA-13; local widget/source checks не закрывают device acceptance.

## Admin parity epic #188

- [x] Flutter admin foundation and functional slices for readiness, members,
  roles, topology, audit, media and guild settings implemented with focused
  tests. See [parity map](flutter-web-parity.md) and
  [FV2-031 evidence](../evidence/flutter/qa-admin-parity-2026-10-07-001.json).
- [x] Members expanded rows and Roles before/current/proposed conflict review
  completed on `codex/issue-188-flutter-admin-completion`; full Flutter suite,
  analyzer, dependency guard and split APK gate pass — [Members evidence](../evidence/flutter/qa-admin-members-responsive-2026-10-07-001.json),
  [Roles evidence](../evidence/flutter/qa-admin-roles-conflict-2026-10-07-001.json).
- [x] Cross-cutting large-text/resize regression hardening: the admin geometry
  matrix now covers phone portrait/landscape, tablet and desktop widths, and a
  text-scale 2.0 traversal opens every section. Channels dropdowns, Audit,
  Media and Readiness no longer overflow at that scale — [accessibility
  evidence](../evidence/flutter/qa-admin-accessibility-hardening-2026-10-07-001.json).
- [ ] Runtime acceptance across Android, iOS, macOS and Windows. Android and
  macOS checks may be recorded when the clients are available; iOS and Windows
  remain open until a real runtime is supplied. Do not mark this item PASS from
  widget tests alone. A macOS administrator-surface pass is recorded in
  [QA-ADMIN-MACOS-RUNTIME-2026-10-07-001](../evidence/flutter/qa-admin-macos-runtime-2026-10-07-001.json);
  an Android portrait administrator-surface pass is recorded in
  [QA-ADMIN-ANDROID-RUNTIME-2026-10-07-001](../evidence/flutter/qa-admin-android-runtime-2026-10-07-001.json).
  A current-source Android portrait + landscape smoke after the accessibility
  hardening is recorded in
  [QA-ADMIN-ANDROID-RUNTIME-2026-10-07-002](../evidence/flutter/qa-admin-android-runtime-2026-10-07-002.json).
  The subsequent compact identity regression and current APK launch smoke are
  recorded in
  [QA-ADMIN-ACCESSIBILITY-HARDENING-2026-10-07-002](../evidence/flutter/qa-admin-accessibility-hardening-2026-10-07-002.json).
  These records do not replace live-resize, IME/TalkBack, iOS or Windows acceptance.

## Текущий фокус: Flutter macOS и Android

Ближайшие leaves выполнять в таком порядке: (1) Android screen-preview regression
после EGL release barrier — сначала воспроизводимый plugin/UI regression, затем
Pixel runtime acceptance; (2) Android voice/publication persistence при фоне;
(3) macOS обнаружение/просмотр remote screen-share и проверка unpublish;
(4) Android login/Gboard и повторный screen-share flow; (5) macOS Keychain/session restore на стабильной подписи, когда будет доступна
Developer ID identity. Общие macOS/Android voice, audio-device и screen-share
проверки остаются в объёме. Windows-only acceptance, Windows runner и FE-63
MSVC/PCM gate отложены и не должны вытеснять эти задачи; общие изменения не
должны регрессировать Windows build.

## P0 — Запуск приложения

- [x] Разобраться, почему свежий macOS debug-клиент после запуска остаётся на
  «Подключаемся к гильдии…»: legacy Keychain блокировал
  `SecItemCopyMatching`; переключено на Data Protection Keychain, debug startup
  доходит до логина —
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
- [ ] На подписанной macOS release-сборке проверить запуск и сохранение сессии
  через перезапуск; подтвердить ожидаемый повторный вход для cookies, ранее
  сохранённых в legacy Keychain. Debug-клиент после свежего запуска восстановил
  существующую авторизованную сессию; universal macOS Release 1.0.13 (18)
  локально собран из текущего source, обе архитектуры и ad-hoc подпись прошли
  проверку — [QA-151](../evidence/flutter/qa151-macos-release-current-source-build-2026-09-30-001.json).
  Developer ID/notarization и runtime-проверка запуска/сессии остаются открытыми;
  предыдущая release-упаковка проходит asset-limit gate —
  [QA-135](../evidence/release/macos-v1.0.12-local-2026-09-30-001.json).
  На этом Mac нет valid Developer ID signing identity —
  [QA-40](../evidence/flutter/qa40-macos-startup-loading-2026-09-28-001.json).
  Пользователь сообщил о запросе пароля/разрешения Keychain при входе. Текущая
  конфигурация не задаёт user-presence/access-control policy; точный системный
  диалог не подтверждён. Повторить свежий вход и relaunch с session cookie в
  Developer ID-подписанном клиенте после уточнения текста окна —
  [QA-141](../evidence/flutter/qa141-macos-keychain-access-prompt-2026-09-30-001.json),
  [QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json).
- [x] Сделать macOS release packaging устойчивым к устаревшему nested-code seal
  после Flutter/Xcode build: при ошибке проверки разрешено переподписать только
  внешний ad-hoc bundle с сохранением entitlements; ошибочную Developer ID
  подпись скрипт не заменяет. Проверены universal Release 1.0.13+18, strict
  bundle verification, ZIP 40,067,669 bytes и checksum; package regression
  покрывает оба пути. Подписанный/notarized Release и установленный runtime
  остаются открытыми — [QA-153](../evidence/flutter/qa153-macos-release-ad-hoc-seal-recovery-2026-09-30-001.json).
- [x] Восстановить macOS Debug startup после зависания v2 Keychain lookup: свежий
  sample подтвердил ожидание внутри `SecItemCopyMatching`/`CSSM_DecryptDataFinal`;
  сессия переведена на отдельный legacy service `.session.v3`, прежние записи
  оставлены нетронутыми. Новый процесс дошёл до login form без Keychain prompt;
  disposable plugin write/read/delete прошёл, 278 Flutter-тестов/analyzer и
  universal macOS Release compilation прошли. Успешный account login/write,
  relaunch в v3 и stable-signature acceptance ещё не проверены —
  [QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json).
- [x] Устранить `PlatformException` при сохранении сессии на macOS: screenshot
  показывал Security.framework `errSecMissingEntitlement` (`-34018`) при
  Data Protection Keychain. На macOS используется поддерживаемый legacy
  Keychain с отдельным service name: это не требует Keychain Sharing entitlement
  и не читает старую зависавшую запись; ad-hoc сборка и запуск проходят без
  ошибки Keychain, Debug-процесс восстановил существующую авторизованную сессию,
  а реальный plugin integration test подтвердил запись, чтение и удаление
  отдельного QA-значения — [QA-60](../evidence/flutter/qa60-macos-keychain-entitlement-2026-09-28-001.json),
  [QA-99](../evidence/flutter/qa99-macos-keychain-service-rotation-2026-09-29-001.json),
  [QA-113](../evidence/flutter/qa113-macos-keychain-integration-roundtrip-2026-09-29-001.json).
  Вход с записью новой session cookie и повторный вход для старого service всё
  ещё нужно проверить; existing Keychain записи не удалялись. Не переносить
  session cookie в plaintext и не удалять Keychain items.
- [x] Найти причину долгой загрузки macOS Debug 1.0.15+20: свежий sample
  текущего процесса снова показывает `flutter_secure_storage.read` →
  `SecItemCopyMatching` → `CSSM_DecryptDataFinal`; `securityd` подтвердил prompt
  для `.session.v3`. Ad-hoc CDHash текущей сборки отличается от code hashes,
  перечисленных в ACL записи, поэтому новая пересборка может снова потребовать
  разрешение. Подробности — [QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json);
  предыдущая шестиминутная задержка описана в
  [QA-160](../evidence/flutter/qa160-macos-debug-restart-2026-09-30-001.json).
- [ ] Обеспечить устойчивый macOS startup/session restore без повторяющегося
  Keychain prompt: проверить один раз выданное пользователем разрешение и
  повторный запуск; затем повторить со стабильной Developer ID подписью. Не
  отключать Keychain ACL и не переносить session cookie в plaintext. На этом Mac
  нет действительной Developer ID identity; сейчас требуется действие
  пользователя в системном окне либо тест на корректно подписанной сборке —
  [QA-141](../evidence/flutter/qa141-macos-keychain-access-prompt-2026-09-30-001.json),
  [QA-143](../evidence/flutter/qa143-macos-keychain-v3-startup-recovery-2026-09-30-001.json),
  [QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).
  - [x] Убрать Keychain read из публичного `/maintenance` при старте и refresh
    каждые 5 секунд, сохранив `Origin`/`Accept`: test-first API regression и все
    314 Flutter-тестов/analyzer проходят. Это сокращает лишние обращения, но не
    обходит защищённое чтение `/auth/session` и не закрывает блокировку —
    [QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).
  - [x] Не оставлять launch splash навсегда при зависшем session check: после
    20 секунд показывать retryable connection error с подсказкой про системное
    Keychain-окно на macOS. Widget regression подтверждает переход из loading,
    видимую причину и кнопку retry; все 315 Flutter-тестов и analyzer проходят.
    Это ограничивает UI ожидание, но не отменяет native Keychain operation и не
    заменяет авторизацию/стабильную подпись —
    [QA-163](../evidence/flutter/qa163-macos-keychain-prompt-runtime-2026-10-01-001.json).
  - [x] Расширить startup deadline на все pre-ready операции, а не только
    `currentSession`: regression tests сначала воспроизвели вечный splash при
    зависшем API bootstrap и account-preference read. Теперь secure storage,
    platform notification init, проверка сессии и account preparation вместе
    ограничены 20 секундами — 4 stall tests, весь Flutter suite (416), analyzer
    и macOS Debug build проходят. Реальный экран retry/повторный вход на этом
    Mac ещё проверить — [QA-216](../evidence/flutter/qa216-macos-bounded-startup-initialization-2026-10-02-001.json).

## P0 — Голосовые каналы и демонстрация экрана

- [ ] RNNoise opt-in добавлен в web и Flutter, но реальная audio-engine parity ещё не принята. Flutter Windows CI #14 обнаружил MSVC/VLA несовместимость; source-preserving CMake overlay для Windows добавлен в `b81128b`, новый hosted build и execution PCM parity fixture ещё не подтверждены — [evidence](../evidence/noise-suppression/2026-10-02-windows-msvc-overlay.md). На физических Windows/Android сверить выбор `off/browser/rnnoise`, requested/effective engine и fallback copy; проверить сохранение предпочтения, mute/PTT/deafen, замену устройства, reconnect и сбой/неподдерживаемый PCM с bounded recovery. На macOS явно подтвердить `platform-aec-ns-coupled` и сохранение AEC вместо RNNoise. Затем отдельно проверить русскую речь/шум, double-talk, USB/Bluetooth и длительный звонок на реальных устройствах; сохранять только агрегаты и hardware/build metadata, не PCM. Не считать browser/unit/native-synthetic gate акустической или аппаратной приёмкой — [ADR-014](adr/ADR-014-client-rnnoise.md), [partial automated evidence](../evidence/noise-suppression/2026-10-02-automated-gates.md).

Критический пользовательский путь на всех клиентах. Сначала закрываем возврат к
своей/чужой трансляции и базовые проблемы устройств; затем проводим реальные
peer/platform-проверки и выравниваем viewer с вебом.

- [ ] На macOS, Windows и Android пройти полный путь: подключение, mute/deafen,
  запуск screen share, возврат к roster, повторное открытие из карточки, выбор
  другой трансляции и корректное завершение локально/из OS. После обновления
  roster-контракта собраны macOS Release, GitVerse Windows Release CI и свежие
  подписанные Android ABI APKs. 2026-09-30 Pixel 7 / Android 17 с 1.0.15+20 и
  Mac Debug 1.0.15+20 одновременно вошли в SHARE_TEST с выключенными
  микрофонами; полный portrait-экран отобразился на Mac без crop, приложение
  пережило старт/первый кадр/остановку и вернулось к roster — [QA-162](../evidence/flutter/qa162-macos-webrtc-renderer-dispose-race-2026-09-30-001.json).
  Полный сценарий остаётся открыт для Windows, OS-level stop, повторного открытия
  своей трансляции после возврата к roster и выбора другого потока —
  [QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).
- [ ] На macOS и Android открыть локальную трансляцию повторно из собственной
  карточки после возврата к roster; отдельно проверить, что завершившаяся чужая
  трансляция не подменяется локальной.
- [x] Не принимать отложенный first-frame callback предыдущей публикации за кадр
  выбранного сейчас потока: callback `ScreenFrameGate` привязан к generation
  выбранного трека. Regression воспроизведён до исправления; полный Flutter suite
  (409), macOS Debug и Android arm64 Debug builds проходят — [QA-210](../evidence/flutter/qa210-flutter-stale-screen-frame-callback-2026-10-02-001.json).
- [x] На macOS/Darwin не принимать уже поставленное в main queue событие первого
  кадра старого `RTCVideoTrack` за готовность нового: renderer сохраняет
  generation при загрузке pixel buffer и перед отправкой события проверяет, что
  дорожка не заменена. Регрессия падала до изменения; все 21 WebRTC package
  tests и macOS Debug build проходят — [QA-211](../evidence/flutter/qa211-macos-renderer-track-generation-2026-10-02-001.json).
- [x] Не позволять запоздавшему ответу `srcObject = null` очищать размеры и
  `renderVideo` уже подключённого нового потока: native Dart renderer сверяет
  source generation после каждого method-channel ответа и инвалидирует ожидания
  при dispose. Regression падает без guard; все 22 WebRTC package tests, 413
  client tests, analyzer и macOS Debug build прошли —
  [QA-214](../evidence/flutter/qa214-native-video-renderer-source-generation-2026-10-02-001.json).
  Live browser→Mac кадры и unpublish ещё требуется подтвердить.
- [x] До Android screen capture проверять MediaProjection FGS type в merged app
  manifest, а foreground service запускать с manifest-declared type. Контрактный
  тест сначала падал; затем тест и analyzer прошли, полный Flutter suite (410)
  прошёл; legacy и AGP built-in Kotlin debug builds проходят (для второго нужен
  JDK 17) — [QA-212](../evidence/flutter/qa212-android-media-projection-service-readiness-2026-10-02-001.json).
- [x] Сохранять явное ended-состояние при завершении выбранной чужой трансляции;
  не переключать пользователя молча на собственный экран, предложить выбрать
  другой поток вручную или вернуться к участникам — [QA-38](../evidence/flutter/qa38-voice-screen-ended-state-2026-09-28-001.json).
- [x] Привязать transient viewer selection к ID голосового канала, чтобы при
  переходе в другую комнату не наследовались remote identity и ended-state —
  [QA-39](../evidence/flutter/qa39-voice-channel-viewer-scope-2026-09-28-001.json).
- [x] На Android 12+ перечислять не только USB, но и доступные системные
  communication outputs (разговорный/основной динамик, проводные и Bluetooth
  выходы), выбирать их через `AudioManager.setCommunicationDevice` только в
  активной voice-сессии и снимать override при leave/disconnect. Если native
  enumeration отсутствует, показывать системный выход по умолчанию вместо
  «Динамики не найдены». Pixel 7 / Android 17 подтвердил в UI оба встроенных
  динамика; release APK 1.0.9+13 установлен без потери данных — [QA-126](../evidence/flutter/qa126-android-communication-audio-routes-2026-09-29-001.json).
- [x] Исправить локальную проверку микрофона Android: сопоставлять WebRTC ID
  встроенного микрофона (`microphone-bottom/back`) с числовым `AudioDeviceInfo`
  ID, который ожидает `record`; проверить речь на Pixel 7 без входа в голосовой
  канал, затем остановить захват. Полный Flutter suite (265 тестов), analyzer и
  release-сборка прошли — [QA-128](../evidence/flutter/qa128-android-local-microphone-check-2026-09-29-001.json).
- [x] Завершать локальную проверку микрофона и показывать ошибку выбранного
  устройства, если input track или уровень аудио неожиданно закончился; web
  слушает `MediaStreamTrack.ended`, Flutter обрабатывает завершение amplitude
  stream. Flutter regression был красным до исправления; focused web/Flutter
  tests, полный Flutter suite (286), analyzer и frontend production build прошли.
  Физическое отключение/подключение микрофона на Android, macOS и Windows
  остаётся открытым — [QA-152](../evidence/flutter/qa152-local-microphone-ended-state-parity-2026-09-30-001.json).
- [ ] На Android физически проверить USB/Bluetooth microphone/output hotplug,
  смену маршрута в активном звонке и слышимость; на macOS/Windows проверить
  перечисление, hotplug и переключение устройств. Пустой Android scan в
  `devicechange` теперь сохраняет выбор системного выхода вместо пустого списка;
  regression, все 283 Flutter-теста и analyzer прошли —
  [QA-149](../evidence/flutter/qa149-android-audio-empty-device-refresh-2026-09-30-001.json).
  Повторное перечисление,
  stale-scan protection, distinct loading/empty/error и ручное обновление
  покрыты локальными тестами — [QA-14](../evidence/flutter/qa14-audio-device-refresh-2026-09-27-001.json),
  [QA-69](../evidence/flutter/qa69-android-usb-audio-routes-2026-09-28-001.json),
  [QA-126](../evidence/flutter/qa126-android-communication-audio-routes-2026-09-29-001.json).
  Flutter now also retains a vanished selection during an empty device scan,
  then falls back to the first replacement and announces a live warning when
  devices return; state/UI tests, all 285 Flutter tests and analyzer pass —
  [QA-150](../evidence/flutter/qa150-audio-device-disconnect-feedback-2026-09-30-001.json).
- [ ] На каждой платформе проверить разрешение screen share, OS-level stop,
  Android 14+ MediaProjection service и реальный захват у peer. На Pixel 7
  (Android 17/API 37) полный захват экрана прошёл: foreground service имел тип
  `MEDIA_PROJECTION`, virtual display — 1080×2400, локальный viewer показал
  весь portrait-экран; ошибка `Unable to getDisplayMedia` не повторилась. App-level
  stop снял активную проекцию и освобождение voice lease прошло. Проверка
  OS-level stop, второго peer, receiver crop/metrics и остальных платформ остаётся
  открытой — [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [ ] **FE-68 · Android background microphone continuity:** отдельно сравнить сценарии с mic muted и mic
  enabled. Сейчас foreground service объявляет только `mediaProjection`, а
  предыдущий FE-64 Pixel-прогон был muted, поэтому microphone capture в фоне не
  проверен. Если он входит в ожидаемый parity, оценить отдельный microphone FGS
  type/permission и запуск при видимой Activity до изменения манифеста/ADR-006 —
  [QA-221](../evidence/flutter/qa221-android-background-microphone-fgs-gap-2026-10-02-001.json),
  [Android requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required),
  [background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
- [ ] **FE-59/FE-64 · Android runtime:** Pixel full-display preview/thumbnail and muted background/resume passed — [QA-222](../evidence/flutter/qa222-pixel-screen-share-background-lifecycle-2026-10-02-001.json). Android Emulator API 35 additionally passed single-app Clock preview, 10-second muted background/resume, and projection/service cleanup after stop/leave — [QA-224](../evidence/flutter/qa224-android-emulator-app-only-share-resume-2026-10-02-001.json). No paired receiver was present in either run; remote frames, sender/receiver metric correlation and mic-enabled background voice remain open.
- [ ] **FE-59 · Portrait participant thumbnail:** emulator local thumbnail logged `captured` and then `captureFailed` about 8.3 seconds later while the large viewer remained visible; the participant-strip image looked nearly blank for the portrait Clock source. Flutter `BoxFit.cover` and web `object-fit: cover` both crop; compare the actual rendered content and refresh behavior before changing either client — [QA-224](../evidence/flutter/qa224-android-emulator-app-only-share-resume-2026-10-02-001.json).
- [ ] На Android сверить room membership/publication с `MediaProjection` при
  переводе приложения в фон и возврате. Pixel 7 / `1.0.19+2032`: в user-started
  Calculator app-only тесте projection/foreground service и BOOHTACORD process
  оставались активны, но браузер временно показывал одного участника и ноль
  публикаций. После возврата приложения Android-участник восстановился, но
  захват уже был остановлен (пользователь ещё уточняет, вручную ли), публикации
  не было. Нужны sender `framesEncoded`, receiver `framesDecoded` и
  отдельное сравнение app-only vs full-display capture; пока нельзя заключить,
  что это чёрные декодированные кадры, а не RTC disconnect/unpublish —
  [QA-202](../evidence/flutter/qa202-android-surfaceproducer-resume-2026-10-02-001.json).
- [x] Устранить найденное в OS-stop прогоне зависание локального screen-share UI:
  Android `MediaProjection.Callback.onStop` теперь останавливает capturer,
  освобождает virtual display/surface и отправляет ended-событие только треку
  захвата; локальный WebRTC-пакет передаёт его LiveKit для снятия публикации.
  Dispatcher сохраняет ранний/дублированный event до регистрации Dart-трека
  и доставляет `onEnded`, даже если LiveKit назначает callback после stop.
  Пять package-регрессий, включая EventChannel → LiveKit callback ordering,
  все 224 app-теста и Android release compile прошли. Физический OS-stop ретест
  и второй peer остаются открытыми —
  [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [ ] На реальных peers проверить microphone/screen-audio gain, mute/deafen/PTT,
  смену устройств и ограниченный reconnect без параллельных loops/дублирующих
  voice lease на macOS, Windows и Android.
- [x] Ограничить reconnect активной голосовой комнаты шестью попытками и
  выровнять Flutter LiveKit SDK с web по экспоненциальным задержкам 250–4000 мс
  и jitter 0,8–1,2; после лимита завершать сессию с actionable-сообщением.
  Совпадение обеих retry-политик и остановка после шести попыток подтверждены
  focused tests — [QA-33](../evidence/flutter/qa33-flutter-voice-reconnect-limit-2026-09-28-001.json),
  [QA-86](../evidence/flutter/qa86-voice-reconnect-web-parity-2026-09-29-001.json).
  Проверка wall-clock поведения, восстановления медиа и освобождения lease при
  реальном сбое сети на macOS, Windows и Android остаётся открытой.
- [ ] Сверить permission-denied/prejoin/dock copy, focus и screen-reader
  announcements на устройствах. Обычный и joining copy prejoin приведён к вебу,
  состояния подключения, загрузка/ошибка roster помечены live-region, а header
  теперь показывает те же dynamic roster states, что и web (проверка до фикса
  воспроизводила расхождение на пустом roster) — [QA-154](../evidence/flutter/qa154-prejoin-roster-live-status-parity-2026-09-30-001.json),
  [QA-169](../evidence/flutter/qa169-flutter-prejoin-roster-header-copy-2026-10-01-001.json).
  Заголовок также сохраняет состояние roster при закрытом администратором входе;
  ошибка roster в этом состоянии покрыта красным/зелёным regression test —
  [QA-170](../evidence/flutter/qa170-flutter-closed-channel-roster-header-2026-10-01-001.json).
  dock reconnect/leaving, deafen guidance и pending/leave button states также
  приведены к вебу и покрыты локально. Проверка реальных screen readers/focus и
  mute/deafen поведения остаётся открытой — [QA-52](../evidence/flutter/qa52-voice-prejoin-copy-live-region-2026-09-28-001.json),
  [QA-53](../evidence/flutter/qa53-voice-dock-deafen-web-parity-2026-09-28-001.json).
  Состояние закрытого канала также выровнено с web: специальный status banner,
  отсутствие roster/prejoin/join controls и явный выход для активного участника;
  просмотр уже выбранного потока сохраняется — [QA-171](../evidence/flutter/qa171-flutter-closed-voice-admission-parity-2026-10-01-001.json).
- [x] Явно показывать после отказа/сбоя microphone capture, что пользователь
  остался слушателем; дать безопасный retry для VAD и PTT-инструкцию без
  обхода удерживаемой клавиши — [QA-32](../evidence/flutter/qa32-voice-microphone-unavailable-fallback-2026-09-27-001.json).
- [ ] Мобильный PTT больше не требует hardware key: Android/iOS используют
  удержание кнопки микрофона в voice dock, а desktop сохраняет клавиатурный
  режим. При недоступном микрофоне mobile fallback больше не просит назначенную
  клавишу; Android PTT selector и шумоподавление используют компактные выбранные
  подписи и не переполняют 390×844 layout — regression сначала падал overflow,
  после исправления полный suite (419) и analyzer прошли —
  [QA-213](../evidence/flutter/qa213-mobile-push-to-talk-touch-2026-10-02-001.json),
  [QA-218](../evidence/flutter/qa218-mobile-ptt-fallback-guidance-2026-10-02-001.json),
  [QA-219](../evidence/flutter/qa219-android-ptt-settings-responsive-2026-10-02-001.json).
  Android Emulator API 35 / `1.0.23+2035` подтвердил PTT без key binding и
  смену muted → active mic при удержании → muted после release; исходный VAD
  восстановлен — [QA-223](../evidence/flutter/qa223-android-emulator-touch-ptt-runtime-2026-10-02-001.json).
  На физических Android/iOS проверить release при background/system interruption,
  отменённом жесте и работу screen readers.
- [ ] На физических устройствах проверить receiver metrics/audio states,
  fullscreen/share permissions и переключение rail/viewer; локальный fullscreen
  и исправления диагностики, отступов и мобильного возврата — [QA-17](../evidence/flutter/qa17-voice-viewer-mobile-navigation-2026-09-27-001.json).
- [x] Совместить геометрию thumbnail в voice participant card с web: 64×64 px,
  `BoxFit.cover`, вместо Flutter 80×64. Test-first widget regression, 62 widget
  tests и analyzer проходят — [QA-232](../evidence/flutter/qa232-participant-thumbnail-web-geometry-2026-10-02-001.json).
- [x] Показывать потери пакетов трансляции как процент за скользящее окно 10 секунд,
  синхронно в web и Flutter; покрыть накопление окна, счётчики без изменения,
  reset и недоступные stats — [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json).
  При разборе incoming commits пройдены полные Flutter (275), web (677), Go и
  analyzer проверки как на первоначальном review, так и повторно на текущем HEAD —
  [QA-136](../evidence/flutter/qa136-untrusted-commit-review-and-regression-2026-09-30-001.json),
  [QA-139](../evidence/flutter/qa139-incoming-commits-current-head-regression-2026-09-30-001.json).
  Следующий приоритет — двухаккаунтная проверка roster/privacy и затем полный
  screen-share acceptance на реальных macOS/Windows/Android peers; сравнение
  populated diagnostics с удалённым viewer остаётся открытым.
- [x] Перезапускать receiver diagnostics при смене выбранного video track даже
  если чтение stats старого трека ещё не завершилось; ответы предыдущего track
  generation не должны ни блокировать новый sampling, ни сбрасывать его busy
  состояние. Widget regression воспроизвёл блокировку до исправления; generation
  token и локальный Flutter suite, analyzer, Android ABI release и macOS Release
  проходят — [QA-140](../evidence/flutter/qa140-receiver-diagnostics-track-generation-2026-09-30-001.json).
  GitVerse Windows CI run 1688569 прошёл tests, analyzer и Release build для
  code commit `32ad129`; реальный переключаемый remote viewer остаётся открытым.
- [x] Привести receiver diagnostics к веб-паттерну: компактная кнопка-summary и
  popover до 288 px вместо inline `ExpansionTile`, с прокруткой, размещением
  вверх при нехватке места снизу, закрытием по Escape и проверкой Android-width
  360 dp — [QA-57](../evidence/flutter/qa57-screen-diagnostics-popover-web-parity-2026-09-28-001.json).
  Фактические populated receiver metrics и matched screenshots на устройствах
  остаются открытыми в пункте выше.
- [x] Исправить web-панель статистики, когда summary у нижней границы viewport:
  фиксировать popover относительно viewport с рассчитанными top/left, ограничивать
  доступную высоту и прокручивать содержимое, не допуская обрезания контейнером
  viewer; полный frontend suite (686 tests) и production build прошли. Live browser
  screenshot confirmation остаётся открытым — [QA-158](../evidence/flutter/qa158-stream-metrics-web-panel-2026-09-30-001.json).
- [x] Добавить dock-объявление о новой чужой демонстрации экрана и отключаемый
  локальный звуковой сигнал; не объявлять исходные публикации при входе и
  восстановленные дорожки при reconnect — локальная логика/виджет покрыты
  [QA-54](../evidence/flutter/qa54-voice-stream-start-alert-web-parity-2026-09-28-001.json).
  Слышимость системного сигнала и реальные LiveKit события на macOS/Windows/
  Android остаются открытой device-приёмкой.
- [x] Показывать во Flutter voice-room и постоянном dock цветной индикатор
  качества LiveKit и измеренный ping по RTT аудиодорожки; при недоступном RTT
  показывать «—», не подменяя его screen-share статистикой — [QA-110](../evidence/flutter/qa110-voice-connection-quality-2026-09-29-001.json).
- [x] Добавить тот же индикатор в web dock, обновлять его раз в две секунды только
  при активном voice-соединении и останавливать polling при reconnect/leave —
  [QA-111](../evidence/flutter/qa111-web-voice-connection-quality-2026-09-29-001.json).
- [x] Не объявлять каждый ping через Flutter live region: live announcement
  остаётся только у состояния/канала, а quality/ping имеет отдельную обычную
  accessible label; полный suite, analyzer и свежая macOS Debug-сборка прошли —
  [QA-112](../evidence/flutter/qa112-voice-quality-accessibility-macos-build-2026-09-29-001.json).
  Реальное обновление метрик и доступность RTT проверить с подключённым peer на
  macOS/Windows и в браузере; Pixel 7 показал 10 мс с выключенным микрофоном
  [QA-131](../evidence/flutter/qa131-android-voice-ping-muted-runtime-2026-09-29-001.json),
  а проверка с отдельным аккаунтом остаётся открытой; фактический ping зависит
  от платформенной WebRTC-статистики.
- [x] В voice-room не объявлять pending LiveKit-сессию как «Подключено»: отличать
  joining/connected/reconnecting/leaving/error/disconnected и показывать ping/quality
  только после фактического подключения; voice/workspace widget tests и analyzer
  прошли — [QA-119](../evidence/flutter/qa119-voice-connection-transition-state-2026-09-29-001.json).
- [x] Исправить пустой Android ping при выключенных микрофоне и удалённом звуке:
  собирать stats publisher и subscriber peer connections, приоритизировать audio
  `remote-inbound-rtp`, выбирать ICE RTT отдельно внутри каждого соединения и
  удерживать последнее измерение при пустом snapshot. На Pixel 7 после установки
  1.0.8+12 ping показал 92–103 мс в room badge и dock при выключенном микрофоне;
  262 Flutter tests, analyzer и LiveKit package checks прошли. Публикация
  `android-v1.0.8` прошла в workflow 1682148; проверка с другим участником/deafen
  остаётся открытой —
  [QA-123](../evidence/flutter/qa123-android-voice-rtt-peer-connections-2026-09-29-001.json).
- [x] Убрать из компактного voice dock лишнюю стрелку, раскрываемую область и
  пояснение; оставить постоянный ряд voice-действий. Исправить ping: брать RTT
  связанного LiveKit `remote-inbound-rtp`, а не outbound report — unit/widget
  tests, полный Flutter suite, analyzer и подписанный Android split release
  прошли; GitVerse release `android-v1.0.6` опубликован. Реальный Android RTT
  теперь подтверждён на Pixel 7; другие платформы и проверка со вторым участником
  остаются открыты —
  [QA-120](../evidence/flutter/qa120-voice-ping-compact-dock-2026-09-29-001.json).
- [x] Добавить в постоянный voice dock start/stop демонстрации с тем же picker
  качества и источника, что и в voice viewer; блокировать запуск во время
  joining/reconnecting и переходных состояний публикации — локальная проверка
  [QA-55](../evidence/flutter/qa55-voice-dock-screen-share-control-2026-09-28-001.json).
  OS permission, публикация и stop должны быть приняты на физических устройствах
  в незакрытом P0 full-path пункте выше.
- [x] Вынести rail выбора трансляции из наложения на видеокадр под stage,
  выровнять stream cards с web и показывать selected/audio состояния с
  screen-reader подсказкой — [QA-37](../evidence/flutter/qa37-voice-viewer-rail-web-parity-2026-09-28-001.json).
- [ ] Проверить prejoin roster на реальном сервере с двумя аккаунтами: вход/выход,
  смену демонстрации, пятисекундную сверку и поведение при недоступности
  private presence. Web и Flutter получают roster через долгоживущий SSE-поток;
  подписанные webhook-события LiveKit запускают быстрый refresh, а серверная
  сверка каждые пять секунд защищает от пропущенного webhook. Каждый снимок
  повторно проверяет ACL и lease. **Новая production-находка (30.09.2026):** в браузере
  prejoin `SHARE_TEST` сначала показал «состав недоступен» и повторяющуюся ошибку,
  затем автоматическое обновление восстановилось и показало пустую комнату;
  пользователь ранее приложил такой же экран Flutter. Голос и микрофон в браузерной
  проверке не подключались. Новый Flutter regression test подтверждает локальный
  переход 503 → retry → успешный empty snapshot; live retry на устройстве и
  populated snapshot на обоих клиентах ещё проверить. Сопоставить ошибку с
  серверными и LiveKit логами; причина пока неизвестна —
  [QA-148](../evidence/flutter/qa148-production-prejoin-roster-recovery-2026-09-30-001.json).
  Текущая реализация использует один долгоживущий SSE-поток с heartbeat,
  сверкой roster каждые пять секунд и повторной проверкой cookie-сессии каждые 10 секунд;
  при отзыве сервер отправляет `session-expired`, которое обрабатывают web и
  Flutter. ADR-015 зафиксировал это решение. Focused backend (2 packages) и
  Flutter (8 tests) проходят; web typecheck, full suite (760 tests / 241 files)
  и production build проходят; PowerShell
  contract/spec verifiers недоступны. Это ещё не
  live/deployment acceptance и не доказывает устранение production причины —
  [QA-231](../evidence/backend/qa231-long-lived-voice-roster-sse-session-revalidation-2026-10-02-001.json).
  Локальные unit suites проходят, но
  доставка событий, приватность между двумя аккаунтами и disconnect/reconnect
  на production ещё не проверены —
  [QA-18](../evidence/flutter/qa18-prejoin-voice-roster-2026-09-27-001.json),
  [QA-134](../evidence/flutter/qa134-realtime-voice-roster-screen-thumbnails-2026-09-30-001.json),
  [QA-136](../evidence/flutter/qa136-untrusted-commit-review-and-regression-2026-09-30-001.json).
- [x] Выравнять срок жизни prejoin roster после обрыва SSE: Flutter теперь
  сохраняет последний snapshot до 10 секунд с disconnect/error (как web),
  отменяет stale timer при следующем snapshot и очищает snapshot после таймаута.
  Два test-first state regressions, все 328 Flutter-тестов, analyzer, Android
  Debug APK и macOS Debug app прошли —
  [QA-174](../evidence/flutter/qa174-flutter-roster-sse-stale-snapshot-2026-10-01-001.json).
  Live reconnect/production roster acceptance и Windows runtime остаются открытыми.
- [x] Добавить безопасные server-side метрики стадии сбоя roster snapshot:
  `visibility_initial`, `presence_snapshot`, `visibility_recheck`; неизвестные
  labels сворачиваются в `unknown`, текст ошибки и IDs не попадают в labels.
  Полный Go suite и `go vet ./...` прошли —
  [QA-173](../evidence/backend/qa173-roster-failure-stage-observability-2026-10-01-001.json).
  Для подтверждения первопричины наблюдавшегося production сбоя требуется
  deployment с этой метрикой и новый отказ; ACL/privacy/live roster acceptance
  остаются открытыми.
- [x] Ограничить initial SSE roster snapshot тем же 5-секундным context timeout,
  что и invalidation-triggered snapshots. До исправления regression подтверждал,
  что initial `Lister.List` получал unbounded request context; после исправления
  полный backend suite и `go vet ./...` проходят —
  [QA-175](../evidence/flutter/qa175-voice-roster-initial-snapshot-timeout-2026-10-01-001.json).
  Production error correlation/recovery и two-account acceptance остаются открытыми.
- [x] Не терять roster invalidation, приходящий во время загрузки исходного SSE
  snapshot: подписываться до ACL-проверенного чтения и затем сразу перечитывать
  roster по накопленному событию. Новый тест сначала воспроизводит timeout на
  старом порядке, затем проходит после исправления; package race detector и
  полный backend suite проходят —
  [QA-137](../evidence/flutter/qa137-realtime-roster-initial-snapshot-race-2026-09-30-001.json).
- [x] Не открывать второй roster `EventSource` при первом `CONNECTED` отдельного
  workspace WebSocket: начальный SSE уже запускается при mount. При последующем
  восстановлении WebSocket roster по-прежнему принудительно обновляется, а
  повторный `start()` того же менеджера не создаёт второй EventSource.
  Зафиксировано test-first; полный frontend suite (680 тестов), TypeScript
  проверка и production build проходят —
  [QA-144](../evidence/flutter/qa144-web-roster-sse-initial-reconnect-2026-09-30-001.json).
  Поведение изменено по [ADR-015](adr/ADR-015-long-lived-voice-roster-sse.md):
  один долгоживущий SSE-поток с heartbeat и повторной проверкой сессии каждые
  10 секунд; при отзыве сессии клиенты закрывают поток через событие
  `session-expired`.
- [x] Синхронизировать канонический roster contract: описать authenticated
  long-lived SSE endpoint и обязательный `microphone_muted`, а web/Flutter
  клиенты должны отвергать снимки без этого состояния вместо ложного fallback
  «микрофон выключен». OpenAPI field/path assertions и focused/full client tests
  проходят; PowerShell verifier локально недоступен —
  [QA-138](../evidence/flutter/qa138-voice-roster-contract-sync-2026-09-30-001.json).
- [x] Реализовать безопасные превью демонстраций без LiveKit DataPackets и
  расширения `CanPublishData`: web и Flutter берут ограниченный JPEG из уже
  опубликованной/временно подписанной screen-video дорожки; одновременно
  захватывается не более одного скрытого preview на комнату, временная подписка
  очищается при завершении/ошибке, а выбранный viewer сохраняет свою подписку.
  Web локальное превью обновляется не чаще раза в 4 секунды; превью остаётся
  до unpublish/disconnect. Тесты покрывают размер/сигнатуру, capture deadline,
  cleanup, очередь, reconnect и гонки выбора viewer — [QA-165](../evidence/flutter/qa165-web-screen-thumbnail-receiver-capture-2026-10-01-001.json),
  [QA-167](../evidence/flutter/qa167-flutter-preview-subscription-race-2026-10-01-001.json),
  [QA-168](../evidence/flutter/qa168-web-preview-selection-during-capture-2026-10-01-001.json),
  [QA-169](../evidence/flutter/qa169-screen-thumbnail-cross-client-source-and-test-audit-2026-10-01-001.json).
  Сохранить `CanPublishData=false` согласно [ADR-013](adr/ADR-013-room-scoped-screen-thumbnail-preview.md).
- [ ] Провести paired runtime acceptance thumbnail на Android→macOS и Android→web;
  отдельно проверить остановку/очистку, повторный выбор того же viewer и отсутствие
  лишней подписки/помехи голосу. Android app-only capture с локальным thumbnail
  на Pixel 7 подтверждён отдельно — [QA-189](../evidence/flutter/qa189-pixel7-android-app-only-local-preview-2026-10-01-001.json);
  связка Android→Mac/web и runtime-проверка Windows остаются открытыми. Исходные
  Android и Flutter pipeline записи — [QA-159](../evidence/flutter/qa159-android-screen-thumbnail-buffer-2026-09-30-001.json),
  [QA-166](../evidence/flutter/qa166-flutter-temporary-screen-subscriptions-2026-10-01-001.json).
  Для Android app-only capture добавлено чтение фактического размера содержимого
  через MediaProjection resize callback — [QA-184](../evidence/flutter/qa184-android-app-window-capture-resize-2026-10-01-001.json);
  физический Pixel capture прошёл, но отображение самих пикселей thumbnail ещё
  нужно визуально подтвердить.
  Локальный Android `captureFrame()` теперь возвращает ошибку после пяти секунд,
  если MediaProjection не выдала кадр; native sink снимается, атомарное завершение
  не допускает двойного ответа, а очередь thumbnail может повторить захват —
  [QA-186](../evidence/flutter/qa186-android-local-preview-frame-timeout-2026-10-01-001.json).
  На Pixel 7 (Android 17) app-only runtime test с Google Calculator прошёл на
  установленной версии 1.0.18+2023: MediaProjection записывала выбранную задачу,
  локальный capture pipeline вернул `captured`, микрофон оставался выключен,
  трансляция и голосовое подключение после теста остановлены —
  [QA-189](../evidence/flutter/qa189-pixel7-android-app-only-local-preview-2026-10-01-001.json).
  Исходный симптом не воспроизвёлся на этой версии; визуальная сверка пикселей,
  другой целевой app и paired remote viewer macOS/web остаются открытыми.
  На текущем source повторно исполнены все 14 Android WebRTC lifecycle tests;
  они проходят. Свежий read-only ADB snapshot показывает Pixel 7 на launcher без
  активного MediaProjection, поэтому это не runtime-приёмка и paired test остаётся
  открытым — [QA-220](../evidence/flutter/qa220-android-screen-preview-lifecycle-current-head-2026-10-02-001.json).
  Исправлен UX edge case локального viewer: запуск собственного screen share
  теперь возвращает выбор с удалённой демонстрации или закрытого viewer на
  собственный экран; policy/widget tests и analyzer проходят. Проверка видео
  на физическом Android остаётся частью paired runtime acceptance.
- [x] Устранить повторяющийся macOS crash при получении видеокадров: два отчёта
  `EXC_BAD_ACCESS` в `FlutterRTCVideoRenderer` указывают на dereference `weakSelf`
  после удаления renderer. Добавлены nil guard и test-first regression; все 17
  тестов `flutter_webrtc` и macOS Debug build прошли. Повторный Pixel→Mac live
  test после фикса остаётся открытым — [QA-162](../evidence/flutter/qa162-macos-webrtc-renderer-dispose-race-2026-09-30-001.json).
- [x] Выровнять active voice participant grid с CSS `auto-fill/minmax(160px, 1fr)`:
  вычислять число колонок по доступной ширине, сохранять 176 px минимальную высоту,
  web-порядок карточки и 64 px avatar; добавить screen-share badge и доступную кнопку
  просмотра, не теряя Material touch target. Android portrait и desktop resize,
  Flutter suite/analyzer, Android и macOS debug builds прошли — [QA-65](../evidence/flutter/qa65-active-voice-grid-web-parity-2026-09-28-001.json).
- [x] Синхронизировать desktop search drawer Vue и Flutter: 360 px при 1280–1439
  и 400 px от 1440; широкий voice stage остаётся 320 px modal. CSS contract,
  Flutter widget tests, полный web suite и production build прошли —
  [QA-61](../evidence/flutter/qa61-search-drawer-width-parity-2026-09-28-001.json).
- [x] По умолчанию искать в активной TEXT/DM-беседе, как в Vue `SearchPanel`; из VOICE
  или без активной текстовой беседы оставлять область «Все беседы». Покрыты все три
  контекста search widget tests и Flutter analyzer —
  [QA-115](../evidence/flutter/qa115-search-scope-web-parity-2026-09-29-001.json).
- [x] Держать polite live status поиска видимым при найденных результатах и во время
  следующей загрузки; объявлять число строк и пустое состояние как в web. Workspace
  suite и Flutter analyzer прошли —
  [QA-116](../evidence/flutter/qa116-search-live-status-web-parity-2026-09-29-001.json).
- [x] Отключать «Найти» при пустом запросе и не запускать поиск клавишей Enter, пока
  запрос не заполнен, как `SearchPanel.canSubmit` в web; покрыто widget test и analyzer —
  [QA-117](../evidence/flutter/qa117-search-submit-web-parity-2026-09-29-001.json).
- [ ] Сравнить search на matched screenshots в текстовом и голосовом контекстах;
  точная визуальная/device-приёмка остаётся открытой.
- [x] Реализовать FE-52: ограниченные анонимные Android sender encoded FPS/bitrate/RTT;
  расчёты, API и подписанный APK прошли локальную проверку — [QA-19](../evidence/flutter/qa19-android-sender-metrics-2026-09-27-001.json).
- [x] Добавить bounded фактические размеры закодированного кадра в анонимные
  sender/receiver reports и admin diagnostics; исходный screen-share clipping
  теперь можно сопоставлять по размерам на Android sender и web peers —
  [QA-50](../evidence/flutter/qa50-screen-share-frame-dimensions-2026-09-28-001.json).
- [x] Изолировать sender-stats busy lock по поколению screen-share track: поздний
  `getSenderStats()` старой демонстрации не должен удерживать lock новой. Два
  generation-gate regression tests, полный suite из 278 Flutter-тестов и analyzer
  проходят; Android ABI Release и GitVerse Windows Release CI #1688448 также
  успешны — [QA-142](../evidence/flutter/qa142-screen-share-metrics-generation-race-2026-09-30-001.json).
- [ ] На устройстве подтвердить остановку отчётов при OS share stop/leave/disconnect
  и сопоставить sender с двумя receiver snapshots в QA-07. Физическая
  остановка/немедленный restart и два receiver остаются открыты —
  [QA-142](../evidence/flutter/qa142-screen-share-metrics-generation-race-2026-09-30-001.json).
- [x] Отправлять bounded screen-share telemetry из Flutter: sender с Android/
  macOS/Windows и receiver выбранной удалённой трансляции каждые 5 секунд через
  тот же authenticated endpoint; локальный предпросмотр не отправляется,
  receiver reporting приостанавливается в фоне. Full Flutter suite (299 tests),
  analyzer, macOS Debug, Android Debug APK и GitVerse Flutter Windows CI (tests,
  analyzer, Windows Release) прошли; повторная сверка web/Flutter/backend путей —
  [QA-157](../evidence/flutter/qa157-stream-statistics-reporting-audit-2026-09-30-001.json),
  [QA-158](../evidence/flutter/qa158-stream-metrics-web-panel-2026-09-30-001.json).
- [x] Считать `presented_fps` отдельно от `decoded_fps` во Flutter: разбирать
  native inbound `framesRendered`, рассчитывать дельту счётчика и отправлять
  только bounded FPS; LiveKit model parser, report payload и regression покрыты
  тестами по W3C-семантике счётчика — [QA-157](../evidence/flutter/qa157-stream-statistics-reporting-audit-2026-09-30-001.json),
  [QA-158](../evidence/flutter/qa158-stream-metrics-web-panel-2026-09-30-001.json).
- [ ] Проверить реальную доставку Flutter sender и двух receiver отчётов на
  Android/macOS/Windows, наличие `framesRendered` в native stats, stop/restart
  и admin snapshot — [QA-157](../evidence/flutter/qa157-stream-statistics-reporting-audit-2026-09-30-001.json).
- [x] Устранить Android screen-share retry leak: публиковать созданный track под
  контролем клиента, очищать его при publish failure, снизить Android профиль
  до 720p/15 FPS и сохранять текст исходной ошибки — [QA-23](../evidence/flutter/qa23-android-ime-screen-share-2026-09-27-001.json).
- [ ] На Samsung с Gboard проверить ввод нескольких символов в логине без
  закрытия IME; на Android проверить разрешение, успешную публикацию, stop и
  повторный запуск screen share с удалённым участником. Обрезка receiver-side
  воспроизведена в web на Pixel 7 (576×1280, в кадре видна только верхняя часть);
  найденное CSS intrinsic-minimum исправлено и прошло regression test/build.
  Проверка всех production stylesheet правил 2026-09-30 подтвердила доставку
  fix с `min-width: 0; min-height: 0`; live share должен подтвердить все четыре
  края. Отдельно
  сравнить portrait/landscape кадр в Flutter receiver и проверить повторный запуск
  screen share [QA-132](../evidence/flutter/qa132-browser-android-screen-share-crop-2026-09-29-001.json).
  Для проверки добавлен
  Android single-layer publish fallback; сравнить кадр, разрешение, FPS и bitrate
  у двух зрителей и подтвердить приемлемую нагрузку сети [QA-25](../evidence/flutter/qa25-android-screen-share-receiver-clipping-2026-09-27-001.json).
  Encoder wrapper теперь сравнивает ширину и высоту с настройками и адаптирует
  height-only resize; JVM test и release APK 1.0.1+4 прошли. Это не закрывает
  исходную обрезку без проверки устройства и двух зрителей —
  [QA-93](../evidence/flutter/qa93-android-encoder-height-resize-2026-09-29-001.json).
  Локальный IME regression test дополнительно сохраняет ввод следующего символа
  через тот же text-input connection после двух перестроений; физическая Samsung
  проверка остаётся открытой — [QA-51](../evidence/flutter/qa51-android-ime-multichar-regression-2026-09-28-001.json).
- [ ] Воспроизвести ошибку входа `PlatformException` на Android/Samsung и
  установить точный источник по sanitized logcat. Auth UI теперь показывает
  ограниченные code/message, скрывает credential-like значения и не выводит
  plugin `details`; эта диагностика покрыта локально, но реальный вход и причина
  сбоя не подтверждены — [QA-59](../evidence/flutter/qa59-android-auth-platform-exception-diagnostics-2026-09-28-001.json).
- [ ] На Android 14+ установить свежий release APK и повторить MediaProjection:
  на Pixel 7 Android 17/API 37 APK, обновлённый тем же сертификатом, прошёл
  full-screen capture с `FOREGROUND_SERVICE_MEDIA_PROJECTION` и сервисом
  `mediaProjection`; app-level stop снимает проекцию. Не проверены receiver и
  OS-level stop. Лишний
  plugin-added `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` удалён из merged release
  manifest и проверен в [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
  Проверка receiver и OS-level stop остаётся открытой — [QA-26](../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
- [x] Добавить web-аналог закреплённой удалённой демонстрации: мини-плеер
  остаётся поверх другого канала, личных сообщений и панелей workspace; его
  можно вернуть в voice-viewer, заглушить только для текущего просмотра или
  остановить. Состояние изолировано ID активного voice-канала, локально
  проверены 231 Flutter-тест и analyzer — [QA-94](../evidence/flutter/qa94-pinned-screen-mini-player-web-parity-2026-09-29-001.json).
- [x] Синхронизировать завершение закреплённой трансляции с web: при удалении
  screen-share publication закрыть mini-player, оставить ended-состояние в
  открытой voice-комнате, не путать отсутствующий видеокадр с завершённой
  публикацией — [QA-95](../evidence/flutter/qa95-pinned-screen-ended-lifecycle-2026-09-29-001.json).
- [x] Выровнять layering mini-player: он находится над содержимым, но под
  scrim/drawers/search overlays, недоступен по фокусу и accessibility tree при
  открытом drawer, а на Android располагается над voice dock — [QA-96](../evidence/flutter/qa96-pinned-screen-overlay-layering-2026-09-29-001.json).
- [x] Не запрашивать Android battery-optimization exemption: удалить
  неиспользуемое plugin-added разрешение из итогового APK, оставив разрешения
  foreground MediaProjection service — [QA-56](../evidence/flutter/qa56-android-battery-permission-minimization-2026-09-28-001.json).
- [x] Добавить выбор screen-share resolution `720/1080/1440p` и `15/30/60 FPS`,
  собственный оформленный picker для экранов/окон с preview, обновлением списка
  и явными error/empty/retry состояниями; Android получает мобильный вариант
  настройки качества; исправить перенос значений качества в узком Android
  портрете — [QA-24](../evidence/flutter/qa24-screen-share-quality-picker-2026-09-27-001.json),
  [QA-31](../evidence/flutter/qa31-android-share-quality-compact-layout-2026-09-27-001.json).
- [x] Убрать Android-specific инструкцию с экрана выбора качества; обязательное
  системное MediaProjection-подтверждение остаётся, iOS-сообщение об ограничении
  app-only захвата сохранено, а режим изменения качества не показывает setup
  guidance — [QA-190](../evidence/flutter/qa190-android-screen-share-quality-copy-2026-10-01-001.json).
- [x] Применять выбранный Android resolution profile к RTP encoder, а не только
  подписывать трек выбранным профилем: MediaProjection track metadata содержит
  фактический source size, sender получает aspect-preserving scale cap с чётными
  output edges; unit tests и Android release сборка — [QA-88](../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).
- [x] Ограничивать длинную сторону полноэкранного ScreenCaptureKit output на
  macOS 13+ по выбранному 720/1080/1440p профилю, сохраняя aspect ratio и чётные
  размеры кадра; macOS Release build, codesign integrity, 225 тестов и analyzer
  прошли — [QA-89](../evidence/flutter/qa89-macos-screen-share-profile-cap-2026-09-29-001.json).
- [x] Применить выбранный resolution cap в macOS window capture/macOS 12 fallback
  через frame processor, а в Windows — через выбранные source preview dimensions
  и LiveKit encoder scale. macOS Release build, Windows profile tests и source
  race tests прошли; runtime sender dimensions/FPS и отсутствие crop остаются
  открытыми — [QA-90](../evidence/flutter/qa90-windows-screen-share-profile-cap-2026-09-29-001.json),
  [QA-92](../evidence/flutter/qa92-macos-legacy-and-window-screen-share-profile-cap-2026-09-29-001.json).
- [x] Проверить picker на минимальной Android-ширине 320 dp: обе настройки качества
  достижимы прокруткой, а закреплённая кнопка запуска остаётся видимой; все пять
  screen-share тестов проходят — [QA-76](../evidence/flutter/qa76-android-screen-share-picker-320dp-2026-09-28-001.json).
- [x] Native desktop `getDisplayMedia` теперь проверяет результат `Start()`;
  при `CS_FAILED` возвращает ошибку и очищает video/audio tracks и stream,
  тот же rollback очищает loopback только текущего запроса при отсутствующем
  источнике или ошибке создания video capturer/source/track, не останавливая
  чужую активную аудиодорожку;
  вместо «успешного» чёрного трека. Flutter показывает исходное platform
  message, а не `PlatformException(...)`; GitVerse Windows tests/analyzer и
  Release compile прошли. Runtime failure injection остаётся открытой —
  [QA-98](../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json),
  [QA-103](../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json).
- [ ] На GitVerse Windows runner, где Release-сборка теперь проходит, проверить
  захват выбранных screen/window sources, включая свёрнутое/недоступное окно;
  проверить обновления preview и отсутствие чёрного трека; также вызвать stale
  source, video capturer/source/track creation и `CS_FAILED` после старта
  loopback audio, убедившись, что текущий запрос очищен, посторонняя активная
  дорожка не остановлена и повторный запуск не дублирует ресурсы. Runtime Windows C++
  capture остаётся непроверенным — [QA-98](../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json),
  [QA-103](../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json),
  [QA-81](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json).

## P1 — Каналы и навигация

- [x] При первой загрузке топологии автоматически открывать первый текстовый
  канал в порядке категорий, как это делает Flutter; не менять действующий
  выбор канала или личную переписку. Если выбранный канал исчез, очистить его и
  перейти к первому доступному текстовому каналу — регрессия, полный frontend
  suite (681 тест) и production build пройдены —
  [QA-145](../evidence/flutter/qa145-web-default-text-channel-2026-09-30-001.json).
- [x] Ограничить текстовую колонку карточки участника и обрезать длинный логин
  многоточием; длинное отображаемое имя переносится максимум на две строки,
  как в Flutter. Регрессионный тест и полный frontend suite (682 теста),
  production build пройдены —
  [QA-146](../evidence/flutter/qa146-web-member-popover-long-login-2026-09-30-001.json).
- [x] Показывать версию и номер сборки до входа и в настройках профиля, чтобы их
  можно было сообщить при диагностике; значение сверяется тестом с `pubspec.yaml`.
  Android release `1.0.14 (19)` подготовлен; публикация APK заблокирована таймаутом
  GitVerse release API —
  [QA-147](../evidence/flutter/qa147-android-visible-app-version-2026-09-30-001.json).

## P1 — Admin и переписка

- [ ] Проверить administrator REST ACL на работающем backend: роль, блокировка, topology, reset-link, voice kick и audit через два аккаунта.
- [x] Согласовать отправку TEXT/DM с мобильной клавиатурой: показывать action `Send` и отправлять по `onSubmitted`; аппаратный `Shift+Enter` не запускает отправку. Flutter widget-тесты покрывают action отдельно для TEXT/DM и shortcut guard; полный suite/analyzer — [QA-156](../evidence/flutter/qa156-flutter-composer-soft-keyboard-send-2026-09-30-001.json). Widget harness не моделирует реальную вставку новой строки от клавиши, поэтому многострочный ввод и Gboard/Samsung остаются в device acceptance QA-13.
- [x] Пометить общие ошибки загрузки TEXT/DM и voice ролью
  `SemanticsRole.alert`, как web `role="alert"`: до исправления Flutter отдавал
  `SemanticsRole.none`, а не alert. Focused-тест проверяет именно роль, не факт
  устного объявления — полный Flutter suite и analyzer проверены; см.
  [QA-155](../evidence/flutter/qa155-conversation-error-live-alert-parity-2026-09-30-001.json).
  В Windows/macOS Flutter engine alert-транслируется в платформенное alert event;
  для Android добавлен отдельный polite live-region дочернего текста, поскольку
  bridge не превращает alert role в live-region. Android debug APK собран;
  GitVerse Windows CI run 1690633 прошёл tests, analyzer и Release build для
  tree, содержащего этот fix;
  фактическое объявление TalkBack и отличие polite от web assertive остаются
  непроверенными. VoiceOver/NVDA и focus также требуют device acceptance.
- [ ] Проверить серверную очистку `UNATTACHED` вложений через 24 часа и восстановление после сбоя на реальном deployment; клиентского DELETE-контракта нет. Пройти live 507/partial-upload UX на TEXT/DM и устройствах.
- [x] Для macOS sandbox разрешить запись только в выбранный пользователем путь,
  поскольку скачивание вложения пишет байты после `NSSavePanel`; сохранить
  `app-sandbox` и не запрашивать общий доступ к файлам. Debug/Release entitlements
  теперь указывают `user-selected.read-write`, формат валиден, Release bundle
  universal и ad-hoc signature проходит проверку. Реальное сохранение из UI и
  notarized/Developer ID distribution остаются непроверенными.
- [ ] Проверить edit/delete 409 и idempotent send retry с реальным backend и физическим устройством, включая удаление во время редактирования и смену диалога.
- [ ] Проверить reply context, pagination/scroll anchoring и read cursors на границах страниц и при realtime updates.
  - [x] Для TEXT сохранить экранную позицию видимого сообщения при добавлении cursor-страницы сверху и не откатывать read cursor на старые сообщения. Тест сначала воспроизвёл сдвиг строки за пределы viewport; исправлено сохранением ключей/координат видимых строк при reindex sliver. Focused regression, workspace suite (51 тест), полный Flutter suite (329 тестов) и analyzer прошли — [QA-177](../evidence/flutter/qa177-text-history-scroll-anchor-2026-10-01-001.json). Reply через границы страниц и realtime/backend acceptance остаются открыты.
  - [x] Для DM применить то же сохранение экранной позиции и курсора при подгрузке предыдущей страницы. Test-first regression воспроизвёл пропажу исходной строки из viewport; после keyed reindexing и восстановления координаты full Flutter suite (332 теста), analyzer, подписанные Android split APK (v2) и macOS Debug build прошли — [QA-178](../evidence/flutter/qa178-dm-history-scroll-anchor-2026-10-01-001.json). Windows compile/runtime, reply через ещё не загруженные страницы и realtime/backend acceptance остаются открыты.
  - [x] Flutter realtime refresh для TEXT теперь объединяет новую страницу с уже загруженными, не сбрасывая историю и исчерпанный курсор; `connection.resync_required` использует тот же путь. Regression покрывает добавление realtime-сообщения после загрузки старой страницы — [QA-179](../evidence/flutter/qa179-text-realtime-history-merge-2026-10-01-001.json). Серверная realtime-проверка и поведение reply через ещё не загруженные страницы остаются открыты.
  - [x] Защитить загрузку TEXT-истории от устаревших async-ответов при смене канала, DM, search context, сервера или сессии; ранее зависший `loadingMessages` воспроизведён тестом при realtime-refresh, за которым следовал переход в VOICE, и устранён generation gate на текущей загрузке — [QA-180](../evidence/flutter/qa180-text-history-navigation-race-2026-10-01-001.json). Полный Flutter suite (334 теста) и analyzer прошли.
  - [x] Reply preview теперь открывает контекст целевого сообщения, даже если оно находится за пределами загруженной TEXT/DM-страницы; уже загруженная цель прокручивается на место, для старой используется bounded `at` context и возврат к последним сообщениям. Test-first TEXT regression и DM regression, полный Flutter suite (336), analyzer, frontend suite (710), web production build и macOS/Android Debug builds прошли — [QA-181](../evidence/flutter/qa181-reply-context-unloaded-history-2026-10-01-001.json). Живая проверка backend/read cursor, устройств и Windows остаётся открытой.
  - [x] Добавить web regression coverage для общей навигации в TEXT/DM: загруженная цель прокручивается, незагруженная (или временно недоступный список) передаётся в bounded context. Test-first, три focused проверки, frontend suite (713) и production build прошли — [QA-182](../evidence/flutter/qa182-web-reply-context-navigation-2026-10-01-001.json). Реальная browser viewport и live backend acceptance остаются открытыми.
- [x] Сохранять несданный TEXT/DM черновик при переключении бесед и восстановить
  тело, ответ, упоминания и уже загруженные вложения отдельно по аккаунту;
  очищать память при logout/session expiry. Service isolation/clear и TEXT
  channel-switch покрыты тестами; полный Flutter suite и analyzer прошли —
  [QA-71](../evidence/flutter/qa71-composer-draft-memory-web-parity-2026-09-28-001.json).
  Проверить restore на реальном Android/desktop и уточнить поведение после
  перезапуска остаётся открытым (как в web — черновики только в памяти).
- [x] Реализовать native opt-in notifications для macOS, Windows и Android: generic preview без текста сообщения, разрешения ОС, foreground suppression, рост unread-счётчика и event deduplication, отдельная настройка на аккаунт — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [x] Устранить Android `PlatformException(invalid_icon)` в настройках профиля: инициализировать notifications через отдельную монохромную drawable-иконку, сохранить её при resource shrinking и проверить наличие ресурса в release APK — [QA-75](../evidence/flutter/qa75-android-profile-notification-icon-2026-09-28-001.json). Проверка фактического системного уведомления на Samsung остаётся открытой ниже.
- [ ] Проверить системное разрешение/отказ, доставку в фоне и deduplication на реальном macOS; Windows toast/AppUserModelID на Windows runner; Android 13+ prompt и background delivery на Samsung/Gboard. Локальные macOS release startup и Android debug build/merged permission прошли, но это не заменяет device acceptance — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [ ] Сверить нативный защищённый просмотр изображений TEXT/DM с DES-09; проверить ACL, loading/error/deleted состояния, масштабирование и отдельное скачивание на deployment и устройствах.
- [x] Добавить доступное имя маршрута защищённого просмотрщика и alt-текст изображения, совпадающие с именем вложения; regression test проверяет оба accessibility metadata поля — [QA-105](../evidence/flutter/qa105-protected-image-viewer-accessibility-2026-09-29-001.json). Реальная проверка VoiceOver/NVDA/TalkBack, возврата фокуса, ACL, скачивания и полного DES-09 остаётся открытой.
- [x] Синхронизировать desktop tooltip и screen-reader имя открытия/закрытия image viewer с web: «Открыть изображение …» и «Закрыть просмотр изображения»; regression tests проверяют tooltip и доступное имя — [QA-106](../evidence/flutter/qa106-protected-image-viewer-copy-2026-09-29-001.json). Фактическое поведение hover и screen readers на нативных платформах остаётся открытым.
- [x] Проверить keyboard-поведение image viewer: Tab остаётся в модальном route, Escape закрывает его, а фокус возвращается к исходной кнопке preview — [QA-107](../evidence/flutter/qa107-protected-image-viewer-focus-2026-09-29-001.json). OS screen-reader acceptance остаётся открытой.
- [x] При открытии viewer сразу переводить keyboard focus на «Закрыть просмотр изображения», как web `closeButton.focus()`; regression test проверяет первый focus target до нажатия Tab — [QA-108](../evidence/flutter/qa108-protected-image-viewer-initial-focus-2026-09-29-001.json). Реальное platform screen-reader поведение остаётся открытым.
- [x] Объявлять loading и unavailable/deleted состояния image viewer как отдельные polite live regions, не поглощая доступную кнопку retry; regression test проверяет `liveRegion` и текст статуса — [QA-109](../evidence/flutter/qa109-protected-image-viewer-live-status-2026-09-29-001.json). Нативные объявления TalkBack/VoiceOver/NVDA проверить на устройствах.
- [x] Реализовать native image clipboard support в Flutter TEXT/DM через нативный clipboard plugin, scoped queue, plain-text fallback, retry/лимиты и attachment-only отправку — [FE-56](../backlog/FRONTEND_TODO.md), [QA-22](../evidence/flutter/qa22-native-clipboard-image-paste-2026-09-27-001.json). Фактическая вставка и Windows-native build всё ещё требуют platform acceptance.
- [x] Сгруппировать выбор файла и вставку из буфера под компактной кнопкой `+` в composer для TEXT/DM; оставить `@` как отдельное компактное действие упоминания. Widget tests и Pixel 7 UI acceptance подтвердили оба пункта меню, размещение и сохранение mention/send controls — [QA-127](../evidence/flutter/qa127-flutter-composer-action-menu-2026-09-29-001.json). Matched screenshots, keyboard traversal и paste acceptance на macOS/Windows остаются открытыми.

## P2 — Visual, keyboard и accessibility

- [x] Централизовать оставшиеся web design tokens во Flutter theme: семантические
  цвета/контраст, Material ColorScheme, typography/line-height, радиусы, размеры,
  motion и elevation; добавить отсутствовавшую высоту voice-member row в CSS и
  Flutter и исправить несуществующий `--gc-surface-base` в web rail —
  [QA-97](../evidence/flutter/qa97-flutter-web-design-token-parity-2026-09-29-001.json).
  Общий matched-screenshot/device gate остаётся открытым.
- [x] Выровнять профиль по web CSS: centered 720 px content, 480 px form, 64 px avatar, responsive 24/16 px insets, 16 px page title, section dividers и toolbar без дублированного заголовка; clients/flutter/mobile геометрия и route покрыты widget tests — [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json).
- [x] Выровнять maintenance banner по web CSS: минимум 44 px, текст 14/20 px,
  поля 12/16 px и естественный перенос без обрезания; clients/flutter/mobile viewport
  проверены виджет-тестами —
  [QA-41](../evidence/flutter/qa41-maintenance-banner-web-geometry-2026-09-28-001.json).
  Matched screenshots на реальных платформах остаются в общем screenshot gate.
- [x] Сгруппировать список участников по статусу online/offline/unknown и показывать
  количество в заголовке каждой группы как в web; проверено виджет-тестом
  [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json).
- [x] Добавить web-эквивалентные loading/error/retry для списка участников
  [QA-27](../evidence/flutter/qa27-member-presence-groups-2026-09-27-001.json).
- [x] Применять guild presence snapshot/change к списку и сбрасывать статусы
  в unknown при недоступности realtime, как в web
  [QA-28](../evidence/flutter/qa28-guild-presence-realtime-2026-09-27-001.json).
- [x] Заменить центрированный профиль участника на anchored popover с loading,
  error/retry, DM, same-voice volume и admin voice kick
  [QA-29](../evidence/flutter/qa29-member-profile-popover-2026-09-27-001.json).
- [x] Выровнять member profile popover с web CSS: responsive max-width aside,
  привязка к верху строки и правому отступу, 64 px violet fallback avatar,
  20 px имя, 40 px action и volume layout —
  [QA-34](../evidence/flutter/qa34-member-profile-popover-web-geometry-2026-09-28-001.json).
  Matched screenshots и визуальная приёмка на экранах остаются открытыми.
- [ ] Проверить live-переходы presence двумя аккаунтами на backend.
- [ ] Сохранить matched web/Flutter screenshots 1440×900, 1280×800, 1024×768 и Android portrait для auth, chat, DM, search, members, voice, screen share, profile, audio и admin; зафиксировать отличия по экранам. Profile widget tests теперь фиксируют точную max-width/inset geometry — [QA-49](../evidence/flutter/qa49-profile-geometry-web-parity-2026-09-28-001.json).
- [ ] Завершить focus trap/return и keyboard reachability для admin/profile/dialogs; responsive modal search и drawer traps, начальный/возвращаемый фокус реализованы. Открыты device screen-reader приёмка и matched screenshots.
  - [x] Screen-share setup explicitly keeps Tab/Shift+Tab focus within the open dialog; widget regression verifies both traversal edges, all 9 quality-picker tests and analyzer pass — [QA-183](../evidence/flutter/qa183-screen-share-dialog-keyboard-loop-2026-10-01-001.json). Other modal focus loops and physical screen-reader acceptance remain open.
  - [x] Destructive confirmations for message deletion, voice kick and admin topology actions match web modal behavior: backdrop taps do not dismiss, Tab traversal stays modal, Escape/Back cancels, and focus returns to the opener — [QA-185](../evidence/flutter/qa185-confirmation-dialog-web-parity-2026-10-01-001.json). Platform screen-reader acceptance remains open.
  - [x] Password-reset-link and server-address auth dialogs cannot be dismissed by an accidental backdrop tap, trap Tab traversal, cancel with Escape and return keyboard focus to the opener. The route owns its text controllers through the reverse transition so they are not disposed while text fields still listen — [QA-187](../evidence/flutter/qa187-auth-dialog-keyboard-lifecycle-2026-10-01-001.json). Platform screen-reader acceptance remains open.
  - [x] Authentication mode tabs can be reached and activated by keyboard; a widget regression moves focus with Tab, selects Registration with Space, and checks selected tab semantics — [QA-188](../evidence/flutter/qa188-auth-mode-tab-keyboard-2026-10-01-001.json). Physical keyboard and screen-reader acceptance remains open.
- [x] Возвращать keyboard focus к исходному элементу после закрытия настроек профиля, аудио или администрирования; регрессионный widget-тест проверяет переход фокуса на заголовок профиля и обратно к opener — [QA-63](../evidence/flutter/qa63-settings-panel-focus-return-2026-09-28-001.json).
- [x] При открытии admin панели переводить фокус на семантический заголовок «Администрирование», чтобы клавиатурная и screen-reader навигация сразу обозначала текущий раздел — [QA-64](../evidence/flutter/qa64-admin-heading-focus-accessibility-2026-09-28-001.json).
- [ ] Проверить responsive breakpoints, resize, accessibility labels и узкие layouts на macOS, Windows и Android. Android empty TEXT welcome теперь растёт и прокручивается на 320 dp вместо RenderFlex overflow — [QA-80](../evidence/flutter/qa80-android-empty-channel-320dp-2026-09-28-001.json); остальные viewport/device сравнения остаются открыты.
- [x] На Pixel 7 с gesture navigation проверены Android edge-свайпы от самого края: левый открывает каналы, правый участников; системный Back с обеих сторон работает за пределами центральной exclusion-зоны и не перехватывает drawer-жесты — [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json).
- [x] На Android system Back закрывает открытые navigation и members drawers, не сворачивая workspace; regression widget tests на Android/iOS и физическая проверка release APK на Pixel 7 — [QA-129](../evidence/flutter/qa129-android-workspace-drawer-system-back-2026-09-29-001.json).
- [x] На Pixel 7 физически открыть вкладки «Каналы»/«Личные», закрыть drawer системным Back, затем открыть members drawer свайпом справа и закрыть его Back; переписки и voice join не запускались — [QA-130](../evidence/flutter/qa130-pixel7-mobile-navigation-drawer-2026-09-29-001.json).
- [ ] На физических Android/iOS пройти полный объединённый mobile drawer (General с TEXT/VOICE, direct voice entry, переход в другой TEXT и возврат в DM) и полный набор dock gestures; проверенные Android tab/Back/members flows — [QA-129](../evidence/flutter/qa129-android-workspace-drawer-system-back-2026-09-29-001.json), [QA-130](../evidence/flutter/qa130-pixel7-mobile-navigation-drawer-2026-09-29-001.json); iOS swipe acceptance остаётся открытой — [QA-78](../evidence/flutter/qa78-android-ios-mobile-swipes-2026-09-28-001.json), [QA-79](../evidence/flutter/qa79-android-unified-channel-drawer-2026-09-28-001.json), [QA-125](../evidence/flutter/qa125-android-edge-swipe-navigation-2026-09-29-001.json).
- [x] Выровнять voice prejoin с web clamp-геометрией: viewport inset 24–72 px,
  desktop card padding 28–44 px и mobile 16×24 px; иконка и заголовок тоже
  используют web tokens. Narrow mobile regression test поймал и устранил
  overflow двухстрочного channel header — title/subtitle теперь ellipsis;
  macOS/Android debug builds, 186 Flutter tests и analyzer прошли —
  [QA-62](../evidence/flutter/qa62-voice-prejoin-responsive-web-parity-2026-09-28-001.json).
- [ ] Сравнить active/prejoin voice roster на matched screenshots при desktop
  breakpoints и Android portrait; проверить реальный список активных участников.
- [x] Исправить Android-скролл TEXT: медленный свайп от конца истории не должен
  прыгать обратно к последнему сообщению; автокорректировка привязана к смене
  истории, а Android-портретный виджетный тест двигает список короткими шагами
  и проверяет scroll offset — [QA-70](../evidence/flutter/qa70-android-text-scroll-2026-09-28-001.json).
  На Pixel 7 (Android 17) физически проверены медленный и быстрый свайп,
  сохранение позиции, загрузка предыдущей страницы и прокрутка с открытой
  Gboard; остаются короткая история и точные read-cursor updates.
- [x] Выровнять prejoin и navigation roster по вебовым размерам аватаров/текста,
  отступам и интервалам; синхронизировать FNV avatar palette и screen-share badge —
  [QA-36](../evidence/flutter/qa36-voice-roster-web-geometry-2026-09-28-001.json).
- [x] Выровнять приоритет статусов участников и speaking-индикаторы voice roster,
  strip и cards с `VoiceParticipantStatus.vue`; целевые тесты, analyzer и полный
  Flutter suite прошли — [QA-35](../evidence/flutter/qa35-voice-participant-status-web-parity-2026-09-28-001.json).
  Порядок, отступы, аватары и matched screenshots остаются открытыми.
- [x] Удерживать длинный статус полностью заглушённого участника по центру
  карточки в одну строку с многоточием; узкий Android portrait widget test,
  полный `workspace_screen_test.dart` (42 теста) и analyzer прошли —
  [QA-121](../evidence/flutter/qa121-deafened-participant-status-alignment-2026-09-29-001.json).

## P2 — Identity и delivery

- [x] Выровнять auth-card с вебом: eyebrow/title/copy, max-width 440 px,
  адаптивный 24–40 px padding, labels над полями и web-sized inputs/submit;
  сохранить нативные server/reset actions и стабильные focus nodes —
  [QA-42](../evidence/flutter/qa42-auth-layout-web-parity-2026-09-28-001.json).
  Android Gboard и matched screenshots остаются отдельной device-проверкой.
- [x] Заменить Material `SegmentedButton` на web-эквивалент auth tablist: 48 px
  outer control, 4 px inset/gap, 40 px tabs, selected colors и явные
  `tablist`/`tab` semantics; целевой auth suite и analyzer прошли —
  [QA-82](../evidence/flutter/qa82-auth-tabs-web-parity-2026-09-28-001.json).
  Matched screenshots остаются в общем visual gate.
- [x] Выровнять own-profile mutation с web/backend: display name валидируется по Unicode code points без trim/графемного maxLength, оба password поля используют диапазон 12–128, feedback объявляется как live region, при открытии focus переходит на семантический заголовок — [QA-48](../evidence/flutter/qa48-profile-mutation-validation-focus-web-parity-2026-09-28-001.json).
- [ ] Завершить оставшуюся auth/profile acceptance на Samsung/Gboard и реальных screen readers; matched screenshots и keyboard/focus проверка остаются открытыми.
- [x] Разделить password validation по режимам: login принимает любое непустое
  значение (как web/API), registration проверяет 12–128 Unicode code points по
  backend contract; проверены короткий существующий пароль и обе границы —
  [QA-43](../evidence/flutter/qa43-auth-password-validation-web-contract-2026-09-28-001.json).
  Полный Samsung/Gboard и экранный error/focus acceptance остаётся открытым.
- [x] Очищать предыдущую auth-ошибку при переключении между login и registration,
  как делает web `chooseMode`; переход покрыт widget test —
  [QA-44](../evidence/flutter/qa44-auth-mode-error-reset-2026-09-28-001.json).
- [x] Отделить сбой загрузки собственного профиля от общей ошибки workspace;
  показывать доступные loading/error live-region статусы как на web и снимать
  load error при успешном повторном запросе — [QA-45](../evidence/flutter/qa45-profile-loading-error-web-parity-2026-09-28-001.json).
- [ ] Настроить signed platform/domain association до обещания автоматического открытия password-reset URL.
- [x] Определить и реализовать native эквиваленты browser-only notification preferences; настройка не показывается на web/неподдерживаемых платформах и включает только generic previews — [QA-46](../evidence/flutter/qa46-native-notifications-web-parity-2026-09-28-001.json).
- [x] Собрать Android release APK с upload keystore и проверить APK Signature Scheme v2; извлечённые permissions содержат `POST_NOTIFICATIONS` и Android MediaProjection foreground service — [QA-47](../evidence/flutter/qa47-android-release-apk-signing-2026-09-28-001.json).
- [x] Подготовить публикацию Android APK в GitVerse Releases без бинарников в Git: release workflow собирает три ABI-варианта, каждый из локальной проверки меньше 95 MB; универсальный APK превышает GitVerse 100 MB asset limit — [QA-104](../evidence/flutter/qa104-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Добавить GitVerse repository secrets для API-публикации и Android upload keystore; tag-triggered workflow #1679869 завершился успешно и опубликовал все три ABI APK в [релизе android-v1.0.3](https://gitverse.ru/egkurilov/BOOHTACORD/releases/tag/android-v1.0.3). Установка и device acceptance остаются отдельной проверкой — [QA-104](../evidence/flutter/qa104-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Опубликовать Android `1.0.18` через GitHub Releases: tag workflow собрал и опубликовал все три подписанных ABI APK; наличие и размеры ассетов подтверждены GitHub Release API — [android-v1.0.18](https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/android-v1.0.18), [release evidence](../evidence/android/android-github-apk-delivery-2026-10-01-001.json). Старый пункт о `1.0.17` вытеснен этим выпуском; исторический timeout `1.0.14` оставлен только в evidence — [QA-158](../evidence/android/qa158-android-release-1.0.14-publish-timeout-2026-09-30-001.json).
- [x] Собрать и опубликовать Android v1.0.4 через tag-triggered GitVerse workflow; release содержит подписанные APK для `arm64-v8a`, `armeabi-v7a` и `x86_64`, бинарники не добавлены в Git. Физическая установка/device acceptance остаётся открытой — [QA-114](../evidence/flutter/qa114-gitverse-android-release-apks-2026-09-29-001.json).
- [x] Подготовить Android `1.0.5+9`: analyzer, все 253 Flutter-теста и три подписанных ABI APK прошли локальную проверку — [QA-118](../evidence/flutter/qa118-android-release-build-2026-09-29-001.json). Публикация GitVerse через tag `android-v1.0.5` и device acceptance остаются открытыми.
- [x] Убрать повторную safe-zone подгонку полноразмерного composite artwork: Android 8+ теперь отображает исходный рисунок на full-bleed adaptive background, а foreground прозрачен; pre-26 density mipmaps оставлены прежними. APK проверен `apksigner`, установлен поверх приложения на Pixel 7 без потери данных; в штатном круглом стиле лишней белой внутренней рамки нет — [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json).
- [x] Добавить Android adaptive monochrome `B` mark для themed launcher icons, сохранив обычный полноцветный знак без изменений; focused Flutter test и Android release APK/AAPT resource check прошли — [QA-133](../evidence/flutter/qa133-android-themed-launcher-icon-2026-09-29-001.json). Проверить themed rendering на Pixel 7 с включённой настройкой; acceptance установленной иконки macOS/Windows остаётся открытой — [QA-77](../evidence/flutter/qa77-android-adaptive-launcher-icon-2026-09-28-001.json).
- [x] Подтвердить GitVerse Windows x64 runner целиком: workflow run [1678418](../evidence/flutter/qa81-gitverse-windows-runner-ci-2026-09-29-004.json) прошёл tests, analyzer и Windows Release build. Запуск интерфейса и visual/device acceptance на Windows остаются открыты.
- [ ] Проверить подписанную macOS Release-сборку и Keychain persistence после перезапуска; на текущем Mac нет действительной Apple Developer identity. macOS Debug app и Android Debug APK собраны локально — [QA-30](../evidence/flutter/qa30-native-debug-builds-2026-09-27-001.json).
- [x] Временно отключить автоматические push/tag запуски macOS CI и macOS Release, пока GitVerse runner недоступен; ручной dispatch сохранён. Возобновить автозапуски после provision macOS runner.
- [ ] Сохранить защищённую копию Android upload JKS/credentials вне сборочного host; установить/обновить release APK на физическом Android и пройти QA-13.
- [x] Сделать Android CI regression gate для двух Gradle режимов и устранить
  конфигурационную несовместимость `flutter_background 1.3.1`: пакет vendored как
  локальный MIT fork без изменений Dart/native runtime, а его Android Gradle
  script применяет KGP только в legacy режиме. `tools/verify/android_kotlin/verify_android_kotlin_modes.sh`
  собирает Debug при текущем `android.builtInKotlin=false` и через Gradle с
  `android.builtInKotlin=true`; оба режима прошли. Signed Release также прошёл
  в обоих режимах: split APK для трёх ABI в legacy и universal APK в built-in
  режиме; APK v2 signatures проверены — [QA-172](../evidence/flutter/qa172-android-kotlin-build-modes-2026-10-01-001.json).
- [x] Убрать ложное предупреждение Flutter о KGP для `flutter_background`,
  `flutter_webrtc` и `livekit_client`: при выключенном built-in Kotlin локальные
  форки применяют KGP императивно через `pluginManager`, а в built-in режиме не
  применяют legacy plugin. Регрессионный gate теперь падает, если предупреждение
  возвращается; Debug обоих режимов и подписанные Release-сборки обоих режимов
  прошли локально. Три split ABI APK legacy и universal APK built-in проверены
  `apksigner` (v2); удалённый CI и device/runtime acceptance не проверялись,
  `android.builtInKotlin=false` оставлен значением по умолчанию —
  [QA-176](../evidence/flutter/qa176-android-kgp-warning-free-build-modes-2026-10-01-001.json).
