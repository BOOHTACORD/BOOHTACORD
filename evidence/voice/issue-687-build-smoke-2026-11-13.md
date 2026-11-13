# Issue 687: local client build smoke

Source: `e3a4d5753930f8a84624b4dcdc72f6871248f756`. These are local
build/start checks, not release acceptance. No server deployment occurred.

Windows: Flutter 3.47.7 `build windows --release --no-pub` passed with the
default research features disabled. The pinned Velopack SDK was prepared by the
project script; an existing Firebase C++ SDK 14.1.0 was reused. The EXE SHA-256
is `af42adf92011e395f6ba9027ec8ee1b66c8fb53d57ef597ffa6fb87af4cd2aed`.
Authenticode reports `NotSigned`. Packaging, installation, app launch, native
audio acceptance and a signed release were not performed by this build.

Android: the project debug build completed in a separate worktree, producing
an APK SHA-256 `8cf82af5801688174a4164979a86f414bb7ba3ab18728879001cc633c718c6d9`.
The package was absent on `emulator-5560`; installation succeeded and the main
activity resumed with a live process. A 1080x1920 screenshot was inspected at
source resolution: the login and registration tabs, empty login/password fields,
sign-in button and version 1.0.54 (90) were visible. The debug artifact contains
the existing RNNoise v0.1 component, not the requested v0.2. No voice call,
audio or signed production APK was tested. No release was published.
