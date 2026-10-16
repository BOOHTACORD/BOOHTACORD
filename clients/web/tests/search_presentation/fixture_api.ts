import type { Page } from '@playwright/test'
export const channel = '22222222-2222-4222-8222-222222222222', author = '11111111-1111-4111-8111-111111111111'
export const name = 'ОченьДлинноеИмяБезПробелов'.repeat(4), filename = 'ДлинноеНазваниеФайлаБезПробелов'.repeat(5) + '.pdf'
export const id = (i: number) => `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`
export const message = (i: number) => ({ id: id(i), channel_id: channel, author_id: author, body: 'Synthetic orbit snippet '.repeat(30), created_at: '2026-10-12T10:00:00Z', client_message_id: id(i + 100), revision: 1, attachments: [{ id: id(i + 200), original_name: filename, byte_size: 1024 }], mention_user_ids: [], deleted: false })
export async function api(page: Page) {
  await page.route('**/api/v1/**', route => {
    const url = new URL(route.request().url()), p = url.pathname
    const json = p.endsWith('/members') ? { members: [{ user_id: author, login: 'fixture', display_name: name, role: 'MEMBER', presence: 'online' }] }
      : p.includes('/members/') ? { user_id: author, login: 'fixture', display_name: name, role: 'MEMBER', presence: 'online' }
      : p.endsWith('/pins') ? { pins: [1, 2, 3].map(i => ({ message_id: id(i), author_id: author, preview: 'Synthetic pinned snippet '.repeat(8), pinned_at: '2026-10-12T11:00:00Z', message_created_at: '2026-10-12T10:00:00Z' })), can_manage: false, next_cursor: 'page-two' }
      : p.endsWith('/mentions') ? { mentions: [1, 2].map(i => ({ kind: 'CHANNEL', message_id: id(i), conversation_id: channel, author_id: author, created_at: '2026-10-12T10:00:00Z' })), next_cursor: 'page-two' }
      : p.endsWith('/archives/text-channels') ? { channels: [{ id: channel, name, category_name: 'Общее', description: '', archived_at: '2026-10-12T10:00:00Z' }], revision: 1, can_manage: false }
      : p.endsWith('/search/messages') ? { messages: Array.from({ length: 30 }, (_, i) => ({ ...message(i + 1), kind: 'CHANNEL' })), next_cursor: 'page-two' }
      : p.endsWith('/messages') ? { messages: [message(1), message(2)], next_cursor: url.searchParams.has('before') ? undefined : 'page-two' }
      : { members: [] }
    return route.fulfill({ json })
  })
}
