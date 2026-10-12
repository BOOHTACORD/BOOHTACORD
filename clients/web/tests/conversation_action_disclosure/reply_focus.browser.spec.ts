import { expect, test } from '@playwright/test'

test.describe('desktop message Reply focus', () => {
  test.use({ viewport: { width: 1440, height: 900 }, hasTouch: false, isMobile: false })
  test('returns focus to the message when the mobile disclosure is hidden', async ({ page }) => {
    await page.goto('/')
    await page.evaluate(async () => {
      const load = (path: string) => import(path)
      const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
      const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
      const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
      document.body.innerHTML = '<div id="mount"></div>'
      const app = createApp({ render: () => h(MessageItem, {
        message: { id: 'reply-focus-fixture', authorId: 'fixture-author', clientMessageId: 'fixture-client', body: 'Synthetic fixture', createdAt: '2026-10-12T12:00:00Z', revision: 1, deleted: false },
        canEdit: true, canDelete: true,
        onReply: () => { document.body.dataset.replyCount = String(Number(document.body.dataset.replyCount ?? '0') + 1) },
      }) })
      app.use(createPinia()); app.mount('#mount')
    })
    const row = page.locator('.message-row')
    await row.focus()
    await expect(row.locator('.message-actions-toggle')).toBeHidden()
    const reply = row.getByRole('button', { name: 'Ответить', exact: true })
    await reply.focus()
    await reply.press('Enter')
    await expect(page.locator('body')).toHaveAttribute('data-reply-count', '1')
    await expect(row).toBeFocused()
  })
})
