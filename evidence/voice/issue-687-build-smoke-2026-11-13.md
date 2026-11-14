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

Follow-up Windows build on `9c9fe0d6e186b8d803b0d2861bc88df7126c134a`:
`flutter build windows --release --no-pub` passed with experimental flags off.
The first link failed after an incomplete Firebase SDK extraction. The missing
`firebase_app.lib` was copied from the previously used local SDK, with matching
source and destination SHA-256
`a13b250c60f1cb92a1fb65b8ae389a20f67bb84555fdf1fc37cd784da44bcde5`;
this is a local reuse check, not an independent SDK authenticity verification.
The resulting EXE SHA-256 was
`e5c522519c1499f26fec7ba971da7c66ee6c25517f3ac9563b6e35497e83008d`
and Windows reported `NotSigned`. It was not packaged, installed or released.
