# Original Windows client update acceptance (#249)

Run `python -m tools.qa.legacy_windows_update.run` only on a fresh **GitHub-hosted
Windows** runner. User machines and existing application profiles are rejected.
The normal Windows GUI job runs this before its existing recovery/SFU journeys.

The gate uses the unchanged published Windows1.0.32/46 portable EXE, its pinned
archive/manifest and every manifest file hash. Its external UI Automation driver
is restricted to the exact process/window: it must see the old version, the live
stable offer and the target version in “What's new”. No patched application,
mocked response, account, microphone or private server input is used.

It then closes the old process, verifies the current published Setup checksum,
performs a real per-user installation into a new owned directory, verifies every
installed manifest file and PE version/build, and opens the installed EXE.
The new login UI must display that version and no incorrect update offer.
This visible-state check is not an authenticated settings-card status check.
The old client supports a manual download page, not modern in-place updating.

Public catalog reads must return no-store/nosniff JSON and a consistent newer
Windows/direct/stable/x64 target. A second read must equal the first; target
changes during the run fail rather than mixing release generations. Production
catalogs/backends are never modified or restarted. The original29/r52 target is
historical: testing the approved current stable avoids an artificial downgrade.

The baseline ZIP SHA256 is
`efcb003c45f1a37732990dd8ff05cff4b601f6697ecb97a3f405c9512c030202`;
source `e2b19dfef3568eb00187c5dd35e244aa58ae2942`. Current artifacts are authenticated
against the official release's checksum/manifest publication, not Authenticode;
code-signing acceptance is separate. Only bounded synthetic login captures,
public release identities and PASS/FAIL observations are retained as artifacts.

Offline guards:
```sh
python -m unittest tools.qa.legacy_windows_update.test_policy \
  tools.qa.legacy_windows_update.test_packages tools.qa.legacy_windows_update.test_workflow \
  tools.qa.legacy_windows_update.test_catalog tools.qa.legacy_windows_update.test_owned
```

Missing window/semantics/version, corrupt files, incorrect offer, timeout or
cleanup failure cannot pass. Hardware/media, private user-profile migration,
authenticated settings, backend-restart and broader release gates are separate.

The final receipt is published only after the owned root is removed. Windows may
briefly retain its directory handle after the uninstaller returns; cleanup retries
that owned path for at most10 seconds, then fails. Ownership/parent/link guards
remain active. A real Windows child-CWD lock regression checks this boundary.
The Windows job runs that unit module explicitly before the published-EXE journey.
