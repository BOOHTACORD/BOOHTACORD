# Web participant card preview size and refresh

Date: 2026-10-28

## Implementation

- Participant grid width is capped at 18rem per participant column. Matching stream and voice-only cards remain equal-sized.
- Web captures JPEG previews up to 480×320. At each size it tries quality 0.82, 0.74, 0.66, then 0.6 before reducing dimensions; the compact ≤160 px fallback remains at quality 0.45. This keeps the existing 14 KiB payload limit while selecting sharper encoding whenever it fits. The API validates the expanded frame dimensions while retaining its JPEG byte and pixel bounds.
- The publisher retries a missing first drawable frame at one-second intervals up to ten times. After its first successful frame, it captures every 30 seconds. Visible readers poll at 30-second intervals; up to three one-second retries handle an empty initial response.

## Verification

- `screen_thumbnail.spec.ts` and `reader_visibility.spec.ts`: 14 tests passed, including higher-quality encoding at full preview resolution within the unchanged byte cap.
- `python3 -m tools.verify.client_parity.run --base origin/master`, JSON validation and `git diff --check`: passed.
- `go test ./internal/media/screen_preview`: passed in the previous acceptance run; backend code and JPEG contract are unchanged by this quality follow-up.
- `vue-tsc --noEmit` and the production Vite build: passed in the local feature run.
- Local feature run `.out/local-features/20261028-235956/report.json`: all 24 Web stages passed, including browser suites and real API/SFU scenarios at 1440 and 393 CSS pixels. Overall report status is `REVIEW_REQUIRED` because other feature captures were generated and were not all in this visual review.
- The real-stack stream source is a synthetic canvas. It confirms capture, JPEG delivery, decode and card lifecycle only; it does not measure perceived sharpness on real high-detail content or establish physical-device/media-quality acceptance.

## Visual review

Reviewed the relevant generated images at their original resolution on 2026-10-29:

- `web-screen_share_ui/.../listener-participant-cards-876x656.png`: two equal 405 px cards; the 16:9 preview is about 228 px tall.
- `web-screen_share_ui/.../listener-participant-cards-390x200.png`: at 200% text, cards stack vertically without horizontal overflow; lower content continues in the page's vertical scroll area.
- `web-real-stack/1440/screen-share-listener-participant-cards.png` and `web-real-stack/393/screen-share-listener-participant-cards.png`: decoded previews appear in the streamer's card at desktop and mobile sizes; the stream fixture is synthetic and cannot demonstrate perceptual JPEG improvement.

The harness status remains `REVIEW_REQUIRED` because the selected feature set generates additional screenshots beyond these target views. No screenshot baseline was approved.
