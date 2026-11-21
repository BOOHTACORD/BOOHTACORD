import { expect, test } from '@playwright/test'

for (const width of [393, 1440]) {
  test(`pending topology create keeps focus inside modal at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    let release!: () => void
    let requested!: () => void
    const started = new Promise<void>(resolve => { requested = resolve })
    await page.route('**/api/v1/categories', async route => {
      requested()
      await new Promise<void>(resolve => { release = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ error: { code: 'UNAVAILABLE', message: 'QA service unavailable' } }) })
    })
    await page.goto('/')
    await page.evaluate(async () => {
      const { createApp, h } = await import('/tests/browser_runtime/fixture_dependencies.ts')
      const { createPinia } = await import('/tests/browser_runtime/fixture_dependencies.ts')
      const { default: Actions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
      const qaWindow = window as Window & { __qaUnderlyingEscapeCount?: number }
      qaWindow.__qaUnderlyingEscapeCount = 0
      window.addEventListener('keydown', event => { if (event.key === 'Escape') qaWindow.__qaUnderlyingEscapeCount!++ })
      document.body.innerHTML = '<button id="outside">Underlying navigation</button><div id="mount"></div>'
      const app = createApp({ render: () => h(Actions, {
        accountId: 'qa-fixture', voicePresence: null,
        topology: { revision: 1, categories: [] },
        permissions: { 'category.create': true, 'category.delete': false, 'channel.text.create': true, 'channel.text.delete': false, 'channel.voice.create': true, 'channel.voice.delete': false },
      }) })
      app.use(createPinia()); app.mount('#mount')
    })
    await page.getByRole('button', { name: 'Создать раздел или канал', exact: true }).click()
    const dialog = page.getByRole('dialog', { name: 'Создать раздел', exact: true })
    await dialog.getByLabel('Название раздела').fill('QA pending')
    await dialog.getByLabel('Название раздела').press('Enter')
    await started
    await expect(dialog.getByRole('button', { name: 'Создаём…' })).toBeDisabled()
    try {
      await expect.poll(() => dialog.evaluate(element => element.contains(document.activeElement))).toBe(true)
      for (const key of ['Tab', 'Shift+Tab', 'Enter', 'Escape']) {
        await page.keyboard.press(key)
        await expect(dialog).toBeVisible()
        expect(await dialog.evaluate(element => element.contains(document.activeElement))).toBe(true)
      }
      expect(await page.evaluate(() => (window as Window & { __qaUnderlyingEscapeCount: number }).__qaUnderlyingEscapeCount)).toBe(0)
    } finally { release() }
    await expect(dialog.getByRole('alert')).toBeVisible()
  })
}

for (const width of [393, 1440]) {
  test(`destructive confirmation Escape cancels without closing background at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/')
    await page.evaluate(async () => {
      const { createApp, h } = await import('/tests/browser_runtime/fixture_dependencies.ts')
      const { createPinia } = await import('/tests/browser_runtime/fixture_dependencies.ts')
      const { default: Actions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
      const qaWindow = window as Window & { __qaUnderlyingEscapeCount?: number }
      qaWindow.__qaUnderlyingEscapeCount = 0
      window.addEventListener('keydown', event => { if (event.key === 'Escape') qaWindow.__qaUnderlyingEscapeCount!++ })
      document.body.innerHTML = '<button id="outside">Underlying navigation</button><div id="mount"></div>'
      const app = createApp({ render: () => h(Actions, {
        accountId: 'qa-fixture', voicePresence: null,
        topology: { revision: 1, categories: [{id:'qa-category',name:'QA empty',position:0,channels:[]}] },
        permissions: { 'category.create': true, 'category.delete': true, 'channel.text.create': true, 'channel.text.delete': false, 'channel.voice.create': true, 'channel.voice.delete': false },
      }) })
      app.use(createPinia()); app.mount('#mount')
    })
    const trigger = page.getByRole('button', {name:'Действия с разделом QA empty',exact:true})
    await trigger.click()
    const dialog = page.getByRole('dialog', {name:'Подтвердите действие',exact:true})
    await expect(dialog.getByRole('button',{name:'Отмена',exact:true})).toBeFocused()
    await page.keyboard.press('Escape')
    await expect(dialog).toBeHidden()
    await expect(trigger).toBeFocused()
    expect(await page.evaluate(() => (window as Window & { __qaUnderlyingEscapeCount: number }).__qaUnderlyingEscapeCount)).toBe(0)
  })
}
