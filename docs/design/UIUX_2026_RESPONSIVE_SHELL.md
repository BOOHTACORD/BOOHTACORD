# Responsive workspace shell contract (#291)

This contract records the responsive behavior already implemented by the Web and Flutter shells. It keeps the channel list, conversation history, composer and voice controls available as the viewport changes; it does not alter navigation, guild permissions or media state.

## Width bands

| Viewport | Web | Flutter |
| --- | --- | --- |
| Below 1024 px | Conversation uses the full viewport. Navigation opens as a fixed drawer up to 320 px wide (with 40 px reserved at narrow widths); members/search appear as overlays. The voice dock stays pinned to the bottom at 53 px. | Compact workspace uses a navigation drawer, compact header and 44 px touch targets. Members/search are presented through workspace panels. |
| 1024–1279 px | Navigation is 280 px; conversation fills the remaining width. Members and search open as right overlays no wider than 320 px. | Desktop navigation is 280 px, conversation fills the remainder, and secondary panels overlay the workspace. |
| 1280–1439 px | Navigation and the 248 px member rail flank a flexible conversation when the rail is enabled; search may overlay at 360 px. | Medium layout adds a 248 px member rail when the selected surface allows it; a DM or workspace panel keeps the conversation and panel behavior intact. |
| 1440 px and above | The wide shell keeps a flexible conversation between the 280 px navigation and optional 248 px member rail, with the existing wide frame inset. | Wide layout retains the 280 px navigation and 248 px member rail. A voice-stage surface may present members as an overlay to preserve the media stage. |

Flutter breakpoints are `1024 / 1280 / 1440` logical pixels. Web uses `1024 / 1280 / 1440` shell bands and a `720` px breakpoint for compact drawer controls. The two clients intentionally differ in when a permanent member rail appears; the channel and conversation remain the primary content in both.

## Scroll and resize invariants

- Navigation content and message history are separate vertical scroll areas. Scrolling one does not move the other.
- The composer stays attached to the conversation bottom; the active mobile voice dock stays inside the available viewport. Android keyboard and safe-area insets are covered by Flutter widget geometry tests.
- Channel label width yields to favorite and channel-action buttons. At narrow targets, both controls keep a 44×44 px hit area and remain inside the channel row. After navigation reflows, the selected lower channel remains reachable in the visible navigation area.
- Resizing changes layout and overlay presentation without changing the selected channel or the active voice session. Flutter and Web viewport tests retain selected-channel state; Flutter's IME scenario also retains the typed draft and connected voice state.
- Desktop admin forms keep their component-specific maximum widths rather than stretching to fill the whole shell.

## Regression coverage

Web Playwright covers 320×640, 375×812, 390×844, 393×852, 430×932, 600×900, 768×1024, 840×390, 1024×768, 1280×800, 1440×900 and 1920×1080. It checks shell/composer/voice-dock bounds, channel favorite row geometry and production reflow, independent navigation/history scrolling, drawer behavior, selected-channel retention, browser history and focus restoration. Fixture captures are review evidence, not pixel goldens.

Flutter workspace geometry covers 320×640, 360×800, 375×812, 390×844, 430×932, 600×900, 840×390, 1024×768, 1280×800, 1440×900 and 1920×1080. A separate Android widget test simulates a 280 px IME with 24 px top/bottom view padding and verifies the composer, voice dock, draft, channel and connected voice remain available.

Automated geometry is not physical acceptance. iOS Safari, Android system keyboard, macOS/Windows window resize and actual device media behavior remain in [issue #303](https://github.com/BOOHTACORD/BOOHTACORD/issues/303) until device evidence is recorded.
