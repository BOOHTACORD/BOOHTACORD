# Native builds and retained distributions

Flutter source lives in `clients/flutter`; all platforms keep the same native
project identities and the version/build number from its `pubspec.yaml`.

Run commands from the repository root with the pinned Flutter SDK on PATH:

```sh
python -m tools.ci.native.flutter
python -m tools.build.android.run --debug
python -m tools.build.android.run
python -m tools.build.windows.run
```

Task equivalents are `task test:flutter`, `task build:android -- --debug`,
`task build:android`, and `task build:windows`. Windows builds require Windows
and the existing Visual Studio/CMake prerequisites. Android builds require the
Android SDK in `ANDROID_SDK_ROOT` or `ANDROID_HOME` and Java 17.

Android release signing uses the existing external Gradle inputs or ignored
`android/key.properties`. CI materializes the existing repository keystore only
for the build and removes that temporary copy on success or failure. The command
rejects a release signed with a certificate different from the published 1.0.18
APK. No signing identity is created or rotated. Release tags must match pubspec.

Android debug output is `.out/native/android-debug/`; signed APKs are retained in
`clients/flutter/build/release-assets/`. Windows retains the entire
`clients/flutter/build/windows/x64/runner/Release/` directory. Each distribution
includes `artifact-manifest.json` and `SHA256SUMS`: source revision, dirty-source
flag, app version, contract hashes, platform/architectures, file sizes/hashes and
measured signing status. An unsigned Windows CI build is explicitly unsigned.
macOS packages include equivalent metadata after native codesign verification;
the current ad-hoc distribution remains unnotarized.

GitHub CI retains the complete distributions and metadata for 30 days. Android
and macOS release jobs share a non-cancellable native signing queue separate
from the production server installation queue. Published release retries compare
the existing asset's SHA-256 as well as its size. No build products enter Git.

Each local package has `UPSTREAM.json`, its original license and
`BOOHTACORD_PATCHES.md`. The upstream release archive checksum and patch paths
make rebasing auditable. Physical media acceptance remains separate from these
builds and metadata checks.

For an operator without a local Git push credential, **Prepare native release tag**
can be dispatched from `master` in the existing `production` environment. Choose
one platform; the job reads its canonical version from `contracts/client-build.json`
and requires the checkout, trigger SHA and current fetched master to match. It
creates only that version tag, or accepts an already matching tag; a different
existing target is rejected without force updates. Then dispatch Android or Windows Release from `master` while its SHA still
matches the prepared tag. macOS Release runs from the matching tag; production
must separately allow that exact tag with owner approval, without broadening
other environment rules. Tags created with GITHUB_TOKEN do not trigger push
workflows. Prepare/dispatch macOS first, then Android, then
Windows as the shared signing queue becomes available: GitHub keeps only one
running and one pending job in a concurrency group. Existing exact-tag, ancestry,
quality, signing and immutable asset publication checks remain required.
