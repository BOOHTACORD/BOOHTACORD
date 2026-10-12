# Configured guild identity native QA (#278)

The supplemental Android/iOS scenario runs the real Flutter application against an
owned Go/PostgreSQL stack. It does not replace the physical assistive-technology
acceptance required by #278.

Run from a Git checkout. The runner reads `git rev-parse HEAD` before starting
resources, and reads the actual Flutter/Dart versions with `flutter --version
--machine`. Future runs never inherit the SHA or versions from this evidence.
A failed scenario status raises an error and exits nonzero, even if Flutter drive
itself returned success.

Use a separate Git worktree/build directory when running alongside another
Flutter build; do not use `git archive` as the execution directory because an
archive has no Git provenance. Preserve the tested ref in the isolated worktree
and prepare its Flutter dependencies there. The native scenario records
`Platform.operatingSystemVersion` from the runtime. The dedicated AVD is `BOOHTACORD_QA_278_API35`, device `emulator-5558`.
The API requires an owned loopback HTTPS origin on port 4840 and an exact local
certificate pin. Tempo uses port 4842; the internal API publishes only to
loopback 4843. No SFU or Voice Join is used.

```
BOOHTACORD_QA_SHARED_WORK=/path/to/Colima-mounted/checkout/.out \
  python3 -m tools.qa.guild_identity.run --platform android --device emulator-5558

BOOHTACORD_QA_SHARED_WORK=/path/to/Colima-mounted/checkout/.out \
  python3 -m tools.qa.guild_identity.run --platform ios --device <dedicated-QA-simulator-UUID>
```

The temporary directory must be visible to the Colima VM; `/private/tmp` is not
mounted in this machine's QA configuration. The private defines file contains
disposable credentials and is removed along with owned containers, network and
API image. Only sanitized status data and PNG hashes belong in public evidence.

The scenario checks auth/header long Unicode layout, the native Flutter semantics
label on the logo, no server switcher, a rename through a second real authorized
admin session, logout, a new sign-in and switching from ADMIN to MEMBER. A Flutter semantics node is **not** proof
of TalkBack/VoiceOver/NVDA announcement. Desktop window title, real screen reader,
OS notification permission/delivery and missing platforms remain
separate acceptance rows.

Runner regression checks (no Docker/device needed):

```
python3 -m unittest tools.qa.guild_identity.test_run
```
