# macOS-клиент BOOHTACORD

Клиент macOS использует общий Flutter-код из [`clients/flutter/lib/`](../../clients/flutter/lib) и runner из [`clients/flutter/macos/`](../../clients/flutter/macos). Ручной GitHub Actions workflow на runner с метками `self-hosted`, `macos` запускает Flutter tests и analyzer, затем собирает Release для Apple Silicon и Intel. До регистрации GitHub runner запуск не подтверждён.

Для локального запуска:

```sh
cd clients/flutter
flutter pub get
flutter run -d macos --dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=screen_capture_kit
```

Xcode перед компиляцией Runner автоматически восстанавливает Sparkle 2.10.0 в `macos/Updaters` через [`sdk.py`](../../tools/build/desktop_updater/sdk.py) с проверкой SHA-256. Первая сборка требует доступа к GitHub; следующие используют локальный SDK, пока доступны бинарник, заголовок и маркер закреплённой версии. `flutter pub get` управляет Dart-зависимостями и отдельно Sparkle не устанавливает. При необходимости SDK можно подготовить заранее из корня репозитория: `python3 -m tools.build.desktop_updater.sdk macos`.

Релиз публикуется в GitHub через ручной запуск [macOS Release](../../.github/workflows/macos-release.yaml) от тега `macos-vX.Y.Z`, совпадающего с версией в [`clients/flutter/pubspec.yaml`](../../clients/flutter/pubspec.yaml). В релиз попадают ZIP с `BOOHTACORD.app` и файл SHA-256. Workflow использует встроенный `GITHUB_TOKEN` с правом `contents: write`.

Текущий workflow проверяет целостность ad-hoc подписи, но не подписывает Developer ID и не выполняет Apple notarization. Gatekeeper может запросить подтверждение запуска. Подписанная и notarized публикация требует отдельного Apple Developer signing setup и остаётся открытой приёмкой; наличие CI-сборки не подтверждает её.
