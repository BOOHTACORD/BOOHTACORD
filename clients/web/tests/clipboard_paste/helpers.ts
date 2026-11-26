import { expect, type Page } from '@playwright/test'
import { qaImage } from '../protected_image_viewer/image'
export const first = '11111111-1111-4111-8111-111111111111'
export const second = '22222222-2222-4222-8222-222222222222'
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
      return route.fulfill({ status: 201, json: { ...body, id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', channel_id: path.split('/')[4],
        author_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', revision: 1, created_at: '2026-11-26T00:00:00Z', deleted: false,
        attachments: (body.attachment_ids ?? []).map((id: string) => ({ id, original_name: 'image.png', byte_size: qaImage().length })), mention_user_ids: [] } })
    }
    if (path.endsWith('/auth/session')) return route.fulfill({ json: { account_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', role: 'MEMBER' } })
    if (request.method() !== 'GET') return route.fulfill({ status: 204 })
    return route.fulfill({ json: { messages: [], members: [], reactions: [], can_pin: false } })
  })
  await page.goto('/tests/clipboard_paste/fixture.html')
  await expect(page.locator('#message-body')).toBeEnabled()
  return state
}
export async function paste(page: Page, text = '', count = 1, bytes?: number, selector = '#message-body') {
  await page.locator(selector).evaluate((input, value) => {
    const data = new DataTransfer()
    if (value.text) data.setData('text/plain', value.text)
    for (let i = 0; i < value.count; i++) data.items.add(new File([
      value.bytes === undefined ? Uint8Array.from(atob(value.png), c => c.charCodeAt(0)) : new Uint8Array(value.bytes),
    ], 'image.png', { type: 'image/png' }))
    input.dispatchEvent(new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }))
  }, { text, count, bytes, png: qaImage().toString('base64') })
}
