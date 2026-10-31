# Voice and screen-share UX journey (#300)

Date: 2026-10-10  
Status: presentation journey documented; platform runtime acceptance remains `NOT_RUN`.

This flow maps the existing Web and Flutter voice/media lifecycle for issue [#300](https://github.com/BOOHTACORD/BOOHTACORD/issues/300). It does not change LiveKit, OS permission, screen-capture, or server contracts. The browser/OS owns its native microphone and screen picker prompts; the app reports the current join or publication state around those prompts.

| Phase | User-facing state and next action | Web | Flutter |
| --- | --- | --- | --- |
| Idle / choose join mode | “Вы не подключены”; choose voice with microphone or listener mode. | `VoicePrejoin.vue` shows primary “Подключиться к голосу” and secondary “Подключиться без микрофона”. | `VoicePrejoinCard` exposes the same two join modes. |
| Permission request / connecting | After choosing voice with microphone, the native permission prompt may appear during join. The app announces “Подключаемся к голосовой комнате”; repeated join actions are disabled. | `VoiceConnectionState.JOINING`; the browser controls its permission prompt. | `VoicePhase.joining`; the native platform controls its permission prompt. |
| Permission denied | The user remains connected as a listener, sees why the microphone is unavailable, and can retry after changing site/device permission. | A denied capture maps to `LISTENER_PERMISSION_DENIED`; `VoiceDock` announces listener fallback, labels the retry, and a single click retries publication. `NotFoundError` and `OverconstrainedError` produce device-specific join guidance while the listener CTA stays available. | `VoiceMicrophoneUnavailableNotice` explains listener fallback and offers retry; PTT mode keeps its existing key/touch action. |
| Joined / active | The voice dock confirms the active room; participant controls and roster remain available. A listener is not presented as publishing microphone audio. | `VoiceDock` announces the connected state; `VoiceParticipantStatus` distinguishes unavailable, muted, speaking and deafened states. | `VoiceConnectionBadge`, participant cards and the voice dock expose connected/listener and local mic states. |
| Screen setup / source selection | From the connected room, choose “Показать экран”, review the recommended starting profile, and continue to source selection. Cancel returns to the connected room without publishing a track. | `ScreenShareSetupDialog` offers the ADR-018 requested `1080p · 60 FPS` profile, summarizes the current choice, and keeps resolution/FPS and bandwidth details collapsed until requested. The user's saved profile is preserved unless they choose the recommendation or another profile. The browser owns source selection. | `ScreenShareSetupDialog` shows the same target/current profile and progressive quality options. macOS/Windows use the app's source inventory; Android/iOS use the native system picker after Start. The footer stays reachable above the keyboard and Cancel returns to voice without publishing. |
| Publishing / live | Starting and active publication are separate. The user can stop the share; advanced diagnostics remain behind disclosure. | `ScreenShareState.STARTING` disables duplicate starts; `SHARING` exposes stop and advanced diagnostics. | `ScreenSharePhase.starting` blocks repeat starts; `sharing` exposes stop and disclosure-controlled diagnostics. |
| Recovering | Voice reconnection is explicit and distinct from a disconnected or ended screen share. The user can keep voice controls available while recovery proceeds. | `VoiceDock` and `VoiceRoomConnected` announce reconnecting; bounded retry policy is unchanged. | `VoiceConnectionBadge` announces reconnecting; voice reconnect policy is unchanged. |
| Ended / error | Picker cancellation, permission denial, unavailable sources, connection errors and ended publication are reported separately. The user gets a next action when retry is valid. | `screenFailureMessage` distinguishes `AbortError`, `NotAllowedError` and `NotReadableError`; voice prejoin exposes join failures and revocation notices. | Setup cancellation preserves the voice room; permission/capability errors remain explicit; an ended stream offers another source or return to participants. |

## Cross-client copy and capability contract

The shared state vocabulary describes the same user outcome in Web and Flutter. Short labels can differ when a compact action has less space; platform-specific permission and capture messages retain the actual platform limit.

| State / action | Shared wording and behavior | Web | Flutter |
| --- | --- | --- | --- |
| Voice idle | “Вы не подключены”; primary “Подключиться к голосу”; secondary “Подключиться без микрофона”. The second action joins as a listener. | `VoicePrejoin.vue` | `VoicePrejoinHeading` and `VoiceManualJoinActions` |
| Voice joining | “Подключаемся к голосовой комнате”; progress action “Подключаемся…”; duplicate join actions are disabled. | `VoicePrejoin.vue`, `JOINING` | `VoicePrejoinHeading`, `VoiceManualJoinActions`, `VoicePhase.joining` |
| Voice reconnecting | “Восстанавливаем голосовое соединение”; recovery remains distinct from an ended screen share. | `VoiceDock.vue`, `RECONNECTING` | `VoiceConnectionBadge`, `VoicePhase.reconnecting` |
| Start screen share | Connected-room CTA “Показать экран”; setup summary and recommended profile stay optional; no track is published before Start. | `VoiceRoomConnected.vue`, `ScreenShareSetupDialog.vue` | Voice room controls and `ScreenShareSetupDialog`; compact keyboard mode shortens Start to “Начать показ”. |
| Screen sharing active / stopped | Show the active state and explicit stop action; stopping the stream does not leave voice. | `SHARING` / `STOPPING` | `ScreenSharePhase.sharing` / `stopping` |
| Permission, cancel, unsupported or ended | Explain the specific outcome and offer a valid next action. Do not imply an OS prompt succeeded before the returned track exists. | Browser-owned picker and browser error names map to distinct user messages. | Native platform result maps to cancellation, permission/capability error or ended state; the voice session remains available. |

The capability wording intentionally differs where the platform differs: Web screen capture requires browser `getDisplayMedia` and is disabled in Android Chrome; Flutter iOS captures only BOOHTACORD app content; Android uses the native system source picker and a selected app can be hidden when backgrounded; macOS/Windows use the Flutter source inventory. Native Flutter does not publish system/game audio. Voice microphone permission and listener mode are independent of screen capture, and none of these preflight messages claims hardware acceptance.

## Regression map

- Web prejoin choice, joining progress, microphone-denial notice and 320×640/200% text layout: `clients/web/tests/accessibility/accessibility.browser.spec.ts`.
- Web listener retry behavior and accessible dock copy: `clients/web/src/voice/microphone_controls.spec.ts`, `clients/web/src/voice/voice_dock_reconnect_copy.spec.ts`, and `clients/web/src/voice/connection_state/join_error.spec.ts`.
- Web connection and revocation states: `clients/web/src/voice/voice_dock_transition_states.spec.ts` and `clients/web/src/voice/disconnect_notice/presentation.spec.ts`.
- Web screen cancellation, permission denial and unavailable-source copy: `clients/web/src/voice/screen_feedback.spec.ts`, `clients/web/src/voice/screen_capture_support.spec.ts`, and `clients/web/src/voice/screen_publisher/adapter.spec.ts`.
- Web progressive setup selection and first-screen mobile layout: `clients/web/src/voice/screen_share_setup_dialog.spec.ts` and the “recommended profile before progressive quality options” browser case in `clients/web/tests/accessibility/accessibility.browser.spec.ts`.
- Flutter connection, listener retry/PTT and ended-share behavior: `clients/flutter/test/voice_connection_badge_test.dart`, `clients/flutter/test/voice_microphone_unavailable_notice_test.dart`, `clients/flutter/test/screen_setup/cancellation_test.dart`, `clients/flutter/test/screen_setup/capabilities_test.dart`, and `clients/flutter/test/voice_screen_ended_test.dart`.
- Flutter progressive setup selection and responsive action geometry: `clients/flutter/test/screen_setup/dialog_test.dart` and `clients/flutter/test/screen_share_quality_test.dart`.
- Compact and landscape Flutter desktop source-inventory follow-up: eight-source fixtures verify scrolling, selected-source footer and the accepted source ID/profile at 320×640 / 2× text and 844×390 landscape. The Android quality-only setup test verifies the close control and Start stay above a 280 px keyboard inset; the native Android source picker remains OS-owned. Native prompt/runtime and physical-device behavior remain outside these fixtures.

## Acceptance boundary

Automated component/widget tests establish copy, state transitions and responsive geometry. They do not prove that each browser or OS presents its real permission/picker prompt as expected, that publishing survives a native restart, or that LiveKit recovers after an actual SFU outage. Android/iOS/macOS/Windows media runtime and physical viewport acceptance, plus the owned real-SFU stop/restart/rejoin flow, remain `NOT_RUN` and keep #300 open.
