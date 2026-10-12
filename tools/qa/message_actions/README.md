# Integrated TEXT/DM action acceptance (#293)

From the current QA worktree, build the production Web client with
`VITE_PUBLIC_ORIGIN=https://localhost:4810 npm run build -- --outDir ../../.out/qa293-build`
from `clients/web`, then run `python3 -m tools.qa.message_actions.run` from the repository root.
`QA_WIDTHS=320,393,1440` selects the registered widths. Phone runs use actual Chromium touch emulation; desktop uses visible keyboard/hover actions, where the mobile disclosure is deliberately hidden.

The owned Go/PostgreSQL/HTTPS/SFU stack reserves loopback ports4810/4812/4820/4880/4881/4882. It refuses occupied ports and removes only ownership-labelled resources. Credentials are temporary mode0600 files. Results are ignored under `.out/qa293-20261012`. A new RUNNING receipt is written before execution; failures cannot reuse an old PASS. Web captures crop only action panels and reaction controls, excluding message bodies.

The scenarios exercise actual Reply, edit PATCH200, reactions PUT/DELETE204, delete cancellation without a request, one confirmed delete204, ownership capabilities, protected administrator-only TEXT pin204 with subsequent server-list confirmation, and third-admin DM denial404. The pin's transient local success notice is not claimed as persistent feedback evidence. Grouped/system/attachment/failed-send/scroll/long-press coverage is separately identified in focused component tests, not claimed as integrated device coverage.

Native execution uses an independent Flutter package copy at `/private/tmp/boohtacord-qa293-flutter`; preserve source directories called `build` while excluding only package-root generated build/cache and platform Pods. Run pubget and focused analysis/tests there, then `python3 -m tools.qa.message_actions.run_native --platform android --device emulator-5554` (or the assigned free QA iOS simulator). The runner verifies the whole app lib manifest against the copy before compilation, records executable SHA and removes its own HTTPS reverse. The integration target uses production application widgets and real independent HTTP sessions. Invisible synthetic message content prevents body text from appearing in native captures; this does not test text formatting or attachment content. Never preserve binaries containing private fixture defines.

All native interaction here is controlled integration-test input on an emulator/simulator. Physical touch, IME, keyboard and spoken screen-reader acceptance remain independent NOT_RUN gates, even when all observed rows PASS. Inspect every final capture at original resolution before writing visual observations. No camera, recording, backups, production mutations or media capacity claims are involved.
