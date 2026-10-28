# Web participant card preview size and refresh

Date: 2026-10-28

## Implementation

- Participant grid width is capped at 18rem per participant column. Matching stream and voice-only cards remain equal-sized.
- Web captures JPEG previews up to 480×320 at quality 0.6, then tries smaller dimensions and lowers quality for compact fallback frames. The existing 14 KiB payload limit remains unchanged. The API validates the expanded frame dimensions while retaining its JPEG byte and pixel bounds.
- The publisher retries a missing first drawable frame at one-second intervals up to ten times. After its first successful frame, it captures every 30 seconds. Visible readers poll at 30-second intervals; up to three one-second retries handle an empty initial response.

## Verification

- `screen_thumbnail.spec.ts` and `reader_visibility.spec.ts`: 13 tests passed.
- `go test ./internal/media/screen_preview`: passed.
- `vue-tsc --noEmit` and the production Vite build: passed.
- Local feature run `.out/local-features/20261028-234334/report.json`: Web unit, build, accessibility, all selected browser suites, and real API/SFU scenarios at 1440 and 393 CSS pixels passed.
- The real-stack stream source is a synthetic canvas. It confirms capture, JPEG delivery, decode and card lifecycle only; it is not physical-device or media-quality evidence.

## Visual review

Reviewed the relevant generated images at their original resolution:

- `web-screen_share_ui/.../listener-participant-cards-876x656.png`: two equal 405 px cards; the 16:9 preview is about 228 px tall.
- `web-screen_share_ui/.../listener-participant-cards-390x200.png`: at 200% text, cards stack vertically and stay within the viewport.
- `web-real-stack/1440/screen-share-listener-participant-cards.png` and `web-real-stack/393/screen-share-listener-participant-cards.png`: decoded previews appear in the streamer's card at desktop and mobile sizes.

The harness status remains `REVIEW_REQUIRED` because the selected feature set generates additional screenshots beyond these target views. No screenshot baseline was approved.
