import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./ProtectedImageViewer.vue', import.meta.url), 'utf8')
const preview = readFileSync(new URL('./protected_image_preview/use_protected_image_preview.ts', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/conversation.css', import.meta.url), 'utf8')

describe('protected attachment image viewer', () => {
  it('uses a modal dialog with explicit Escape, close and focus return behavior', () => {
    expect(component).toContain('dialog.value?.showModal()')
    expect(component).toContain('@cancel="onCancel"')
    expect(component).toContain('event.preventDefault()')
    expect(component).toContain('dialog.value.close()')
    expect(component).toContain('@close="restoreFocus"')
    expect(component).toContain('opener.value.focus()')
    expect(component).toContain('aria-label="Закрыть просмотр изображения"')
  })

  it('loads only the same-origin protected preview and releases the blob on close', () => {
    expect(component).toContain('useProtectedImagePreview(')
    expect(component).toContain('cancelPreview()')
    expect(preview).toContain('fetch(previewUrl()')
    expect(preview).toContain("credentials: 'same-origin'")
    expect(preview).toContain("cache: 'no-store'")
    expect(preview).toContain('response.status === 404 || response.status === 410')
    expect(preview).toContain('URL.revokeObjectURL(objectUrl)')
    expect(component).toContain('Вложение удалено или недоступно.')
    expect(component).toContain('@click="loadPreview"')
  })

  it('constrains the viewer and image to narrow viewports', () => {
    expect(styles).toContain('width: min(1100px, calc(100vw - 32px))')
    expect(styles).toContain('max-width: 100%; max-height: calc(100dvh - 160px)')
    expect(styles).toContain('@media (max-width: 600px)')
    expect(styles).toContain('max-height: calc(100dvh - 110px)')
  })

  it('uses real file and download icons while preserving the protected link', () => {
    expect(component).toContain('M14 2H6a2 2 0 0 0-2 2')
    expect(component).toContain('M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5')
    expect(component).toContain(':href="props.downloadUrl" :download="props.name"')
    expect(component).toContain(':src="imageUrl"')
    expect(component).not.toContain('♧')
  })
})
