# Разработка iOS-клиента

iOS runner создан в существующем Flutter-проекте [`clients/flutter/`](../../../clients/flutter). Общие функции Android и iOS находятся в `clients/flutter/lib/`; iOS AppIcon сгенерирован из того же [`app_icon.jpg`](../../../clients/flutter/assets/branding/app_icon.jpg), что используется для Android/macOS/Windows. Web остаётся эталоном поведения; системные разрешения, компоновка и медиа проверяются на iPhone отдельно.

## Инструменты и сборка

Нужны macOS, Xcode, Flutter с iOS toolchain и физический iPhone для проверки медиа. Текущий Xcode-проект подключает Flutter-плагины через генерируемый Swift Package; в `clients/flutter/ios/` нет `Podfile`. [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) описывает настройку среды.

```bash
cd desktop
flutter pub get
flutter analyze
flutter test
flutter build ios --no-codesign
flutter build ios --release
```

Для подписи откройте `ios/Runner.xcworkspace` в Xcode и выберите свой Team в Runner → Signing & Capabilities. Bundle ID: `ru.boohtacord.app`. Локально использован Personal Team с бесплатной учётной записью Apple и автоматическим provisioning. Подписанная release-сборка позволяет запускать приложение с домашнего экрана; debug-сборку iOS 14+ нужно запускать из Xcode или Flutter tooling. Для повторной установки по кабелю можно использовать Xcode Run с конфигурацией Release либо `xcrun devicectl device install app --device <device-id> <path-to-Runner.app>` и `xcrun devicectl device process launch --device <device-id> ru.boohtacord.app`.

На данном Mac каталог `clients/flutter/` управляется FileProvider, который добавляет метаданные к build artifacts и может нарушать code signing. Локальный игнорируемый `clients/flutter/build` направлен в `~/Library/Caches/boohtacord-ios-build`; это настройка рабочей машины, не часть проекта. После `flutter build ios --release` подписанный `.app` находится в `build/ios/iphoneos/Runner.app` (промежуточный Xcode output — `build/ios/Release-iphoneos/Runner.app`). Не добавляйте provisioning profile, сертификаты или локальный build cache в Git.

## Платформенная реализация и открытые проверки

| Срез | Текущее состояние и критерий |
| --- | --- |
| Идентичность | Общий `ApiClient` и secure session cookie. На устройстве показан экран входа; login/logout, iOS Keychain, 401, CSRF/Origin и reset link требуют проверки на тестовом аккаунте и живом API. Не вводить bearer/OAuth и не ослаблять TLS. |
| Навигация | Общие Flutter-экраны собираются для iOS. Safe areas, клавиатура, VoiceOver, Dynamic Type, вложения и preview требуют физической приёмки. |
| Жесты | [Список свайпов](GESTURES.md) реализован в общем мобильном интерфейсе и покрыт widget-тестами. Ручная проверка на iPhone, включая конфликт с системными жестами и клавиатурой, остаётся открытой. |
| Realtime | В общем коде есть reconnect/dedupe и `resync_required`; durable `after` cursor ещё не передаётся. Нужно проверить privacy адресных DM событий и сохранение здорового voice call при reconnect. |
| Voice | `Info.plist` содержит описание доступа к микрофону и background audio. Фактическое разрешение, слышимость, маршруты, interruption, background/foreground и отзыв lease не проверены. |
| Screen viewing | Общий UI подписки на выбранный stream, fullscreen и diagnostics собран; first frame/FPS/звук на iPhone не проверены. |
| Screen publishing | Flutter/LiveKit использует in-app capture с iOS preset 720p/15. Диалог заранее объясняет, что другие приложения и системный звук не захватываются. Full-device capture потребует Broadcast Extension и App Group после отдельного решения. Фактический start/stop/revocation пока не проверен. [LiveKit guidance](https://docs.livekit.io/transport/media/screenshare/). |
| Уведомления | Локальные iOS-уведомления и запрос разрешения добавлены в общий сервис; доставка на физическом устройстве не проверена. Push notifications не входят в scope. |
| Администрирование | UI в общем Flutter-коде зависит от роли; серверный ACL остаётся обязательным. Сценарии ролей и отказа в доступе на iPhone не проверены. |

Публичный архив/IPA, TestFlight и App Store не создавались. До выпуска выполните [матрицу приёмки](ACCEPTANCE.md) и зафиксируйте отдельное продуктовое решение. Не добавляйте camera, recording, group DM, federation или собственный media proxy в рамках этого клиента; cookies, содержимое DM и media credentials не должны попадать в diagnostics/evidence.

## App and ScreenShareExtension version identity (#518)

`ScreenShareExtension/Version.xcconfig` reads Flutter's generated build name and
number. Debug/Release/Profile all use those values for the extension's marketing
version and build number, matching Runner. Do not leave the extension at build 1.
After exporting the signed distribution variant, verify the **actual IPA**:

```sh
python3 -m tools.release.ios_artifact.verify /absolute/path/BOOHTACORD.ipa \
  --application-id ru.boohtacord.app.test
```

The verifier requires exactly the application and approved screen extension,
both with the version/build from `contracts/client-build.json`. An archive/export
success for Runner alone does not establish extension metadata validity, upload
processing, TestFlight availability or physical ReplayKit acceptance. Keep the
existing two supplied provisioning profiles and shared App Group for this
distribution variant; never put profiles, private keys or passwords in Git.
