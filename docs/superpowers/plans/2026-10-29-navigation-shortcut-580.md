# Navigation search shortcut implementation plan

> **For agentic workers:** Execute inline; preserve editable, IME and ordinary dialog guards.

**Goal:** Close #580: the actual search launcher works with Ctrl+K/Meta+K in the mobile navigation drawer.

**Architecture:** Pass the live launcher element to the existing pure focus guard. Editable targets always reject. A role=dialog target is allowed only when it belongs to that exact owned launcher and its nearest dialog is the existing #nav-sidebar navigation dialog. Other/nested dialogs remain blocked.

**Tech Stack:** Vue3, TypeScript, Vitest, actual full-app headed Chromium with Go/API.

---

### Task 1: Retain the counterexample

Create `clients/web/src/search/navigation_shortcut.spec.ts` with typed DOM-shaped
targets for the owned button and descendant, a different navigation control,
an input, ordinary and nested content dialogs. Test both Ctrl and Meta modifiers.

```sh
cd clients/web
npm test -- --run src/search/navigation_shortcut.spec.ts src/search/search_shortcut.spec.ts
```

- [ ] Require owned drawer button/descendant RED while all existing editing/dialog guards pass.

### Task 2: Narrowly authorize the launcher

Modify `clients/web/src/search/search_shortcut.ts` to accept an optional launcher.
Keep the existing key/modifier/repeat/composition check. Reject editable controls
first, then allow a dialog target only if it is the launcher or its descendant and
the target's nearest dialog equals launcher.closest('#nav-sidebar[role="dialog"]').
In `SearchLauncher.vue`, call `shouldOpenSearchShortcut(event, trigger.value)`.

- [ ] Focused shortcut/focus-return/quick-jump tests and full Web typecheck pass.
- [ ] Register the scenario in chat/shell feature metadata with honest platform scope.

### Task 3: Native browser/runtime delivery

- [ ] Run real full-app headed Ctrl+K and Meta+K at 1440, 800 and390 CSS px, plus
Escape/focus return, input/composition/ordinary dialog negative controls, DM
dedup/navigation and zero voice/microphone activation. Save original-size images.
- [ ] Run canonical local_features Web acceptance on the exact source and retain
its actual outcome; fix executable environment blockers where possible.
- [ ] Require final-source hosted CI and approved Web delivery before closing #580.
Preserve old failures and the 43 untouched consolidation decisions.
