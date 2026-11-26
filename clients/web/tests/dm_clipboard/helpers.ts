import { expect, type Page } from '@playwright/test'
import { qaImage } from '../protected_image_viewer/image'
export { first, second } from '../clipboard_paste/helpers'
export async function mount(page: Page) {
  const state = { fail: false, hold: false, release: () => {}, uploads: [] as { path: string; imageBytes: boolean }[], sends: [] as Record<string, unknown>[] }
  await page.route('**/api/v1/**', async route => {
    const request = route.request(), path = new URL(request.url()).pathname
    if (request.method() === 'POST' && path.endsWith('/attachments')) {
      state.uploads.push({ path, imageBytes: request.postDataBuffer()?.includes(qaImage()) ?? false })
      if (state.hold) await new Promise<void>(resolve => { state.release = resolve })
      return route.fulfill(state.fail ? { status: 507, json: { error: { code: 'INSUFFICIENT_STORAGE' } } } : {
        status: 201, json: { id: 'bbbbbbbb-bbbb-4bbb-8bbb-'+String(state.uploads.length).padStart(12, '0'), original_name: 'image.png', byte_size: qaImage().length },
      }).catch(() => {})
    }
    if (request.method() === 'POST' && path.endsWith('/messages')) {
      const body = request.postDataJSON(); state.sends.push(body)
      return route.fulfill({ status: 201, json: { ...body, id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', direct_message_id: path.split('/')[4],
        author_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', revision: 1, created_at: '2026-11-26T00:00:00Z', deleted: false,
        attachments: (body.attachment_ids ?? []).map((id: string) => ({ id, original_name: 'image.png', byte_size: qaImage().length })), mention_user_ids: [] } })
    }
    if (path.endsWith('/auth/session')) return route.fulfill({ json: { account_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', role: 'MEMBER' } })
    if (request.method() !== 'GET') return route.fulfill({ status: 204 })
    return route.fulfill({ json: { messages: [], members: [], reactions: [], direct_messages: [], can_pin: false } })
  })
  await page.goto('/tests/dm_clipboard/fixture.html')
  await expect(page.locator('#direct-message-body')).toBeEnabled()
  return state
}
