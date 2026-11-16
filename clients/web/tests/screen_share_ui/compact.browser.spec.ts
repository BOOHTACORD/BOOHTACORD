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
    await expect(controls.getByRole('button', { name: 'Включить полноэкранный режим', exact: true })).toBeVisible()
    await expect(controls.getByRole('button', { name: 'Прекратить просмотр', exact: true })).toHaveCount(0)

    const returnButton = controls.locator('.stream-toolbar-actions').getByRole('button', { name: 'К участникам', exact: true })
    await expect(page.getByRole('button', { name: 'К участникам', exact: true })).toHaveCount(1)
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
  await expect(controls.getByRole('button', { name: 'Остановить свою трансляцию', exact: true })).toHaveClass(/stream-stop-screen-button/)
  await expect(controls.getByRole('button', { name: 'Прекратить просмотр', exact: true })).toHaveCount(0)
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
    await expect(page.getByRole('button', { name: /^Трансляции/ })).toHaveCount(0)
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
    await expect(controls.getByRole('button', { name: 'Вернуть просмотр в приложение', exact: true })).toHaveCount(0)
    await expect(controls.locator('.stream-toolbar-actions').getByRole('button', { name: 'К участникам', exact: true })).toHaveAttribute('title', 'К участникам')
  })
}

test('pausing and resuming a stream controls its video and audio together', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&single-stream')
  await page.evaluate(() => {
    const canvas = document.createElement('canvas'); canvas.width = 1280; canvas.height = 720
    const context = canvas.getContext('2d')!; context.fillStyle = '#142f40'; context.fillRect(0, 0, 1280, 720)
    const video = document.querySelector('video')!
    video.srcObject = canvas.captureStream(1)
    void video.play()

    const audio = document.querySelector('audio')!
    const playback = { paused: false, pauseCalls: 0, playCalls: 0 }
    Object.defineProperty(audio, 'paused', { configurable: true, get: () => playback.paused })
    audio.pause = () => { playback.paused = true; playback.pauseCalls += 1 }
    audio.play = () => { playback.paused = false; playback.playCalls += 1; return Promise.resolve() }
    ;(window as any).__screenUI.audioPlayback = playback
  })
  await expect(page.locator('.screen-loading-state')).not.toBeVisible()
  await page.locator('.screen-stage').hover()
  await page.getByRole('button', { name: 'Приостановить локальное воспроизведение', exact: true }).click()
  await expect.poll(() => page.locator('video').evaluate(element => (element as HTMLVideoElement).paused)).toBe(true)
  await expect.poll(() => page.evaluate(() => (window as any).__screenUI.audioPlayback)).toEqual({ paused: true, pauseCalls: 1, playCalls: 0 })

  await page.getByRole('button', { name: 'Продолжить локальное воспроизведение', exact: true }).click()
  await expect.poll(() => page.locator('video').evaluate(element => (element as HTMLVideoElement).paused)).toBe(false)
  await expect.poll(() => page.evaluate(() => (window as any).__screenUI.audioPlayback)).toEqual({ paused: false, pauseCalls: 1, playCalls: 1 })
})

test('narrow viewer opens an accessible volume popover and restores focus on Escape', async ({ page }, info) => {
  for (const width of [320, 390]) {
    await page.setViewportSize({ width, height: 844 })
    await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&single-stream')
    const stage = page.locator('.screen-stage')
    await stage.hover()

    const opener = page.getByRole('button', { name: 'Открыть регулировку громкости трансляции', exact: true })
    await expect(opener).toBeVisible()
    await expect(opener).toHaveAttribute('aria-expanded', 'false')
    await opener.click()

    const popover = page.getByRole('group', { name: 'Громкость звука выбранной демонстрации', exact: true })
    const slider = popover.getByRole('slider', { name: 'Громкость звука выбранной демонстрации' })
    await expect(popover).toBeVisible()
    await expect(slider).toBeVisible()
    await expect(slider).toHaveAttribute('min', '0')
    await expect(slider).toHaveAttribute('max', '200')
    await expect(popover.getByRole('button', { name: 'Выключить звук трансляции', exact: true })).toBeVisible()
    const bounds = await Promise.all([popover.boundingBox(), stage.boundingBox()])
    expect(bounds[0]!.x).toBeGreaterThanOrEqual(bounds[1]!.x)
    expect(bounds[0]!.x + bounds[0]!.width).toBeLessThanOrEqual(bounds[1]!.x + bounds[1]!.width)
    await page.screenshot({ path: info.outputPath(`viewer-volume-popover-${width}.png`) })

    await page.keyboard.press('Escape')
    await expect(popover).toBeHidden()
    await expect(opener).toBeFocused()
  }
})


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

test('an unselected single stream gets one large 16:9 card', async ({ page }, info) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&unselected&single-stream&no-thumbnail')
  await page.getByRole('button', { name: 'Трансляции · 1', exact: true }).click()

  const card = page.getByTestId('stream-select')
  await expect(card).toHaveCount(1)
  await expect(card).toHaveAttribute('aria-pressed', 'false')
  await expect(card).toContainText('Эфир')
  await expect(card).toContainText('Предпросмотр загружается')
  const preview = await card.locator('.stream-card-preview').boundingBox()
  expect(preview).not.toBeNull()
  expect(preview!.width / preview!.height).toBeCloseTo(16 / 9, 1)
  expect(preview!.width).toBeGreaterThan(300)
  await expect(page.getByTestId('stream-rail').locator('video')).toHaveCount(0)
  await page.screenshot({ path: info.outputPath('single-stream-switcher.png') })
})

test('two streams fill the popover evenly and distinguish live from selected', async ({ page }, info) => {
  await page.route('**/screen-preview.svg', route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900"><rect width="1600" height="900" fill="#26354c"/><text x="50" y="450" fill="white">Preview</text></svg>',
  }))
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls')
  await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()

  const cards = page.getByTestId('stream-select')
  await expect(cards).toHaveCount(2)
  await expect(cards.nth(0).locator('.stream-card-preview img')).toBeVisible()
  await expect(cards.nth(1).locator('.stream-card-preview img')).toBeVisible()
  await expect.poll(() => cards.nth(1).locator('.stream-card-preview img').evaluate(element => (element as HTMLImageElement).complete && (element as HTMLImageElement).naturalWidth > 0)).toBe(true)
  await expect(cards.nth(0)).toContainText('Эфир')
  await expect(cards.nth(0)).toContainText('Смотрим')
  await expect(cards.nth(1)).toContainText('Эфир')
  await expect(cards.nth(1)).not.toContainText('Смотрим')
  await expect(cards.nth(1)).toContainText('Цель: 1080p · 60 FPS')
  await expect(cards.nth(0)).toHaveAttribute('aria-pressed', 'true')
  await expect(cards.nth(1)).toHaveAttribute('aria-pressed', 'false')
  const bounds = await cards.evaluateAll(elements => elements.map(element => {
    const card = element.getBoundingClientRect()
    const preview = element.querySelector('.stream-card-preview')!.getBoundingClientRect()
    return { left: card.left, width: card.width, ratio: preview.width / preview.height }
  }))
  expect(Math.abs(bounds[0].width - bounds[1].width)).toBeLessThanOrEqual(1)
  expect(Math.abs((bounds[0].left + bounds[0].width) - bounds[1].left)).toBeLessThanOrEqual(12)
  expect(bounds[0].ratio).toBeCloseTo(16 / 9, 1)
  await page.screenshot({ path: info.outputPath('stream-switcher-two-cards.png') })
})

test('many streams use a responsive grid with internal vertical scrolling', async ({ page }, info) => {
  await page.route('**/screen-preview.svg', route => route.fulfill({ status: 200, contentType: 'image/svg+xml', body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 9"><rect width="16" height="9" fill="#26354c"/></svg>' }))
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&eight-streams')
  await page.getByRole('button', { name: 'Трансляции · 8', exact: true }).click()

  const rail = page.getByTestId('stream-rail')
  await expect(rail.getByTestId('stream-select')).toHaveCount(8)
  await expect(rail.getByTestId('stream-select').nth(2)).toHaveAccessibleName('Экран Участник с длинным именем 3 · Эфир')
  await expect(rail.getByTestId('stream-select').nth(2)).toHaveAttribute('title', 'Экран Участник с длинным именем 3 · Эфир')
  const desktop = await rail.evaluate(element => {
    const style = getComputedStyle(element)
    return { columns: style.gridTemplateColumns.split(' ').length, clientHeight: element.clientHeight, scrollHeight: element.scrollHeight, overflowY: style.overflowY }
  })
  expect(desktop.columns).toBe(2)
  expect(desktop.overflowY).toBe('auto')
  expect(desktop.scrollHeight).toBeGreaterThan(desktop.clientHeight)
  await page.screenshot({ path: info.outputPath('stream-switcher-eight-desktop.png') })

  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&eight-streams')
  await page.getByRole('button', { name: 'Трансляции · 8', exact: true }).click()
  const narrow = await page.getByTestId('stream-rail').evaluate(element => ({
    columns: getComputedStyle(element).gridTemplateColumns.split(' ').length,
    viewportWidth: innerWidth,
    right: element.getBoundingClientRect().right,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
  }))
  expect(narrow.columns).toBe(1)
  expect(narrow.right).toBeLessThanOrEqual(narrow.viewportWidth)
  expect(narrow.scrollHeight).toBeGreaterThan(narrow.clientHeight)
  await page.screenshot({ path: info.outputPath('stream-switcher-eight-mobile.png') })
})

test('preview loading and failure keep the live publication available', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&no-thumbnail')
  await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()
  const loadingCard = page.getByTestId('stream-select').nth(1)
  await expect(loadingCard).toContainText('Эфир')
  await expect(loadingCard).toContainText('Предпросмотр загружается')

  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&preview-unavailable')
  await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()
  const unavailableCard = page.getByTestId('stream-select').nth(1)
  await expect(unavailableCard).toContainText('Эфир')
  await expect(unavailableCard).toContainText('Предпросмотр недоступен')
  await expect(unavailableCard).toHaveAttribute('aria-pressed', 'false')
})

test('keyboard selection changes one viewer stream, closes the popover and restores focus', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls')
  const trigger = page.getByRole('button', { name: 'Трансляции · 2', exact: true })
  await trigger.click()
  const remote = page.getByTestId('stream-select').nth(1)
  await remote.focus()
  await page.keyboard.press('Enter')

  await expect(page.locator('.screen-stage-label')).toContainText('Участник показывает экран')
  await expect(page.getByTestId('stream-rail')).not.toBeVisible()
  await expect(trigger).toBeFocused()
  await expect(page.locator('.screen-player')).toHaveCount(1)
  await expect(page.locator('.screen-viewer-panel-content video')).toHaveCount(0)
  await expect.poll(() => page.evaluate(() => (window as any).__screenUI.events)).toContainEqual({ select: 'remote-screen' })
})

test('closing one publication refreshes the open switcher and offers the remaining stream', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls')
  const trigger = page.getByRole('button', { name: 'Трансляции · 2', exact: true })
  await trigger.click()
  await page.evaluate(() => (window as any).__screenUI.closeStream('local-screen'))

  await expect(page.locator('.screen-stage-label')).toHaveCount(0)
  const refreshedTrigger = page.getByRole('button', { name: 'Трансляции · 1', exact: true })
  await expect(refreshedTrigger).toBeVisible()
  await expect(page.getByTestId('stream-select')).toHaveCount(1)
  await expect(page.getByTestId('stream-select')).toContainText('Участник показывает экран')
  await page.getByTestId('stream-select').click()
  await expect(page.locator('.screen-stage-label')).toContainText('Участник показывает экран')
  await expect(page.getByTestId('stream-rail')).not.toBeVisible()
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

  expect(bounds.width).toBeLessThanOrEqual(280)
  expect(bounds.stripTop - bounds.panelTop).toBeLessThanOrEqual(28)
  await expect(strip.locator('.voice-viewer-participant')).toHaveCount(1)
  await page.screenshot({ path: info.outputPath('compact-participant-panel-653.png') })
})

test('statistics stay usable inside browser fullscreen', async ({ page }) => {
  await page.goto('/tests/screen_share_ui/fixture.html?viewer-controls&watching-remote&single-stream')
  const stage = page.locator('.screen-stage')
  await stage.hover()
  await page.getByRole('button', { name: 'Включить полноэкранный режим', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(true)
  await page.getByLabel('Статистика', { exact: true }).click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await expect(panel).toBeVisible()
  expect(await panel.evaluate(element => document.fullscreenElement?.contains(element))).toBe(true)
  await panel.getByRole('button', { name: 'Закрыть статистику', exact: true }).click()
  await page.getByRole('button', { name: 'Выйти из полноэкранного режима', exact: true }).click()
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
