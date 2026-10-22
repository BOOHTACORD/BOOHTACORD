import { expect, test } from '@playwright/test'

test('category context menu closes outside and with Escape', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1280, height: 800 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const [{ createApp, h }, { createPinia }, { default: ChannelNavigation }] = await Promise.all([
      load('/node_modules/.vite/deps/vue.js'),
      load('/node_modules/.vite/deps/pinia.js'),
      load('/src/channel/ChannelNavigation.vue'),
    ])
    const qaWindow = window as Window & { __qaOutsideActionCount?: number }
    qaWindow.__qaOutsideActionCount = 0
    document.body.innerHTML = '<button id="outside">Outside action</button><div id="mount"></div>'
    document.getElementById('outside')?.addEventListener('click', () => qaWindow.__qaOutsideActionCount!++)
    const app = createApp({ render: () => h(ChannelNavigation, {
      accountId: 'qa-context-menu',
      topology: { revision: 1, categories: [{ id: 'qa-general', name: 'General', position: 0, channels: [] }] },
      voicePresence: null,
      permissions: {
        'category.create': true,
        'category.delete': true,
        'channel.text.create': true,
        'channel.text.delete': false,
        'channel.voice.create': true,
        'channel.voice.delete': false,
      },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const category = page.locator('.channel-category').filter({ hasText: 'General' })
  const menu = page.locator('.category-context-menu')
  await category.click({ button: 'right' })
  await expect(menu).toBeVisible()
  await page.screenshot({ path: testInfo.outputPath('category-context-menu-open.png') })

  const outside = page.getByRole('button', { name: 'Outside action', exact: true })
  await outside.click()
  await expect(menu).toHaveCount(0)
  await expect(outside).toBeFocused()
  expect(await page.evaluate(() => (window as Window & { __qaOutsideActionCount: number }).__qaOutsideActionCount)).toBe(1)

  await category.click({ button: 'right' })
  await expect(menu).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(menu).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Свернуть раздел General', exact: true })).toBeFocused()
})
