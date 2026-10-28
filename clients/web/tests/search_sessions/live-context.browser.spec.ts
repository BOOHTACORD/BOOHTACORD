import { expect, test } from '@playwright/test'

for (const kind of ['CHANNEL', 'DIRECT_MESSAGE']) {
  test(`${kind} open context refreshes edits, hides deleted text/files and retains anchor`, async ({ page }, info) => {
    let revision = 1, reads = 0
    await page.route('**/api/v1/members/**', route => route.fulfill({ status: 404, json: {} }))
    await page.route('**/api/v1/**/own/messages?**', route => {
      reads++
      return route.fulfill({ json: { messages: [{
        id: 'target', channel_id: 'own', direct_message_id: 'own', author_id: 'author',
        client_message_id: 'synthetic', body: `Synthetic revision ${revision}`,
        created_at: '2026-10-28T19:00:00Z', revision, deleted: false, mention_user_ids: [],
        attachments: [{ id: 'attachment', original_name: 'qa-synthetic.txt', byte_size: 10 }],
      }] } })
    })
    await page.goto(`/tests/search_sessions/live-context.html?kind=${kind}`)
    const anchor = page.locator('[data-search-anchor]')
    await expect(anchor).toContainText('Synthetic revision 1')
    await expect(anchor).toContainText('qa-synthetic.txt')
    await expect(anchor).toBeFocused()
    const prefix = kind === 'CHANNEL' ? 'message.' : 'direct_message.message_'
    const send = (action: string, conversation = 'own') => page.evaluate(async ({ action, conversation }) => {
      await (window as any).contextHints.apply({ eventId: 'hint', kind: action, payload: {
        channel_id: conversation, direct_message_id: conversation, message_id: 'target',
      } })
    }, { action: prefix + action, conversation })
    revision = 2
    await send('updated', 'foreign')
    expect(reads).toBe(1)
    await expect(anchor).toContainText('Synthetic revision 1')
    await send('updated')
    await expect(anchor).toContainText('Synthetic revision 2')
    await expect(anchor).not.toContainText('Synthetic revision 1')
    await expect(anchor).toBeFocused()
    await send('deleted')
    await expect(anchor).toContainText('Сообщение удалено.')
    await expect(anchor).not.toContainText('Synthetic revision')
    await expect(anchor).not.toContainText('qa-synthetic.txt')
    await expect(anchor).toBeFocused()
    await page.screenshot({ path: info.outputPath(`deleted-${kind}.png`) })
    await page.evaluate(() => (window as any).contextHints.reset())
    await expect(page.locator('.search-context-list')).toHaveCount(0)
  })
}
