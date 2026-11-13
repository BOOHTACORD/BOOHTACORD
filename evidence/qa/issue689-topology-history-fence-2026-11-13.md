# Issue #689: topology-triggered text history fence

A realtime topology refresh can select its first text channel and begin loading
history. A local regression reproduced a late response populating history after
the originating socket ended. The load now receives the refresh owner predicate;
stale results and errors are ignored while the matching loading indicator clears.
Independent initial loading and a newer manual channel selection remain valid.

Thirteen focused Flutter tests passed locally, including old response, independent
load and newer-selection cases. Targeted Dart analysis passed; the project CI
analysis mode passed with 96 informational findings elsewhere. Fourteen local
feature-policy/native/process tests passed under Linux; the process tests failed
when initially run under Windows, where `os.killpg` is unavailable.
This is unit/tooling evidence. Current-source Android, Web/Windows regression,
visual, full matrix and production evidence remain open.

At GitHub commit c7ac7d1f1fcb60a72a24cee53e5c94a17210c7c1 the Android emulator
ran the registered scenario with the owned API: the delayed response did not
update history after socket closure, and the loading indicator cleared. The
runtime report is `Q:\Codex\issue689-android-topology-c7ac\runtime.json`.
The source-resolution screenshot shows the connection-status panel, but an open
navigation drawer obscures the history area. A follow-up capture closes the
drawer; its execution and visual review, iOS and physical-device coverage remain
NOT_RUN. Media was not exercised.
