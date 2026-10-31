import { expect, test } from '@playwright/test'

test('stream viewer keeps return to participants visible in the bottom toolbar', async ({ page }, info) => {
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&single-stream')
    await page.evaluate(() => {
      const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720
      const context = canvas.getContext('2d')!; context.fillStyle = '#142f40'; context.fillRect(0, 0, 1280, 720)
      context.fillStyle = '#c4e4ff'; context.font = '48px sans-serif'; context.fillText('Тестовая трансляция', 80, 360)
      const video = document.querySelector('video')!; video.srcObject = canvas.captureStream(1); void video.play()
    })
    await expect(page.locator('.screen-loading-state')).not.toBeVisible()
    const stage = page.locator('.screen-stage')
    await stage.hover()

    const controls = page.getByRole('group', { name: 'Управление просмотром' })
    await expect(controls).toHaveCSS('opacity', '1')
    await expect(controls.getByRole('button', { name: 'Диагностика просмотра', exact: true })).toHaveCount(0)
    await expect(controls.getByRole('button', { name: 'Развернуть на весь экран', exact: true })).toBeVisible()

    const returnButton = controls.locator('.stream-toolbar-actions').getByRole('button', { name: 'К участникам', exact: true })
    await expect(returnButton).toBeVisible()
    await expect(controls.locator('.stream-more-actions')).toHaveCount(0)
    await expect(returnButton).toHaveAttribute('title', 'К участникам')
    await expect(returnButton.locator('svg')).toHaveCount(1)
    await expect(returnButton.locator('.gc-sr-only')).toHaveText('К участникам')
    await page.screenshot({ path: info.outputPath(`viewer-actions-${width}.png`) })

    await returnButton.click()
    expect(await page.evaluate(() => (window as any).__screenUI.events)).toContain('clear')
  }
})

test('owner keeps return to participants in the toolbar and quality controls in overflow', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&single-stream')
  await page.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720
    canvas.getContext('2d')!.fillRect(0, 0, 1280, 720)
    const video = document.querySelector('video')!; video.srcObject = canvas.captureStream(1); void video.play()
  })
  await expect(page.locator('.screen-loading-state')).not.toBeVisible()
  await page.locator('.screen-stage').hover()
  const controls = page.getByRole('group', { name: 'Управление просмотром' })
  const returnButton = controls.locator('.stream-toolbar-actions').getByRole('button', { name: 'К участникам', exact: true })
  await expect(returnButton).toBeVisible()
  await controls.locator('.stream-more-actions > summary').click()
  const menu = controls.locator('.stream-voice-return')
  await expect(menu.getByRole('button', { name: 'Качество трансляции', exact: true })).toBeVisible()
  await expect(menu.getByRole('button', { name: 'К участникам', exact: true })).toHaveCount(0)
})

for (const width of [390, 1440]) {
  test(`compact viewer gives video the available height at ${width}px`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&single-stream')
    await page.evaluate(() => {
      const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720
      const ctx = canvas.getContext('2d')!; ctx.fillStyle = '#142f40'; ctx.fillRect(0, 0, 1280, 720)
      ctx.fillStyle = '#c4e4ff'; ctx.font = '48px sans-serif'; ctx.fillText('Тестовая трансляция · 1280 × 720', 80, 360)
      const video = document.querySelector('video')!; video.srcObject = canvas.captureStream(1); void video.play()
    })
    await expect(page.locator('.screen-loading-state')).not.toBeVisible()
    const stage = page.locator('.screen-stage')
    const room = page.locator('.voice-room')
    expect((await stage.boundingBox())!.height).toBeGreaterThanOrEqual((await room.boundingBox())!.height - 26)
    await expect(page.getByTestId('stream-rail')).toHaveCount(0)
    await expect(page.getByTestId('viewer-participants')).not.toBeVisible()
    const participants = page.getByRole('button', { name: /Участники · 3/ })
    await participants.click()
    await expect(page.getByTestId('viewer-participants')).toBeVisible()
    expect((await stage.boundingBox())!.height).toBeGreaterThanOrEqual((await room.boundingBox())!.height - 26)
    await page.keyboard.press('Escape')
    await expect(page.getByTestId('viewer-participants')).not.toBeVisible()
    await expect(participants).toBeFocused()
    await participants.click()
    await stage.click({ position: { x: 20, y: (await stage.boundingBox())!.height - 180 } })
    await expect(page.getByTestId('viewer-participants')).not.toBeVisible()
    const controls = page.getByRole('group', { name: 'Управление просмотром' })
    await expect(controls).toHaveCSS('opacity', '0')
    await page.screenshot({ path: info.outputPath(`compact-viewer-${width}.png`) })
    await stage.hover()
    await expect(controls).toHaveCSS('opacity', '1')
    await page.screenshot({ path: info.outputPath(`compact-controls-${width}.png`) })
    await page.getByLabel('Дополнительные действия', { exact: true }).click()
    await expect(controls.getByRole('button', { name: 'Диагностика просмотра', exact: true })).toHaveCount(0)
    await expect(controls.getByRole('button', { name: 'Развернуть на всю область', exact: true })).toHaveCount(0)
    await expect(controls.locator('.stream-toolbar-actions').getByRole('button', { name: 'К участникам', exact: true })).toHaveAttribute('title', 'К участникам')
  })
}

test('compact viewer keeps the stream stage visible in a wide 208px viewport', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 208 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&single-stream')
  const geometry = await page.locator('.screen-stage').evaluate(stage => {
    const rect = stage.getBoundingClientRect()
    const dock = document.querySelector('.mobile-voice-dock')
    const dockStyle = dock ? getComputedStyle(dock) : null
    const dockRect = dock && dockStyle?.display !== 'none' ? dock.getBoundingClientRect() : null
    const dockCoversStage = Boolean(dockRect && rect.right > dockRect.left && rect.left < dockRect.right)
    const top = Math.max(0, rect.top)
    const bottom = Math.min(innerHeight, rect.bottom, dockCoversStage ? dockRect.top : innerHeight)
    return { height: rect.height, visibleHeight: Math.max(0, bottom - top) }
  })
  expect(geometry.height, JSON.stringify(geometry)).toBeGreaterThanOrEqual(160)
  expect(geometry.visibleHeight, JSON.stringify(geometry)).toBeGreaterThanOrEqual(80)
})

test('stream switcher remains available without taking video height', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls')
  const stage = page.locator('.screen-stage')
  const height = (await stage.boundingBox())!.height
  await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()
  await page.getByTestId('stream-select').filter({ hasText: 'Участник показывает экран' }).click()
  await expect(page.locator('.screen-stage-label')).toContainText('Участник показывает экран')
  await expect(page.getByTestId('stream-rail')).not.toBeVisible()
  expect((await stage.boundingBox())!.height).toBe(height)
})

test('participant panel uses the open video space without a full-width blank area', async ({ page }, info) => {
  await page.route(/\/api\/v1\/members\/[^/]+\/avatar(?:\?.*)?$/, route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>',
  }))
  await page.setViewportSize({ width: 653, height: 366 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-strip&single-stream&single-participant&height=366')
  await page.getByRole('button', { name: /Участники · 1/ }).click()

  const panel = page.locator('.screen-viewer-panel-content')
  const strip = page.getByTestId('viewer-participants')
  const bounds = await panel.evaluate(element => {
    const panelRect = element.getBoundingClientRect()
    const stripRect = element.querySelector('.voice-viewer-participant-strip')!.getBoundingClientRect()
    return { width: panelRect.width, stripTop: stripRect.top, panelTop: panelRect.top }
  })

  expect(bounds.width).toBeLessThanOrEqual(260)
  expect(bounds.stripTop - bounds.panelTop).toBeLessThanOrEqual(28)
  await expect(strip.locator('.voice-viewer-participant')).toHaveCount(1)
  await page.screenshot({ path: info.outputPath('compact-participant-panel-653.png') })
})

test('statistics stay usable inside browser fullscreen', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&single-stream')
  const stage = page.locator('.screen-stage')
  await stage.hover()
  await page.getByRole('button', { name: 'Развернуть на весь экран', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(true)
  await page.getByLabel('Статистика', { exact: true }).click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await expect(panel).toBeVisible()
  expect(await panel.evaluate(element => document.fullscreenElement?.contains(element))).toBe(true)
  await panel.getByRole('button', { name: 'Закрыть статистику', exact: true }).click()
  await page.getByRole('button', { name: 'Свернуть просмотр', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(false)
})

test('an unselected viewer can choose its first stream', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&unselected')
  await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()
  await page.getByTestId('stream-select').first().click()
  await expect(page.locator('.screen-stage-label')).toContainText('Ваш экран')
})

test('subscription recovery remains visible while controls are idle', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&subscription-error')
  await expect(page.getByRole('button', { name: 'Повторить подключение к демонстрации', exact: true })).toBeVisible()
  await expect(page.getByRole('group', { name: 'Управление просмотром' })).toHaveCSS('opacity', '0')
})

for (const width of [320, 390]) {
  for (const remote of [false, true]) {
    test(`mobile controls stay in one row at ${width}px, remote=${remote}`, async ({ page }, info) => {
      await page.setViewportSize({ width, height: 900 })
      await page.goto(`/tests/screen_share_ui/fixture.html?viewer-controls&single-stream${remote ? '&watching-remote' : ''}`)
      await page.locator('.screen-stage').hover()
      const controls = page.getByRole('group', { name: 'Управление просмотром' })
      await expect(controls).toHaveCSS('opacity', '1')
      await page.screenshot({ path: info.outputPath(`single-row-${width}-${remote}.png`) })
      const rects = await controls.locator('button, summary').evaluateAll(elements => elements.filter(e => e.checkVisibility()).map(e => {
        const r = e.getBoundingClientRect(); return { name: e.getAttribute('aria-label') || e.textContent, top: r.top, bottom: r.bottom, left: r.left, right: r.right }
      }))
      expect(Math.max(...rects.map(r => r.top)) - Math.min(...rects.map(r => r.top)), JSON.stringify(rects)).toBeLessThanOrEqual(2)
      expect(Math.min(...rects.map(r => r.left))).toBeGreaterThanOrEqual(0)
      expect(Math.max(...rects.map(r => r.right))).toBeLessThanOrEqual(width)
    })
  }
}
