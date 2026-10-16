import type { Page } from '@playwright/test'
export const id = '11111111-1111-4111-8111-111111111111'
export async function fixtureRoutes(page: Page) {
  await page.route('**/api/v1/**', route => {
    const { pathname: path, search } = new URL(route.request().url())
    const message = { id: 'message', channel_id: id, author_id: 'author', client_message_id: 'message-client', body: '', created_at: '2026-10-15T12:00:00Z', revision: 1, deleted: false, mention_user_ids: [], attachments: [{ id: 'file', original_name: 'Отчёт.pdf', byte_size: 2048 }] }
    const body = path.endsWith('/admin/guild-settings') ? { name: 'Тестовая гильдия', revision: 1, welcome_channel_id: null }
      : path.endsWith('/archives/text-channels') ? { revision: 1, can_manage: true, channels: [{ id, name: 'История', description: '', category_name: 'Общее', archived_at: '2026-10-15T12:00:00Z' }] }
        : path.endsWith('/channels') ? { revision: 1, categories: [{ id: 'category', name: 'Общее', position: 0, channels: [{ id, name: 'Общий чат', kind: 'TEXT', position: 0, admission_closed: false, unread_count: 0, mention_count: 0 }] }] }
          : path.endsWith('/messages') ? { messages: [message], ...(search ? {} : { next_cursor: 'older' }) }
            : path.endsWith('/members') ? { members: [] } : {}
    return route.fulfill({ json: body })
  })
}
