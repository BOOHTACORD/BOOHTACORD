# Mobile Web section tabs gutter — 2026-10-23

## Change

The open mobile sidebar now uses a 44px tab strip, matching its 44px touch buttons. The selected-tab underline remains inset by 6px, reducing the dark gap below it from 16px to 6px. Desktop and closed-sidebar styles are unchanged.

## Evidence

- Focused Playwright regression on master `70c803fc12eab18d3e68c03749d7ff140c31c63d`: **PASS**. It asserts a 44px tab strip, 44px button and 6px visible gap.
- Local Web acceptance report: `.out/mobile-sidebar-spacing-qa/.out/local-features/20261023-194846/index.html`. All 24 stages passed, including navigation density and real-stack Web at 1440px and 393px. The report remains `REVIEW_REQUIRED` because the full 506-image gallery was not reviewed; the relevant mobile tab screenshot and 390px channels screenshot were reviewed at source resolution. The run was based on master `7624f8685d1b02c42b55c7efb84993d9d1fac298`; the later master update to `70c803fc` does not touch these Web UI/test files.
- Client parity verifier: **PASS** against `origin/master`.
- `features.json` JSON parse and `git diff --check`: **PASS**.
- Native runtimes: **NOT_RUN**; this is a Web-only CSS/layout change.

## Visual observation

At 390px viewport width, the selected Channels tab has a compact 6px underline-to-container bottom gap. Both section buttons retain their 44px touch target. No unrelated layout change was observed in the captured navigation view.
