import { expect, test, type Page } from '@playwright/test'
import axe from 'axe-core'
import {
  ux2026BreakpointViewports,
  ux2026FunctionalViewports,
  ux2026RequiredViewports,
} from '../uiux_2026/viewport_matrix'
async function open(page: Page, query = '', width = 1440, scale = 100, height = 900) {
  await page.setViewportSize({ width, height })
  await page.goto(`/tests/screen_share_ui/fixture.html?scale=${scale}&${query}`)
}
async function clean(page: Page) {
  const actions = page.getByRole('group', { name: 'Управление просмотром' })
  if (await actions.count()) {
    await actions.getByRole('button').first().focus()
    await expect(actions).toHaveCSS('opacity', '1')
  }
  await page.addScriptTag({ content: axe.source })
  expect(await page.evaluate(async () => (await (window as any).axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] } })).violations.map((v: any) => ({ id: v.id, nodes: v.nodes.map((n: any) => ({ target: n.target, summary: n.failureSummary })) })))).toEqual([])
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  expect(await page.evaluate(() => Array.from(document.querySelectorAll<HTMLElement>('dialog h2, dialog button, .stream-diagnostics-panel button, .stream-diagnostics-panel summary')).filter(e => e.getClientRects().length).flatMap(e => {
    const r = e.getBoundingClientRect()
    return r.left < -1 || r.right > innerWidth + 1 || e.scrollWidth > e.clientWidth + 1 ? [e.textContent?.trim()] : []
  }))).toEqual([])
}
test('200% text keeps action labels and diagnostic words intact at desktop width', async ({ page }, info) => {
  await open(page, '', 1024, 200)
  const cancel = page.getByRole('button', { name: 'Отмена', exact: true })
  const cancelLineCount = await cancel.evaluate(element => {
    const range = document.createRange()
    range.selectNodeContents(element)
    return range.getClientRects().length
  })
  expect(cancelLineCount).toBe(1)
  await page.screenshot({ path: info.outputPath('launch-text-200-1024.png') })

  await open(page, 'receiver', 1024, 200)
  await page.locator('summary[aria-label="Статистика"]').click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await expect(panel).toBeVisible()
  await page.screenshot({ path: info.outputPath('receiver-text-200-1024.png') })
  const rows = page.locator('.stream-diagnostics-panel > dl dt, .stream-diagnostics-panel > dl dd')
  const splitWords = await rows.evaluateAll(elements => {
    const broken: string[] = []
    for (const element of elements) {
      const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT)
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        const text = node.textContent ?? ''
        for (const match of text.matchAll(/\S+/g)) {
          const range = document.createRange()
          range.setStart(node, match.index!)
          range.setEnd(node, match.index! + match[0].length)
          const lines = new Set(Array.from(range.getClientRects(), rect => Math.round(rect.top)))
          if (lines.size > 1) broken.push(match[0])
        }
      }
    }
    return broken
  })
  expect(splitWords).toEqual([])
  const overflowingRows = await rows.evaluateAll(elements => elements
    .filter(element => element.scrollWidth > element.clientWidth + 1)
    .map(element => element.textContent?.trim()))
  expect(overflowingRows).toEqual([])
})
test('launch keeps selection visible and technical details optional; one gesture emits without capture', async ({ page }) => {
  let capture = 0
  await page.addInitScript(() => { navigator.mediaDevices.getDisplayMedia = () => { throw new Error('unexpected capture') } })
  page.on('pageerror', () => capture++)
  await open(page)
  const details = page.locator('.screen-share-capabilities__details')
  await expect(details).not.toHaveAttribute('open', '')
  await expect(page.getByText('Рекомендуемый профиль', { exact: true })).toHaveCount(0)
  await expect(page.getByText(/Суммарный лимит двух слоёв/)).not.toBeVisible()
  await expect(page.getByText(/Текущий выбор: 1080p · 60 FPS/)).toBeVisible()
  await details.locator('summary').focus(); await page.keyboard.press('Enter')
  await expect(page.getByText(/Суммарный лимит двух слоёв/)).toBeVisible()
  await details.locator('summary').click()
  await page.getByRole('radio', { name: '1440p' }).check()
  await expect(page.getByRole('radio', { name: '60 FPS', exact: true })).toBeDisabled()
  await page.getByRole('radio', { name: /Чёткость текста/ }).check()
  await page.getByRole('button', { name: 'Начать трансляцию' }).click()
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual([{ profile: 'P1440_30', mode: 'text', activation: true }])
  expect(capture).toBe(0)
})

test('screen viewer keeps participant cards compact without horizontal scrolling', async ({ page }, info) => {
  await page.route(/\/api\/v1\/members\/[^/]+\/avatar(?:\?.*)?$/, route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>',
  }))
  for (const [width, scale] of [[320, 100], [390, 200], [1440, 100]]) {
    await open(page, 'viewer-strip', width, scale)
    await page.getByRole('button', { name: 'Трансляции · 2', exact: true }).click()
    await expect(page.getByTestId('stream-select')).toHaveCount(2)
    await expect(page.getByRole('heading', { name: 'Демонстрации в канале' })).toBeVisible()
    await page.getByRole('button', { name: /Участники · 3/ }).click()
  const strip = page.getByTestId('viewer-participants')
  await expect(strip.getByText('Участники', { exact: true })).toBeVisible()
  await expect(strip.getByText('3 в комнате', { exact: true })).toBeVisible()
  const participantCards = strip.locator('.voice-viewer-participant')
  await expect(participantCards).toHaveCount(3)
  await expect.poll(() => participantCards.first().evaluate(element => element.getBoundingClientRect().width)).toBeLessThanOrEqual(width <= 420 ? 320 : 176)
  const roster = strip.locator('ul')
  expect(await roster.evaluate(element => element.scrollWidth <= element.clientWidth + 1)).toBe(true)
  const watcherCount = strip.getByRole('status', { name: 'Зрители трансляции: 1' })
  await expect(watcherCount).toBeVisible()
  await expect(watcherCount).toHaveAttribute('title', 'Зрители трансляции: 1')
  await expect(watcherCount).toContainText('1')
  await expect(strip.getByRole('img', { name: 'Смотрит вашу трансляцию' })).toHaveCount(1)
  await expect(strip.getByText('Участник говорит', { exact: true })).toBeVisible()
  await expect(strip.getByText('Участник показывает экран', { exact: true })).toBeVisible()
  await expect(page.locator('.screen-stage-label')).toContainText('Ваш экран')
  await expect(page.locator('.screen-stage-label')).toContainText('ЭФИР')
  await expect(strip.getByRole('img', { name: 'Показывает экран' })).toHaveCount(2)
  await expect(strip.getByRole('img', { name: 'Микрофон выключен' })).toHaveCount(2)
  await expect(strip.getByRole('img', { name: 'Говорит' })).toHaveCount(1)
  const avatars = strip.locator('.voice-viewer-participant-avatar')
  await expect(avatars.locator('img')).toHaveCount(2)
  await expect(avatars.nth(0).locator('img')).toHaveAttribute('src', '/api/v1/members/local-user/avatar?revision=2')
  await expect(avatars.nth(1).locator('img')).toHaveAttribute('src', '/api/v1/members/member-speaking/avatar?revision=3')
  await expect.poll(() => avatars.nth(0).locator('img').evaluate(image => (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0)
  await expect(avatars.nth(2)).toContainText('УЧ')
    await clean(page)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    await page.screenshot({ path: info.outputPath(`viewer-participants-${width}-${scale}.png`) })
  }
})

test('listener room embeds the stream preview in an equal-sized participant card', async ({ page }, info) => {
  await page.route('**/synthetic-screen.svg', route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><rect width="640" height="360" fill="#16283e"/><path d="M0 280 160 170l120 70 150-130 210 100v150H0Z" fill="#315c83"/><circle cx="462" cy="136" r="18" fill="#84c8ff"/></svg>',
  }))
  await page.route(/\/api\/v1\/members\/[^/]+\/avatar(?:\?.*)?$/, route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>',
  }))

  await open(page, 'participant-cards', 876, 100, 656)
  const cards = page.getByTestId('participant-card')
  const streamCard = page.locator('.participant--streaming')
  const voiceOnlyCard = page.locator('.participant--voice-only')
  const preview = page.getByTestId('participant-screen-preview')
  await expect(cards).toHaveCount(2)
  await expect(streamCard).toHaveCount(1)
  await expect(voiceOnlyCard).toHaveCount(1)
  await expect(preview).toBeVisible()
  await expect(preview.locator('img')).toHaveAttribute('src', '/synthetic-screen.svg')
  await expect.poll(() => preview.locator('img').evaluate(image => (image as HTMLImageElement).naturalWidth)).toBe(640)
  await expect(preview.locator('.participant-screen-preview__caption')).toHaveText('Экран · 1080p · 60 FPS')
  await expect(preview.locator('.participant-screen-preview__live')).toHaveCSS('top', '10px')
  await expect(preview.locator('.participant-screen-preview__live')).toHaveCSS('right', '10px')
  expect(await preview.evaluate(button => {
    const caption = button.querySelector('.participant-screen-preview__caption')!.getBoundingClientRect()
    const live = button.querySelector('.participant-screen-preview__live')!.getBoundingClientRect()
    return caption.right <= live.left
  })).toBe(true)
  const playOverlay = preview.locator('.participant-screen-preview__play')
  await expect(playOverlay).toBeVisible()
  await expect(playOverlay).toHaveCSS('opacity', '1')
  const overlayPosition = await preview.evaluate(button => {
    const buttonRect = button.getBoundingClientRect()
    const overlayRect = button.querySelector('.participant-screen-preview__play')!.getBoundingClientRect()
    return { buttonCenterX: buttonRect.left + buttonRect.width / 2, buttonCenterY: buttonRect.top + buttonRect.height / 2, overlayCenterX: overlayRect.left + overlayRect.width / 2, overlayCenterY: overlayRect.top + overlayRect.height / 2 }
  })
  expect(Math.abs(overlayPosition.buttonCenterX - overlayPosition.overlayCenterX)).toBeLessThanOrEqual(1)
  expect(Math.abs(overlayPosition.buttonCenterY - overlayPosition.overlayCenterY)).toBeLessThanOrEqual(1)
  await expect(page.locator('.screen-rail-section')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Смотреть экран', exact: true })).toHaveCount(0)
  await expect(voiceOnlyCard.locator('.participant-voice-placeholder')).toBeVisible()
  await expect(streamCard.locator('.participant-card-info .participant-name')).toHaveCSS('text-align', 'left')
  await expect(voiceOnlyCard.locator('.participant-card-info .participant-name')).toHaveCSS('text-align', 'left')
  for (const card of [streamCard, voiceOnlyCard]) {
    const muteNameCenterOffset = await card.locator('.participant-card-status').evaluate(element => {
      const icon = element.querySelector<SVGElement>('.voice-person-state-icon')!.getBoundingClientRect()
      const name = element.closest('.participant-card-info')!.querySelector<HTMLElement>('.participant-name')!.getBoundingClientRect()
      return Math.abs(icon.top + icon.height / 2 - (name.top + name.height / 2))
    })
    expect(muteNameCenterOffset).toBeLessThanOrEqual(1)
  }
  await expect.poll(() => page.evaluate(() => (window as any).__screenUI.isPreviewVisible())).toBe(true)
  const desktopGeometry = await cards.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect()
    return { width: rect.width, height: rect.height }
  }))
  const previewGeometry = await preview.boundingBox()
  expect(Math.abs(desktopGeometry[0].width - desktopGeometry[1].width)).toBeLessThanOrEqual(1)
  expect(Math.abs(desktopGeometry[0].height - desktopGeometry[1].height)).toBeLessThanOrEqual(1)
  expect(desktopGeometry[0].width).toBeGreaterThanOrEqual(250)
  expect(previewGeometry?.height ?? 0).toBeGreaterThanOrEqual(140)
  const muteScale = await streamCard.locator('.voice-person-state').evaluate(element => ({
    font: getComputedStyle(element).fontSize,
    icon: getComputedStyle(element.querySelector('.voice-person-state-icon')!).width,
  }))
  expect(muteScale.icon).toBe(muteScale.font)
  for (const card of [streamCard, voiceOnlyCard]) {
    const avatar = card.locator('.participant-card-info .avatar img')
    await expect(avatar).toHaveCount(1)
    await expect.poll(() => avatar.evaluate(image => (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0)
    await expect(avatar).toHaveCSS('width', '40px')
    await expect(avatar).toHaveCSS('height', '40px')
  }
  await page.screenshot({ path: info.outputPath('listener-participant-cards-876x656.png') })
  await preview.click()
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual([{ watchScreen: 'remote-screen' }])
  await clean(page)

  await open(page, 'participant-cards&no-profile', 876, 100, 656)
  const fallbackPreview = page.getByTestId('participant-screen-preview')
  await expect(fallbackPreview.locator('.participant-screen-preview__caption')).toHaveText('Демонстрация экрана')
  await expect(fallbackPreview.locator('.participant-screen-preview__play')).toHaveCSS('opacity', '1')

  await open(page, 'participant-cards&no-thumbnail', 876, 100, 656)
  const loadingPreview = page.getByTestId('participant-screen-preview')
  await expect(loadingPreview.locator('.screen-preview-placeholder__title')).toHaveText('Трансляция идёт')
  await expect(loadingPreview.locator('.screen-preview-placeholder__hint')).toHaveText('Предпросмотр скоро появится')
  await expect(loadingPreview.locator('.screen-preview-placeholder')).toBeVisible()
  await expect(loadingPreview.locator('.participant-screen-preview__image')).toHaveCount(0)
  await expect(loadingPreview.locator('.participant-screen-preview__play')).toHaveCount(0)
  await page.screenshot({ path: info.outputPath('listener-preview-loading-876x656.png') })

  await open(page, 'participant-cards', 390, 200, 740)
  const mobileCards = page.getByTestId('participant-card')
  const mobilePreview = page.getByTestId('participant-screen-preview')
  await expect(mobilePreview).toBeVisible()
  expect(await mobilePreview.evaluate(button => {
    const caption = button.querySelector('.participant-screen-preview__caption')!.getBoundingClientRect()
    const live = button.querySelector('.participant-screen-preview__live')!.getBoundingClientRect()
    return caption.right <= live.left
  })).toBe(true)
  const mobileGeometry = await mobileCards.evaluateAll(elements => elements.map(element => {
    const rect = element.getBoundingClientRect()
    return { width: rect.width, height: rect.height }
  }))
  expect(Math.abs(mobileGeometry[0].height - mobileGeometry[1].height)).toBeLessThanOrEqual(1)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await clean(page)
  await page.screenshot({ path: info.outputPath('listener-participant-cards-390x200.png') })
})

test('participant volume controls overlay compact mute state on hover, close outside and keep mute/deafen icons crisp', async ({ page }, info) => {
  await open(page, 'participant-cards', 876, 100, 656)
  const streamCard = page.locator('.participant--streaming')
  const details = streamCard.locator('.participant-volume')
  const trigger = details.locator('summary')
  const overlap = await trigger.evaluate(element => {
    const a = element.getBoundingClientRect()
    const b = element.closest('.participant')!.querySelector<HTMLElement>('.participant-screen-preview__live')!.getBoundingClientRect()
    return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top
  })
  expect(overlap).toBe(false)

  const status = streamCard.locator('.participant-card-status')
  await expect(status).toHaveAttribute('aria-label', 'Микрофон выключен')
  await expect(status).toHaveText('')

  const statusIcon = status.locator('.voice-person-state-icon')
  const controlAlignment = await trigger.evaluate(element => {
    const trigger = element.getBoundingClientRect()
    const icon = element.closest('.participant')!.querySelector<HTMLElement>('.participant-card-status .voice-person-state-icon')!.getBoundingClientRect()
    return {
      horizontal: Math.abs(trigger.left + trigger.width / 2 - (icon.left + icon.width / 2)),
      vertical: Math.abs(trigger.top + trigger.height / 2 - (icon.top + icon.height / 2)),
    }
  })
  expect(controlAlignment.horizontal).toBeLessThanOrEqual(1)
  expect(controlAlignment.vertical).toBeLessThanOrEqual(1)
  await expect(trigger).toHaveCSS('opacity', '0')
  await trigger.hover()
  await expect(trigger).toHaveCSS('opacity', '1')
  await page.screenshot({ path: info.outputPath('participant-volume-overlays-mute.png') })

  const sharpIcon = await statusIcon.evaluate(element => ({ width: getComputedStyle(element).width, height: getComputedStyle(element).height }))
  expect(sharpIcon).toEqual({ width: '16px', height: '16px' })

  await trigger.click()
  await expect(details).toHaveAttribute('open', '')
  const slider = details.getByRole('slider')
  await slider.click()
  await expect(details).toHaveAttribute('open', '')
  await page.locator('.voice-room header h1').click()
  await expect(details).not.toHaveAttribute('open', '')

  const mutedNameTop = await streamCard.locator('.participant-name').evaluate(element => element.getBoundingClientRect().top)
  await open(page, 'participant-cards&unmuted', 876, 100, 656)
  const unmutedCard = page.locator('.participant--streaming')
  const unmutedStatus = unmutedCard.locator('.participant-card-status')
  await expect(unmutedStatus).toHaveAttribute('aria-label', 'В голосовом канале')
  await expect(unmutedStatus).toHaveText('')
  const unmutedNameTop = await unmutedCard.locator('.participant-name').evaluate(element => element.getBoundingClientRect().top)
  expect(Math.abs(unmutedNameTop - mutedNameTop)).toBeLessThanOrEqual(1)

  await open(page, 'participant-cards&deafened', 876, 100, 656)
  const deafenedStatus = page.locator('.participant-self .participant-card-status')
  await expect(deafenedStatus).toHaveAttribute('aria-label', 'Звук и микрофон выключены')
  await expect(deafenedStatus.locator('.voice-person-state-icon')).toHaveCount(2)
  const deafenIconSizes = await deafenedStatus.locator('.voice-person-state-icon').evaluateAll(elements => elements.map(element => ({ width: getComputedStyle(element).width, height: getComputedStyle(element).height })))
  expect(deafenIconSizes).toEqual([{ width: '16px', height: '16px' }, { width: '16px', height: '16px' }])
})

test('participant overlay wraps a four-member roster into a compact grid', async ({ page }, info) => {
  await page.route(/\/api\/v1\/members\/[^/]+\/avatar(?:\?.*)?$/, route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>',
  }))
  for (const [width, scale, maxPanelWidth, expectedRows] of [[390, 200, 320, 4], [640, 100, 320, 2], [1440, 100, 400, 2]]) {
    await open(page, 'viewer-strip&four-participants', width, scale)
    await page.getByRole('button', { name: 'Участники · 4' }).click()
    const panel = page.locator('.screen-viewer-panel-content--participants')
    const strip = panel.getByTestId('viewer-participants')
    const cards = strip.locator('.voice-viewer-participant')
    const roster = strip.locator('ul')
    await expect(cards).toHaveCount(4)
    await expect.poll(() => panel.evaluate(element => element.getBoundingClientRect().width)).toBeLessThanOrEqual(maxPanelWidth)
    expect(await roster.evaluate(element => element.scrollWidth <= element.clientWidth + 1)).toBe(true)
    expect(await panel.evaluate(element => element.scrollHeight <= element.clientHeight + 1)).toBe(true)
    const rowPositions = await cards.evaluateAll(elements => [...new Set(elements.map(element => Math.round(element.getBoundingClientRect().top)))])
    expect(rowPositions).toHaveLength(expectedRows)
    await clean(page)
    await page.screenshot({ path: info.outputPath(`viewer-participants-four-${width}-${scale}.png`) })
  }
})

test('screen viewing controls enter and exit browser fullscreen without enabling app expansion, and stop watching', async ({ page }, info) => {
  await open(page, 'viewer-controls&watching-remote', 1280, 100, 800)
  const stage = page.locator('.screen-stage')
  const stageActions = page.getByRole('group', { name: 'Управление просмотром' })

  await expect(stageActions).toHaveCSS('opacity', '0')
  const idleTransform = await stageActions.evaluate(element => getComputedStyle(element).transform)
  expect(idleTransform).not.toBe('none')
  await page.screenshot({ path: info.outputPath('viewer-controls-idle-hidden.png') })
  const stageBounds = await stage.boundingBox()
  await page.mouse.move(stageBounds!.x + stageBounds!.width / 2, stageBounds!.y + stageBounds!.height / 2)
  await expect(stageActions).toHaveCSS('opacity', '1')
  const visibleTransform = await stageActions.evaluate(element => getComputedStyle(element).transform)
  expect(visibleTransform).not.toBe(idleTransform)
  await expect.poll(() => stageActions.evaluate(element => getComputedStyle(element).opacity), { timeout: 3000 }).toBe('0')
  expect(await stageActions.evaluate(element => getComputedStyle(element).transform)).toBe(idleTransform)
  await page.mouse.move(stageBounds!.x + stageBounds!.width / 2, stageBounds!.y + stageBounds!.height / 2)
  await expect(stageActions).toHaveCSS('opacity', '1')

  await page.getByRole('button', { name: 'Развернуть на весь экран', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(true)
  await expect(page.locator('.voice-room')).not.toHaveClass(/voice-room--screen-expanded/)
  await expect.poll(() => stageActions.evaluate(element => getComputedStyle(element).opacity), { timeout: 3000 }).toBe('0')
  await page.mouse.move(stageBounds!.x + stageBounds!.width / 2, stageBounds!.y + stageBounds!.height / 2)
  await expect(stageActions).toHaveCSS('opacity', '1')
  await page.screenshot({ path: info.outputPath('viewer-controls-expanded.png') })
  await stageActions.getByRole('button', { name: 'Свернуть просмотр', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(false)

  await page.getByRole('button', { name: 'Развернуть на весь экран', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(true)
  await page.screenshot({ path: info.outputPath('viewer-controls-browser-fullscreen.png') })
  await stageActions.getByRole('button', { name: 'Свернуть просмотр', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(false)

  await page.getByRole('button', { name: 'Развернуть на весь экран', exact: true }).click()
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(true)
  await stageActions.getByRole('button', { name: 'Прекратить просмотр', exact: true }).click()
  await expect(page.locator('.screen-stage-actions')).toHaveCount(0)
  await expect.poll(() => stage.evaluate(element => document.fullscreenElement === element)).toBe(false)
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual(['clear'])
})

test('keyboard focus keeps the viewer actions visible after the idle timer', async ({ page }) => {
  await open(page, 'viewer-controls&watching-remote', 1280, 100, 800)
  const actions = page.getByRole('group', { name: 'Управление просмотром' })
  const expand = page.getByRole('button', { name: 'Развернуть на весь экран', exact: true })

  for (let index = 0; index < 6; index++) {
    await page.keyboard.press('Tab')
    if (await expand.evaluate(element => element === document.activeElement)) break
  }
  await expect(expand).toBeFocused()
  await expect(actions).toHaveCSS('opacity', '1')
  await expect.poll(() => actions.evaluate(element => getComputedStyle(element).opacity), { timeout: 2500 }).toBe('1')
})

test('screen viewing overlay stays inside a narrow viewport at 200% text', async ({ page }, info) => {
  await open(page, 'viewer-controls&watching-remote', 390, 200, 844)
  const actions = page.getByRole('group', { name: 'Управление просмотром' })
  await expect(actions).toHaveCSS('opacity', '0')
  const stage = page.locator('.screen-stage')
  const stageBounds = await stage.boundingBox()
  await page.mouse.move(stageBounds!.x + stageBounds!.width / 2, stageBounds!.y + stageBounds!.height / 2)
  await expect(actions.getByRole('button', { name: 'Развернуть на весь экран', exact: true })).toBeVisible()
  await expect(actions.getByRole('button', { name: 'Прекратить просмотр', exact: true })).toBeVisible()
  await expect(actions).toHaveCSS('opacity', '1')
  await clean(page)

  const bounds = await actions.evaluate(element => {
    const rect = element.getBoundingClientRect()
    return { left: rect.left, right: rect.right, viewportWidth: document.documentElement.clientWidth, scrollWidth: document.documentElement.scrollWidth }
  })
  expect(bounds.left).toBeGreaterThanOrEqual(0)
  expect(bounds.right).toBeLessThanOrEqual(bounds.viewportWidth)
  expect(bounds.scrollWidth).toBeLessThanOrEqual(bounds.viewportWidth)
  await page.screenshot({ path: info.outputPath('viewer-controls-mobile-text-200.png') })
})

test('a viewer sees the selected stream audience, including another watcher', async ({ page }, info) => {
  await open(page, 'viewer-strip&watching-remote', 390)
  await page.getByRole('button', { name: /Участники · 3/ }).click()
  const strip = page.getByTestId('viewer-participants')
  const watcherCount = strip.getByRole('status', { name: 'Зрители трансляции: 2' })
  await expect(watcherCount).toBeVisible()
  await expect(watcherCount).toHaveText('Зрители · 2')
  await expect(strip.getByRole('img', { name: 'Смотрит эту трансляцию' })).toHaveCount(2)
  await expect(strip.getByText('Участник говорит', { exact: true }).locator('..').getByRole('img', { name: 'Смотрит эту трансляцию' })).toBeVisible()
  await expect(strip.locator('.voice-viewer-participant').first().getByRole('img', { name: 'Смотрит эту трансляцию' })).toBeVisible()
  await page.screenshot({ path: info.outputPath('viewer-sees-selected-stream-audience.png') })
})

test('muting a remote screen changes the speaker icon and restores it on unmute', async ({ page }, info) => {
  await page.route(/\/api\/v1\/members\/[^/]+\/avatar(?:\?.*)?$/, route => route.fulfill({
    status: 200,
    contentType: 'image/svg+xml',
    body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>',
  }))
  await open(page, 'viewer-strip&remote-audio')
  await page.locator('.screen-stage').hover()
  const mute = page.getByRole('button', { name: 'Выключить звук трансляции' })
  await expect(mute).toHaveAttribute('aria-pressed', 'true')
  const unmutedIcon = await mute.locator('svg').innerHTML()
  await page.screenshot({ path: info.outputPath('stream-audio-unmuted.png') })

  await mute.click()
  const unmute = page.getByRole('button', { name: 'Включить звук трансляции' })
  await expect(unmute).toHaveAttribute('aria-pressed', 'false')
  await expect(unmute.locator('svg')).not.toHaveJSProperty('innerHTML', unmutedIcon)
  const mutedIcon = await unmute.locator('svg').innerHTML()
  await page.screenshot({ path: info.outputPath('stream-audio-muted.png') })

  await unmute.click()
  await expect(page.getByRole('button', { name: 'Выключить звук трансляции' })).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('.screen-audio-toggle svg')).toHaveJSProperty('innerHTML', unmutedIcon)
  expect(mutedIcon).not.toBe(unmutedIcon)
})

test('unsupported prevents starting but leaves cancel and keyboard close available', async ({ page }) => {
  await open(page, 'unsupported')
  await expect(page.getByRole('alert')).toContainText('не поддерживает')
  await expect(page.getByRole('button', { name: 'Начать трансляцию' })).toBeDisabled()
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual(['cancel'])
})
test('cancel and reopen preserves the opener focus and has no publish side effect', async ({ page }) => {
  await open(page)
  await page.keyboard.press('Escape')
  await page.locator('#opener').click()
  await page.getByRole('button', { name: 'Отмена', exact: true }).click()
  await expect(page.locator('#opener')).toBeFocused()
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual(['cancel', 'cancel'])
})
test('sender never fabricates a target and distinguishes zero measured FPS from no data', async ({ page }) => {
  await open(page, 'sender&profile=null')
  await expect(page.getByText('Нет данных от источника', { exact: true })).toBeVisible()
  await expect(page.getByText(/1080p/)).toHaveCount(0)
  await page.evaluate(() => (window as any).__screenUI.patch({ profile: 'P1080_60', fps: 0 }))
  await expect(page.getByText(/1920 × 654 · 0 FPS/)).toBeVisible()
  await expect(page.getByText(/RTT:/)).not.toBeVisible()
  await page.getByText('Диагностика отправителя', { exact: true }).click()
  await expect(page.getByText(/RTT: 42 мс/)).toBeVisible()
  await page.getByRole('button', { name: 'Обновить измерения' }).click()
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual(['refresh'])
  await page.evaluate(() => (window as any).__screenUI.patch({ source: 'ENDED' }))
  await expect(page.getByRole('status')).toContainText('завершена')
})
const disclosureStates = ['', 'updating', 'unsupported', 'sender', 'receiver'] as const
const mainDisclosureViewport = ux2026FunctionalViewports[3]
test(`all screen-share disclosure states remain accessible at ${mainDisclosureViewport.width}x${mainDisclosureViewport.height}`, async ({ page }, info) => {
  for (const view of disclosureStates) {
    await open(page, view, mainDisclosureViewport.width, 100, mainDisclosureViewport.height)
    if (view === 'receiver') await page.locator('summary[aria-label="Статистика"]').click()
    await clean(page)
    await page.screenshot({ path: info.outputPath(`${view || 'launch'}-${mainDisclosureViewport.width}.png`) })
    if (view === 'sender' || view === 'receiver') {
      await page.locator(view === 'sender' ? '.screen-sender-details > summary' : '.stream-diagnostics-technical > summary').click()
      await clean(page)
      await page.screenshot({ path: info.outputPath(`technical-${view}-${mainDisclosureViewport.width}.png`) })
    }
    if (view === '' || view === 'updating') {
      const footer = page.locator('.screen-share-setup__footer')
      await expect(footer).toBeInViewport({ ratio: 0.99 })
      const details = page.locator('.screen-share-capabilities__details')
      await details.locator('summary').click()
      await clean(page)
      await page.screenshot({ path: info.outputPath(`details-${view || 'launch'}-${mainDisclosureViewport.width}.png`) })
    }
  }
})

const responsiveDisclosureCases = [
  { viewport: ux2026RequiredViewports[0], view: 'unsupported', scale: 100 },
  { viewport: ux2026RequiredViewports[1], view: 'receiver', scale: 200 },
  { viewport: ux2026RequiredViewports[2], view: 'sender', scale: 100 },
  { viewport: ux2026RequiredViewports[3], view: '', scale: 200 },
  { viewport: ux2026RequiredViewports[4], view: 'receiver', scale: 100 },
  { viewport: ux2026RequiredViewports[5], view: 'sender', scale: 100 },
  ...ux2026BreakpointViewports.map((viewport, index) => ({
    viewport,
    view: index === 2 ? 'receiver' : 'unsupported',
    scale: index === 2 ? 200 : 100,
  })),
] as const
test('targeted viewport and breakpoint disclosure states stay in bounds', async ({ page }, info) => {
  for (const { viewport, view, scale } of responsiveDisclosureCases) {
    await open(page, view, viewport.width, scale, viewport.height)
    if (view === 'receiver') await page.locator('summary[aria-label="Статистика"]').click()
    await clean(page)
    if (viewport.width === 320) await page.screenshot({ path: info.outputPath('unsupported-320x640.png') })
  }
})
test('missing source audio stays the diagnosis while video receiver samples fluctuate', async ({ page }, info) => {
  await open(page, 'diagnosis')
  const diagnosis = page.locator('.screen-diagnosis > [role="status"]')
  await expect(diagnosis).toHaveText('Источник не публикует аудиодорожку.')
  await page.evaluate(() => (window as any).__screenUI.patch({ sampledAt: Date.now() }))
  await expect(diagnosis).toHaveText('Источник не публикует аудиодорожку.')
  await page.screenshot({ path: info.outputPath('diagnosis-no-audio-desktop-fresh.png') })
  await page.evaluate(() => (window as any).__screenUI.patch({ sampledAt: Date.now() - 7000 }))
  await expect(diagnosis).toHaveText('Источник не публикует аудиодорожку.')
  await open(page, 'diagnosis', 390, 200)
  await expect(page.locator('.screen-diagnosis > [role="status"]')).toHaveText('Источник не публикует аудиодорожку.')
  await page.screenshot({ path: info.outputPath('diagnosis-no-audio-mobile-stale.png') })
})

test('a silent local preview is expected and does not offer an audio fix', async ({ page }, info) => {
  await open(page, 'diagnosis-local')
  const diagnosis = page.locator('.screen-diagnosis')
  await expect(diagnosis.getByRole('status')).toHaveText('Предпросмотр без звука.')
  await expect(diagnosis.getByRole('button', { name: 'Как добавить звук' })).toHaveCount(0)
  await page.screenshot({ path: info.outputPath('diagnosis-local-silent-preview.png') })
})

test('the add-audio guidance can be collapsed after opening', async ({ page }) => {
  await open(page, 'diagnosis')
  const diagnosis = page.locator('.screen-diagnosis')
  await diagnosis.getByRole('button', { name: 'Как добавить звук' }).click()
  const instruction = diagnosis.getByText('Попросите ведущего заново выбрать источник и включить передачу звука. Звук должен поддерживаться выбранным источником и браузером.')
  await expect(instruction).toBeVisible()
  const toggle = diagnosis.getByRole('button', { name: 'Скрыть инструкцию' })
  await expect(toggle).toHaveAttribute('aria-expanded', 'true')
  await toggle.click()
  await expect(instruction).toBeHidden()
  await expect(diagnosis.getByRole('button', { name: 'Как добавить звук' })).toHaveAttribute('aria-expanded', 'false')
})

test('playback diagnosis stays stable when receiver stats go stale but frames keep arriving', async ({ page }, info) => {
  await open(page, 'diagnosis-flapping')
  const diagnosis = page.locator('.screen-diagnosis > [role="status"]')
  const playing = 'Демонстрация воспроизводится.'
  await expect(diagnosis).toHaveText(playing)
  const messages = await diagnosis.evaluate(async element => {
    const observed = [element.textContent?.trim() ?? '']
    const observer = new MutationObserver(() => observed.push(element.textContent?.trim() ?? ''))
    observer.observe(element, { childList: true, characterData: true, subtree: true })
    await new Promise(resolve => window.setTimeout(resolve, 7500))
    observer.disconnect()
    return observed
  })
  expect(messages).toEqual([playing])
  await expect(page.locator('.screen-diagnosis > button')).toHaveCount(0)
  await page.screenshot({ path: info.outputPath('diagnosis-stable-through-stats-gaps.png') })
})

test('the owner can stop their own broadcast while the screen preview is open', async ({ page }) => {
  await open(page, 'viewer-strip', 1440)
  await page.locator('.screen-stage').hover()
  await expect(page.getByRole('group', { name: 'Управление просмотром' })).toHaveCSS('opacity', '1')
  await page.getByRole('button', { name: 'Остановить свою трансляцию' }).click()
  expect(await page.evaluate(() => (window as any).__screenUI.events)).toEqual(['stop-screen'])
})

test('short room height keeps the selected screen preview visible', async ({ page }) => {
  await open(page, 'viewer-strip&height=208', 417, 100, 208)
  const loadingState = page.locator('.screen-loading-state')
  const stageTop = page.locator('.screen-stage-top')
  const loadingBounds = await loadingState.evaluate(element => {
    const range = document.createRange()
    range.selectNodeContents(element)
    const rect = range.getBoundingClientRect()
    return { y: rect.y, bottom: rect.bottom }
  })
  const stageTopBounds = await stageTop.boundingBox()
  expect(stageTopBounds).not.toBeNull()
  expect(loadingBounds.y).toBeGreaterThanOrEqual(stageTopBounds!.y + stageTopBounds!.height)
  const geometry = await page.locator('.screen-stage').evaluate(stage => {
    const rect = stage.getBoundingClientRect()
    const viewer = stage.closest('.screen-viewer')!
    return { stageHeight: rect.height, stageTop: rect.top, stageBottom: rect.bottom, viewerHeight: viewer.clientHeight, viewerScrollHeight: viewer.scrollHeight }
  })
  expect(geometry.stageHeight).toBeGreaterThanOrEqual(120)
  expect(geometry.stageTop).toBeGreaterThanOrEqual(0)
  expect(geometry.stageBottom).toBeLessThanOrEqual(208)
  expect(geometry.viewerScrollHeight).toBeLessThanOrEqual(geometry.viewerHeight)
  await page.locator('.screen-stage').hover()
  const stopButton = page.getByRole('button', { name: 'Остановить свою трансляцию' })
  await stopButton.scrollIntoViewIfNeeded()
  await expect(stopButton).toBeInViewport()
  await page.screenshot({ path: test.info().outputPath('short-height-layout.png') })
})

test('brief screen audio publication changes do not flicker the diagnosis', async ({ page }) => {
  await open(page, 'diagnosis')
  const diagnosis = page.locator('.screen-diagnosis > [role="status"]')
  const noAudio = 'Источник не публикует аудиодорожку.'
  await expect(diagnosis).toHaveText(noAudio)
  await page.evaluate(() => (window as any).__screenUI.patch({ hasAudio: true }))
  await page.waitForTimeout(250)
  await expect(diagnosis).toHaveText(noAudio)
  await page.evaluate(() => (window as any).__screenUI.patch({ hasAudio: false }))
  await page.waitForTimeout(1250)
  await expect(diagnosis).toHaveText(noAudio)
  await page.evaluate(() => (window as any).__screenUI.patch({ hasAudio: true }))
  await expect(diagnosis).toHaveText('Демонстрация воспроизводится.', { timeout: 2000 })
})

test('receiver has selected/applied/measured levels and optional copyable technical data', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write'])
  await open(page, 'receiver')
  await page.locator('summary[aria-label="Статистика"]').click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await expect(panel.getByText('Выбрано отправителем', { exact: true })).toBeVisible()
  await expect(panel.getByText('Нет подтверждения от отправителя', { exact: true })).toBeVisible()
  await expect(panel.getByText('Сейчас у зрителя', { exact: true })).toBeVisible()
  await expect(panel.getByText('Декодирование', { exact: true })).not.toBeVisible()
  await panel.getByText('Технические данные', { exact: true }).click()
  await expect(panel.getByText('Декодирование', { exact: true })).toBeVisible()
  await panel.getByRole('button', { name: 'Копировать статистику' }).click()
  await expect(panel.getByRole('status')).toHaveText('Статистика скопирована')
  const copy = await page.evaluate(() => navigator.clipboard.readText())
  expect(copy).toContain('1920 × 654 · 1 FPS')
  expect(copy).not.toContain('Synthetic QA')
  await page.keyboard.press('Escape')
  await expect(panel).toHaveCount(0)
  await expect(page.locator('summary[aria-label="Статистика"]')).toBeFocused()
})

test('clipboard failure stays visible and mobile tab reaches disclosure and copy before returning to close', async ({ page }) => {
  await open(page, 'receiver', 390)
  await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', { value: { writeText: () => Promise.reject(new Error('denied')) }, configurable: true }))
  await page.locator('summary[aria-label="Статистика"]').click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await expect(panel.getByRole('button', { name: 'Закрыть статистику' })).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(panel.locator('.stream-diagnostics-technical > summary')).toBeFocused()
  await page.keyboard.press('Space')
  await page.keyboard.press('Tab')
  await expect(panel.getByRole('button', { name: 'Копировать статистику' })).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(panel.getByRole('status')).toContainText('Не удалось скопировать')
  await page.keyboard.press('Tab')
  await expect(panel.getByRole('button', { name: 'Закрыть статистику' })).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(panel.getByRole('button', { name: 'Копировать статистику' })).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(page.locator('summary[aria-label="Статистика"]')).toBeFocused()
})

test('desktop statistics remain inside the viewport after clipboard failure adds feedback', async ({ page }) => {
  await open(page, 'receiver')
  await page.evaluate(() => {
    const main = document.querySelector('main')!; main.style.position = 'absolute'; main.style.bottom = '16px'; main.style.width = '320px'
    Object.defineProperty(navigator, 'clipboard', { value: { writeText: () => Promise.reject(new Error('denied')) }, configurable: true })
  })
  await page.locator('summary[aria-label="Статистика"]').click()
  const panel = page.getByRole('dialog', { name: 'Статистика трансляции' })
  await panel.getByRole('button', { name: 'Копировать статистику' }).click()
  await expect(panel.getByRole('status')).toContainText('Не удалось скопировать')
  await expect.poll(() => panel.evaluate(e => e.getBoundingClientRect().bottom)).toBeLessThanOrEqual(884)
})
