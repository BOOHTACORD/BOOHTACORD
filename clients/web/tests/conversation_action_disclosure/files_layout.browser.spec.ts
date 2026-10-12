import { expect, test } from '@playwright/test'

for (const kind of ['CHANNEL', 'DIRECT_MESSAGE']) {
  for (const width of [320, 393, 1440]) {
    test(`${kind} file metadata stays inside its table cells at ${width}px`, async ({ page }, testInfo) => {
      await page.setViewportSize({ width, height: 900 })
      await page.route('**/api/v1/**/qa-files/messages', route => route.fulfill({
        json: { messages: [{
          id: 'message', channel_id: 'qa-files', direct_message_id: 'qa-files',
          author_id: 'author', client_message_id: 'client-message', body: '',
          created_at: '2026-10-12T12:00:00Z', revision: 1, deleted: false, mention_user_ids: [],
          attachments: ['dm-new.png', 'dm-old-one.png', 'dm-old-two.png'].map((name, index) => ({
            id: `file-${index}`, original_name: name, byte_size: 70,
          })),
        }] },
      }))
      await page.goto('/')
      await page.evaluate(async kind => {
        const load = (path: string) => import(path)
        const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
        const { default: Files } = await load('/src/conversation/files_panel/ConversationFilesPanel.vue')
        document.body.innerHTML = '<div id="mount"></div>'
        createApp({ render: () => h(Files, { kind, conversationId: 'qa-files' }) }).mount('#mount')
      }, kind)
      await expect(page.locator('.conversation-files tbody tr')).toHaveCount(3)
      await page.evaluate(() => document.fonts.ready)
      const cells = await page.locator('.conversation-files th').evaluateAll(headers => headers.map(header => {
        const range = document.createRange()
        range.selectNodeContents(header)
        const ink = range.getBoundingClientRect()
        const cell = header.getBoundingClientRect()
        const style = getComputedStyle(header)
        return { inkLeft: ink.left, inkRight: ink.right, cellLeft: cell.left + parseFloat(style.paddingLeft) - 0.5, cellRight: cell.right - parseFloat(style.paddingRight) + 0.5 }
      }))
      for (const cell of cells) {
        expect(cell.inkLeft).toBeGreaterThanOrEqual(cell.cellLeft)
        expect(cell.inkRight).toBeLessThanOrEqual(cell.cellRight)
      }
      const panel = await page.locator('.conversation-files').boundingBox()
      expect(panel!.x + panel!.width).toBeLessThanOrEqual(width)
      await page.locator('.conversation-files').screenshot({ path: testInfo.outputPath(`files-${kind}-${width}.png`) })
    })
  }
}
