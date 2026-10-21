import { expect, test } from '@playwright/test'

for (const width of [320, 393, 1440]) {
  test(`installation telemetry consent and narrow layout ${width}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    let mode = 'local_only', mutations = 0
    await page.route('**/api/v1/admin/telemetry', async route => {
      if (route.request().method() === 'PATCH') { const body = route.request().postDataJSON(); if (body.mode === 'central') expect(body.confirmed).toBe(true); mode = body.mode; mutations++ }
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ installation_id: '11111111-1111-4111-8111-111111111111', mode, state: mode === 'central' ? 'never_connected' : 'disabled', registered: mode === 'central', last_accepted_at: null, queued: 0, dropped: 0 }) })
    })
    await page.goto('/')
    await page.evaluate(async () => {
      const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
      const { default: Settings } = await import('/src/admin/telemetry/AdminTelemetrySettings.vue')
      document.body.innerHTML = '<main style="max-width:800px;margin:auto"><div id="mount"></div></main>'
      createApp({ render: () => h(Settings) }).mount('#mount')
      await document.fonts.ready
    })
    await expect(page.getByText('Только локально', { exact: true })).toBeVisible()
    await page.getByLabel('HTTPS-адрес центра').fill('https://central.example.test')
    await expect(page.getByRole('button', { name: 'Подключить центр' })).toBeDisabled()
    expect(mutations).toBe(0)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    await page.getByRole('checkbox').check()
    await page.getByRole('button', { name: 'Подключить центр' }).click()
    await expect(page.getByRole('button', { name: 'Выключить отправку' })).toBeVisible()
    await page.getByRole('button', { name: 'Выключить отправку' }).click()
    await expect(page.getByText('Только локально', { exact: true })).toBeVisible()
    expect(mutations).toBe(2)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
    await page.screenshot({ path: test.info().outputPath(`installation-telemetry-${width}.png`), fullPage: true })
  })
}
