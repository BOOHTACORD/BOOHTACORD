import { expect, test } from '@playwright/test'

const id = '33333333-3333-4333-8333-333333333333'
const mention = { message_id: '22222222-2222-4222-8222-222222222222', conversation_id: id,
  author_id: '44444444-4444-4444-8444-444444444444', created_at: '2026-10-12T12:00:00Z' }

for (const kind of ['CHANNEL', 'DIRECT_MESSAGE']) {
  for (const outcome of (kind === 'CHANNEL' ? ['VOICE', 'removed', '403', 'allowed'] : ['removed', '403', 'allowed'])) {
    test(`${kind} cached mention rechecks navigation: ${outcome}`, async ({ page }) => {
      let refreshes = 0
      await page.route('**/api/v1/mentions', route => route.fulfill({ json: { mentions: [{ ...mention, kind }] } }))
      await page.route('**/api/v1/members/*', route => route.fulfill({ json: {
        user_id: mention.author_id, login: 'author', display_name: 'Автор', role: 'MEMBER', presence: 'online',
      } }))
      await page.route(kind === 'CHANNEL' ? '**/api/v1/channels' : '**/api/v1/direct-messages', route => {
        refreshes++
        if (outcome === '403') return route.fulfill({ status: 403, json: { error: { code: 'DENIED' } } })
        if (kind === 'DIRECT_MESSAGE') return route.fulfill({ json: { direct_messages: outcome === 'allowed' ? [{
          id, other_participant_id: mention.author_id, other_participant_display_name: 'Автор', created_at: mention.created_at,
          unread_count: 0, mention_count: 0,
        }] : [] } })
        return route.fulfill({ json: { revision: 2, categories: [{ id: 'category', name: 'Fixture', position: 0,
          channels: outcome === 'removed' ? [] : [{ id, name: 'Fresh', kind: outcome === 'VOICE' ? 'VOICE' : 'TEXT',
            position: 0, admission_closed: false, unread_count: 0, mention_count: 0 }] }] } })
      })
      await page.goto('/tests/mentions_inbox/workspace_fixture.html')
      await page.getByRole('button', { name: 'Упоминания', exact: true }).click()
      await page.getByTestId('mention-inbox').getByRole('button', { name: /Перейти к упоминанию/ }).click()
      if (outcome === 'allowed') await expect(page.locator('body')).toHaveAttribute('data-opened', kind)
      else {
        await expect(page.getByRole('alert')).toContainText(kind === 'CHANNEL' ? 'Канал с упоминанием больше недоступен.' : 'Личный диалог больше недоступен.')
        await expect(page.locator('body')).not.toHaveAttribute('data-opened')
      }
      expect(refreshes).toBe(1)
    })
  }
}
