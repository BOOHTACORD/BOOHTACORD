# Issue 689: mobile-width Web real-stack retry

- PASS: `python3 -m tools.qa.client_lifecycle.run --critical --portable-proxy
  --width 393 --output-root .out/issue689-mobile-retry` against disposable local
  Go/PostgreSQL/LiveKit/Caddy/Tempo services. The report records `mocks: false`,
  two real listener sessions, voice retained through application chat recovery,
  roster recovery, mobile workspace search during voice, and owned cleanup.
- The run used HEAD `72928320db20baa1ca7c9810d5a7bafe7e8a7533` plus uncommitted
  changes; it is not immutable release-candidate evidence. Physical hardware,
  microphone capture and audio quality were not tested.
- VISUAL (partial): seven 1179×2556 captures for connected voice, deafen,
  prejoin, leave, voice-to-text navigation, application recovery and SFU failure
  were inspected at source resolution. Voice controls and unavailable roster
  status are legible; the recovery capture shows the navigation list scrolled,
  with a channel row partially above the visible scroll area. The login,
  rate-limit, 200% participant list and 200% channel captures were also viewed
  at source resolution. The warning and composer remain visible in the last
  capture; the enlarged participant list continues below the viewport. The
  normal-size participant, text, text-action and log captures were also viewed.
  The viewer initially truncated the log capture, but the original 1179×2556
  image has background below the composer; rows below y=2400 match the text
  channel capture. A subsequent real-stack run with an explicit viewport
  assertion passed, including owned cleanup, under
  `.out/issue689-mobile-layout-check/393`. Archive and file-search
  captures were also viewed; long file names wrap in the expanded result. The
  mentions and pins captures were inspected as well. Review of the remaining
  51 screenshots from the earlier run, all captures from the later run, and the
  final stable-source feature gate is NOT_RUN.
