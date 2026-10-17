# #288 — screen setup Escape cancellation

Local pre-merge acceptance, 2026-10-18. Base `16e5971c7378860c5e1743ac69d5969aa6cba6f1`. The adjacent JSON records source hashes, commands/scopes, image hashes and failure history.

Escape now follows the same null-result route cancellation as Cancel/X. An autofocus, non-traversable focus node makes the shortcut available before the first Tab; key repeats are ignored. Inventory disposal and late enumeration guards remain owned by the existing dialog lifecycle.

## Local results

- Corrected unchanged-base regression: four Escape cases fail because the dialog remains; four Enter/Space Cancel/X cases pass. Earlier spinner/viewport harness errors are excluded.
- Screen setup: 48 PASS, including initial/traversed Escape and quality editing; final eight keyboard tests pass at 1200×800. Null result, launcher focus, inventory listener/timer cleanup and late completion are checked. Existing start/quality tests remain green.
- Full Flutter: 1457 PASS, one skipped; selected components: 130 PASS. Focused analyzer: zero issues. Python fixture/ownership contracts: 13 PASS; local-feature policy/runtime harness: 21 PASS.
- Local `screen` feature gate: all four stages PASS (full unit, component captures, actual Android emulator API/UI and actual iOS simulator API/UI). The raw report remains `REVIEW_REQUIRED` for incidental images; five selected original-resolution setup captures were reviewed as `PASS_SCOPED`. Body scrolling and fixed accessible footer actions remain intact. No golden was approved.
- Traceability: 39 requirements PASS_INDEX_ONLY; approved brief is unavailable on this Mac. Wire contracts are unchanged.

## Required Windows completion

This record intentionally does not claim Windows runtime from Mac tests. Before merging or closing #288, the exact PR source must pass the added Windows CI gate. It builds a real release GUI around the unchanged shipping entrypoint, reuses the owned API/PostgreSQL/LiveKit fixture, joins without microphone and opens both production launchers using guarded Win32 SendInput. Each launcher is tested before and after Tab/Shift+Tab, then Escape must close, restore trigger focus, retain the same room/lease/mute/deafen and avoid screen publication. A five-second late-effect observation follows.

CI retains `screen-setup-windows-<CI SHA>` with result JSON and six synthetic screenshots (open/closed). The final PR acceptance record binds its run, accepted head, actual OS/SDK and reviewed captures before closure. The runner refuses personal/self-hosted desktops; private configuration and service logs are never uploaded. This is native Windows VM GUI acceptance, not physical media quality or a full release gate.

The first native gate failed Android environment discovery (`adb` absent from PATH), before app startup; the corrected pinned environment passed. Dedicated Android/iOS simulators are not physical touch/screen-reader/media proof. Related broad gates #287/#227 remain independent.
