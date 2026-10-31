# UI/UX 2026 settings taxonomy

Scope: personal settings and the existing audio settings surface in child issue [#297](https://github.com/BOOHTACORD/BOOHTACORD/issues/297). This map distinguishes account-wide preferences from guild administration without adding screens or changing API/session contracts.

## Sections and ownership

| Domain | Sections | Web surface | Flutter surface | Save behavior |
| --- | --- | --- | --- | --- |
| Account identity | Profile | Account settings → Profile | Profile → Профиль | Display name uses explicit Save; avatar upload/removal is an immediate action with pending/result feedback. |
| Account security | Password, own sessions, logout | Account settings → Безопасность | Profile → Безопасность | Password change is explicit and clears fields only after success; leaving a dirty name/password asks before discarding; logout asks for confirmation. Revoking one or all other sessions requires a named confirmation; the current session cannot be revoked. |
| Personal notifications | Browser/system permission and conversation preferences | Account settings → Уведомления | Profile → Уведомления | Permission is owned by the browser/OS; preference controls take effect immediately and report unavailable/denied states. |
| Application information | Update status and app information | Account settings → О приложении | Profile → О приложении | Read-only status; any unavailable update result is reported as such. |
| Device and voice preferences | Input/output devices, microphone, shortcuts, processing, playback | Workspace → Настройки аудио | Workspace → Настройки аудио | Device and processing choices apply to this client/device; refresh exposes pending inventory work. Device labels describe the selected system inventory and do not expose internal device IDs. |
| Guild administration | Guild, members, roles, channels, audit, media, readiness | Admin panel, role-gated | Admin panel, ACL-gated | Kept in guild context. These controls are not personal settings and retain their existing server-side ACL. |

## Navigation and layout contract

- Profile, security, notifications, and about are one account-settings group with one selected section. The visible section names have the same meaning in Web and Flutter.
- Audio is a separate workspace surface because it controls this device's media inventory and voice behavior. It has its own Back action and scrollable content; it is not nested under guild administration.
- Guild settings stay under the selected guild and are entered through the admin surface. The source archive's `desktop-guild-settings.png` duplicates the Members image, so it cannot independently establish desktop before/after parity (D11).
- Each surface owns its own scroll area. On compact layouts, section navigation may scroll horizontally; section content remains vertically scrollable and the Back/close action stays in the header.

## Feedback and unsaved changes

- A mutation enters a visible pending state and disables duplicate submission for that action.
- Success and failure are announced beside the affected form/control. A failed save keeps the user's input available for retry.
- An unchanged profile reports that no changes were made; a dirty profile reports unsaved changes. Leaving while the display name or password is dirty requires a deliberate discard confirmation.
- Logout and session revocation use Cancel-first confirmation. Session prompts state which device/session is affected and that access to messages and voice will end; account changes close stale logout/session prompts without a mutation.
- Immediate device/notification choices must not be described as saved by a later profile Save button. Browser/OS permission denial and unavailable capabilities are distinct from retryable service failures.
- Account exit, session revocation, and other destructive session actions remain explicit, named operations. This map does not add account deletion or any new auth/session capability.

## Evidence and limits

- Web profile state, keyboard tabs, dirty-draft, retry and logout confirmation: `evidence/qa/qa297-personal-settings-2026-10-10.json`.
- Flutter profile, responsive workspace and audio inventory states: the same QA record; widget target-platform cases are simulations, not native device runs.
- Five mobile Web sections have source-sized comparison captures in that record. The independent desktop guild-settings before image remains blocked by duplicate D11. Native macOS/Android audio acceptance and spoken screen-reader review remain `NOT_RUN` under #301/#303.
