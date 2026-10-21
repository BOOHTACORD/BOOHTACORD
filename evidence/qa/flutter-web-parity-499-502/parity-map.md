# Flutter ← Web parity: #499–502

Scope: existing Flutter workspace, with Web production components as reference. No backend, HTTP/realtime schema, authorization, LiveKit/vendor, codec, capture engine or stats collection changes.

| Issue | Web reference | Flutter change and regression coverage |
| --- | --- | --- |
| #499 | `channel/ChannelNavigation.vue`, `direct_message/DirectMessageNavigation.vue`, Web header-actions | TEXT/DM use a touch/keyboard overflow in the existing header: scoped search, loaded-history files, TEXT pins, guarded refresh. Context search returns focus to its conversation instead of reopening navigation. Search re-entry has a fresh panel epoch while retaining the query/session. Compact rows retain full-name tooltips, existing unread/mentions, actual authenticated avatars/presence. Sidebar navigation scrolls above the pinned footer/voice controls. Header/DM widget tests and workspace scale/resize/draft/scroll/ACL regressions. |
| #500 | Web `message`/`conversation`/`search` presentation | Shared author/day/time/boundary grouping policy; grouped TEXT and DM show compact gutter timestamps with full local seconds, timezone name and UTC offset in Tooltip/Semantics. Continuous DM history retains keyed anchors, reply/deleted/pending boundaries, date and stable initial unread markers. Existing actions, attachments and retry remain. Search uses dense rows, explicit Find, contextual desktop Enter guidance and existing session/context navigation. Policy + populated workspace + >1000-history regression tests. |
| #501 | Web voice room/dock, mini-player and screen-share UI | Opt-in pin lifecycle retained. Local video pause owns no media track/subscription/audio mutation. Expand reuses the stage fullscreen flow and transfers the renderer across a frame/lease boundary; end/revoke closes the owned route. Reserved main-pane rail/bottom area prevents mini overlap with composer/roster/dock. Intrinsic participant cards accommodate large text, existing watch/volume actions and known audience indicators. Primary voice controls precede secondary overflow. Screen setup shows selected quality without recommended/Apply duplication; advanced capture/content/audio/permissions and measured/confirmed diagnostics are retained. Mini geometry, pause/rebuild/generation, fullscreen handoff and 1/5/10 participant tests. |
| #502 | Web member roster/popover, settings hierarchy | Confirmed guild baseline drives clean/dirty/save/cancel; 409 preserves draft, refreshes revision and requires explicit retry/reload/cancel. Busy guards and disposed-response handling retained. Audio devices/activation/permissions/errors remain primary; advanced processing/shortcuts/diagnostics stay mounted behind disclosure. Roster removes repeated visible status while preserving presence semantics. Profile uses bounded flip/shift/scroll with SafeArea/IME/dock, atomic dismissal, Back/Escape/outside/navigation and focus restoration. Existing profile/roles/security/notifications and ACL actions retained. Controller, actual overlay/race, layout and workspace tests. |

## Existing contract boundaries

- `DirectConversation` supplies participant ID/name and unread count. It supplies neither avatar nor presence nor a DM mention count. Avatar/presence are joined from the existing authorized guild-member/presence state; absent data stays initials/unknown. No invented mention count and no new endpoint/schema.
- Audience markers use the existing authoritative viewer account IDs for the currently observed publication. Owner audience and screen-stage selected/confirmed/applied/measured diagnostics remain in their existing scope. No per-stream capacity/quality inference.
- Files means attachments from the currently loaded authorized history, excluding deleted/pending messages. The dialog is labelled accordingly; existing attachment download authorization is reused.
- Profile/security/notifications retain the existing settings shell and persistence semantics. Guild edits use explicit Save; audio settings retain their existing immediate-update behavior. Cancel does not issue a server write.

## Form states

Guild: loading → clean → dirty → saving → saved/clean. Validation and request failures keep the draft. Conflict reads the latest confirmed baseline without overwriting the draft; edit keeps the conflict visible, Save explicitly retries that revision, Reload discards draft by explicit choice, Cancel restores the latest confirmed baseline without writing. If conflict refresh fails, Save remains disabled until Reload; no stale automatic retry. Pending blocks edits/duplicate submit/reload/cancel; late responses after disposal do not notify.

Audio: disclosure does not change preferences or unmount processing controls. Fallback/error/unsupported processing remains visible outside advanced controls and stale runtime reports do not confirm a newly requested mode.

## Acceptance boundary

Automated widget geometry covers 320/390/768/1024/1440 dp, scale 1/2, short height and IME; production mini also covers 240 dp height. Native OS/physical capture, microphone/audio quality, hardware keyboard on real Windows/macOS/iOS/Android, and multi-device media are separate acceptance in #303. Simulator/component captures cannot mark those gates PASS. See the execution record for actual PASS/FAIL/NOT_RUN results and image hashes.
