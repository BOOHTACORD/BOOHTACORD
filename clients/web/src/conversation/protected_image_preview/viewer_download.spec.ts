import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import TextMessageAttachments from '../TextMessageAttachments.vue'
import DirectMessageAttachments from '../../direct_message/DirectMessageAttachments.vue'

const preview = vi.hoisted(() => ({ failed: false }))
vi.mock('./use_protected_image_preview', async () => {
  const { ref } = await import('vue')
  return { useProtectedImagePreview: () => ({
    imageUrl: ref('blob:normalized-preview'), loading: ref(false), unavailable: ref(false),
    failed: ref(preview.failed), loadPreview: vi.fn(), cancelPreview: vi.fn(),
  }) }
})

async function render(kind: 'TEXT' | 'DM', extension: string): Promise<string> {
  const attachments = [{ id: 'file ?#', originalName: `original.${extension}`, sizeBytes: 774 }]
  return kind === 'TEXT'
    ? renderToString(createSSRApp(TextMessageAttachments, { channelId: 'channel/a', attachments }))
    : renderToString(createSSRApp(DirectMessageAttachments, { directMessageId: 'dm/a', attachments }))
}

describe('protected viewer original download', () => {
  beforeEach(() => { preview.failed = false })

  for (const kind of ['TEXT', 'DM'] as const) {
    for (const extension of ['png', 'jpg', 'gif']) {
      it(`${kind} downloads original ${extension} while displaying only the normalized preview`, async () => {
        const html = await render(kind, extension)
        const anchor = html.match(/<a\b[^>]*class="attachment-image-dialog__download"[^>]*>/)?.[0]
        const endpoint = kind === 'TEXT' ? 'channels/channel%2Fa' : 'direct-messages/dm%2Fa'
        expect(anchor).toBeDefined()
        expect(anchor).toContain(`href="/api/v1/${endpoint}/attachments/file%20%3F%23"`)
        expect(anchor).toContain(`download="original.${extension}"`)
        expect(anchor).not.toContain('blob:normalized-preview')
        expect(html).toMatch(/<img[^>]*src="blob:normalized-preview"/)
      })
    }
  }

  it('keeps a failed viewer download hidden without changing the independent original card link', async () => {
    preview.failed = true
    const html = await render('DM', 'gif')
    expect(html).not.toContain('class="attachment-image-dialog__download"')
    expect(html).toContain('href="/api/v1/direct-messages/dm%2Fa/attachments/file%20%3F%23"')
    expect(html).toContain('class="attachment-card__download"')
  })
})
