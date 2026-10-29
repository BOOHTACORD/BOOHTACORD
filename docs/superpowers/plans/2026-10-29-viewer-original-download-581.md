# Protected viewer original download implementation plan

> **For agentic workers:** Execute inline, one leaf packet; source and runtime proof must remain separate.

**Goal:** Close #581 by making viewer Download return the same protected original as the card for PNG/JPEG/GIF in TEXT and DM.

**Architecture:** Keep the existing authenticated normalized preview Blob solely as the displayed image. Pass the already computed original download URL from PublishedAttachmentCard to ProtectedImageViewer; use that URL only for the download anchor. Preserve failed/revoked visibility and browser cookie/ACL enforcement.

**Tech Stack:** Vue3/TypeScript, Vitest SSR, real full-app browser/Go API and native project acceptance.

---

### Task 1: Add independent href regression

Create `clients/web/src/conversation/protected_image_preview/viewer_download.spec.ts`.
Render the production TEXT and DM attachment wrappers with a successful preview hook
whose imageUrl is `blob:normalized-preview`. For PNG/JPEG/GIF require the viewer
download anchor to point at the protected original encoded endpoint, retain the
original filename, and keep the img src on the normalized preview. A failed preview
must still hide the viewer download while leaving the separate card available.

```sh
cd clients/web
npm test -- --run src/conversation/protected_image_preview/viewer_download.spec.ts
```

- [ ] Require actual RED: viewer href is the preview Blob instead of the original.

### Task 2: Wire the exact parent edge

Modify `clients/web/src/conversation/ProtectedImageViewer.vue`:

```ts
const props = defineProps<{ name: string; previewUrl: string; downloadUrl: string }>()
```

Bind the existing viewer download anchor to `props.downloadUrl`, retaining its
preview-ready/not-failed condition and download filename.
Modify `clients/web/src/conversation/attachment_card/PublishedAttachmentCard.vue`:

```vue
:download-url="props.downloadUrl"
```

- [ ] Focused regression, published_attachment_card and URL tests pass.
- [ ] Typecheck/production build and full Web tests pass with unchanged lockfile.
- [ ] Register the viewer regression under chat; append an honest Web-only parity
decision while preserving existing Android/iOS history and runtime states.

### Task 3: Real runtime and delivery

- [ ] Run canonical local_features Web acceptance on this exact source with a real isolated Go/API stack.
- [ ] On actual full-app headed browser, upload owned PNG/JPEG/GIF, open viewer and
capture real downloads from viewer/card in both TEXT and DM; compare bytes, SHA256,
decoded format and filename. Preserve preview decode, Escape/focus, both participant
ACL, outsider/anonymous denial, delete/revocation and exact own cleanup.
- [ ] Save original-size screenshots with root visual observations; retain hashes,
source/build/runtime binding, commands, mandatory triggers and honest limitations.
- [ ] Require final-source CI, merge and approved delivery; close #581 only once
its full retained download and ACL behavior passes. No43 consolidation work.
