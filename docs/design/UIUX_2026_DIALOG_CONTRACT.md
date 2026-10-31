# UI/UX 2026 dialogs and dangerous actions

Scope: child issue [#298](https://github.com/BOOHTACORD/BOOHTACORD/issues/298). This inventory records the existing Web and Flutter interaction surfaces and the shared safety contract; it does not claim physical-device acceptance.

## Inventory

| Surface | Operations | Interaction contract and current evidence |
| --- | --- | --- |
| Web `ChannelTopologyActions.vue` | Modal create category/channel; confirm category delete, TEXT archive, VOICE close | Create modal focuses its name field, traps Tab, returns focus to its trigger and disables fields while pending. Validation/server errors remain visible in the modal and the name input references its single live error. A second submit while pending is ignored; the entered name remains after 403/409/5xx. Destructive confirmation names the target and consequence, starts on Cancel, traps focus and treats Escape/backdrop as cancellation. Its content now has safe internal padding and its actions stay at the bottom of the surface. Confirmation captures account, target and topology revision; an account change or stale target closes the confirmation, and no request is sent for stale data. |
| Web `AdminCategoryControls.vue` | Inline create/rename category; confirm empty-category delete | Pending state disables controls and create has an explicit duplicate-submit guard. Deletion states that the section is empty and will leave the list; the target and revision are revalidated after confirmation. Existing `AdminConfirmation` provides focus trapping, Cancel-first focus and safe dismiss. |
| Web `AdminChannelCreate.vue`, `AdminChannelRename.vue`, `AdminChannelDescription.vue`, `AdminChannelMove.vue`, `AdminChannelOrder.vue` | Inline create/edit/move/order | These are forms rather than dialogs. Create ignores duplicate submits, associates an error with the name input, leaves the draft after request failure and exposes pending/success feedback. Rename/move/order use their existing conflict-aware editors. |
| Web `AdminTextArchive.vue`, `AdminVoiceClose.vue` | Confirm TEXT archive and VOICE admission close | Existing editors capture the selected target and revision before awaiting confirmation, send that revision, preserve safe server conflict behavior and announce error/status. `AdminConfirmation` supplies keyboard handling and safe Cancel. |
| Web `ScreenShareSetupDialog.vue` | Start screen demonstration; update current stream quality | Native modal dialog labels title and description, focuses Close, traps keyboard focus, and routes Escape to cancellation. The dialog scrolls within a viewport bound; mobile controls remain reachable at a 320×568 browser viewport. |
| Flutter `widgets/topology_actions/create_dialog.dart` | Modal create category/channel | Flutter dialog uses a scrollable form, focuses the name, prevents barrier-tap dismissal, ignores duplicate submit, shows field validation next to the name, validates the selected section before sending and retains the draft after failed requests. |
| Flutter `widgets/topology_actions/delete_actions.dart` | Confirm category delete, TEXT archive, VOICE close | Shared confirmation helper disables barrier dismissal, closes the focus loop, supports platform Back/Escape, returns focus and defaults to Cancel. The danger action names the object and consequence. Account, target and revision are checked while the prompt is open; an account change or stale target closes it. Duplicate requests for one target are locked while its dialog/request is active. |
| Flutter `features/admin/topology/mutation_categories.dart` / `mutation_danger.dart` | Admin-shell delete/archive/close | Existing mutation controller validates revision before the prompt, rechecks after it, resolves the current target and verifies empty/category or channel kind/state before mutation. |
| Flutter `features/screen/setup/open_dialog/` | Start/cancel screen demonstration; update quality | The body scrolls independently from actions. At narrow phone width it drops redundant header copy, uses a concise primary action and keeps Close as the safe cancellation action. Surface height includes the keyboard inset. A widget test covers 320×568, simulated 280 px IME and 2× text. |

## Related dialogs outside topology

| Client and surface | Operations |
| --- | --- |
| Web `ProfileSettings.vue` | Confirm leaving with an unsaved name/password draft; confirm account logout; inline avatar deletion and profile/password forms. |
| Web `OwnSessionsPanel.vue` | Confirm revoking one or all other sessions. |
| Web `WorkspaceApp.vue` | Confirm leaving a profile panel with an unsaved draft. |
| Flutter `workspace_ui/confirm_delete` | Confirm deleting a message. |
| Flutter `role_permissions/change_role` and `confirm_deletes` | Confirm discarding an unsaved role draft and granting delete permissions. |
| Flutter admin/member voice controls | Confirm disconnecting a participant or applying a voice timeout. |
| Flutter `workspace_ui/message_edit_dialog` | Edit a message with a field-bound form and save/cancel actions. |

These reuse the shared confirmation primitive when one exists; this inventory does not imply that unrelated session, role, message, or voice workflows received new behavior in this #298 slice.

## Shared contract

- Confirmation copy names the affected object and the concrete consequence. Cancel is the initial/default action; submit requires an explicit action.
- Escape, platform Back and backdrop behavior can dismiss a prompt only as cancellation. Pending mutations cannot be submitted twice.
- A prompt tied to an account or target closes when that account changes or the target becomes stale; stale state never triggers a mutation.
- Modal content has an accessible name, contained focus and a return-focus path. Validation appears beside its field; server errors and completion use announced feedback.
- A destructive request uses the same object identity and revision shown during confirmation. If the topology changes or the target disappears, no request is sent until the user sees the refreshed state and confirms again.
- Failed creation keeps the entered draft. A stale or failed server result does not silently retry with a newer revision.
- Mobile dialogs account for safe area, text scale and keyboard-inset layout; device/IME behavior remains separately marked `NOT_RUN` until physical testing.

## Local regression evidence

- Web `clients/web/tests/accessibility/admin_confirmation.browser.spec.ts`: twelve Chrome cases cover safe Cancel-first focus, accessible modal semantics/axe, keyboard focus wrapping and Escape cancellation, 320×568/landscape/2× text reachability, automatic stale-target and account-change dismissal, create-category/channel forms, duplicate submit, and draft retention/retry across 403/409/503. A geometry assertion keeps the destructive-dialog heading inside its padded surface.
- Web `clients/web/src/channel/member_topology/confirmed_target.spec.ts`: five cases cover unchanged target/revision, changed revision/name, disappearance, and a formerly empty section gaining a channel.
- Flutter `clients/flutter/test/topology_confirmed_target_test.dart`: three cases cover target/revision retention, disappearance/name change and a section that is no longer empty.
- Flutter `clients/flutter/test/confirmation_dialog_test.dart`: create preserves its draft after 403/409/503, prevents a duplicate pending submit and closes only after a successful retry. Confirmation semantics expose their title and both action labels; account-scope change closes without resolving as affirmative, and modal barrier, closed focus traversal, Escape/Back cancellation and trigger focus restoration remain covered.
- Flutter `clients/flutter/test/screen_setup/dialog_test.dart`: the mobile keyboard/2× text widget case checks that Close and the primary action remain in the 320×568 viewport without layout exceptions.
- Flutter `clients/flutter/test/uiux_2026/dialog_visual_capture_test.dart` can capture the production create, destructive-confirmation and screen-setup widgets to the ignored visual-evidence directory; the 2× mobile capture includes a simulated 280 px keyboard inset.

These local checks do not establish physical iOS/Android IME, landscape, safe-area, VoiceOver/TalkBack or 41-screen before/after results. Those remain `NOT_RUN`; see [`evidence/qa/uiux-2026-epic-289-2026-10-09.md`](../../evidence/qa/uiux-2026-epic-289-2026-10-09.md).
