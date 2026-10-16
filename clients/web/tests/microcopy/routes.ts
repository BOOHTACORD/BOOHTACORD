import type { Page } from '@playwright/test'
import { fixtureRoutes, id } from '../control_consistency/routes'
import { installReferenceTransports } from '../../artifacts/design-v2/reference-live-state.mjs'
export async function routes(page: Page) {
  await installReferenceTransports(page)
  await fixtureRoutes(page)
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname
    const permissions = { 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true, 'channel.voice.delete': true, 'category.create': true, 'category.delete': true }
    const timestamp = new Date().toISOString()
    const probe = { status: 'ready', sampled_at: timestamp, pending_revocations: 0, available_bytes: 1e10, total_bytes: 2e10, reserved_bytes: 0, protected_bytes: 0, headroom_bytes: 1e10 }
    const profile = { account_id: id, login: 'fixture', display_name: 'Тестовый участник', role: 'ADMINISTRATOR', avatar_url: null }
    const body = path.endsWith('/auth/session') ? { account_id: id, role: 'ADMINISTRATOR' }
      : path.endsWith('/auth/permissions') ? { ...profile, permissions_revision: 1, permissions }
      : path.endsWith('/me') ? profile
      : path.endsWith('/admin/accounts') ? { accounts: [] }
      : path.endsWith('/admin/roles') ? { revision: 1, roles: [{ role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions }, { role: 'MEMBER', display_name: 'Участник', editable: true, permissions }] }
      : path.endsWith('/admin/audit') ? { events: [] }
      : path.endsWith('/admin/screen-metrics') ? { samples: [] }
      : path.endsWith('/admin/readiness') ? { status: 'ready', checked_at: timestamp, database: probe, sfu: probe, storage: probe }
      : path.includes('/sessions') ? { account_id: id, sessions: [], next_cursor: null }
      : path.endsWith('/mentions') ? { mentions: [] }
      : path.endsWith('/read-cursor') ? { message_id: null }
      : path.includes('/messages') && !path.includes('/archives/') ? { messages: [] }
      : undefined
    if (body !== undefined) return route.fulfill({ json: body })
    return route.fallback()
  })
}
