import { expect, test, type Page } from '@playwright/test'
import axe from 'axe-core'
async function open(page: Page, query = '', width = 1440, scale = 100) {
  await page.setViewportSize({ width, height: 900 })
  await page.goto(`/tests/screen_share_ui/fixture.html?scale=${scale}&${query}`)
}
async function clean(page: Page) {
  await page.addScriptTag({ content: axe.source })
  expect(await page.evaluate(async () => (await (window as any).axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] } })).violations.map((v: any) => v.id))).toEqual([])
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

test('screen viewer shows the Flutter participant strip and scrolls names by width', async ({ page }, info) => {
  await open(page, 'viewer-strip', 320)
  const strip = page.getByTestId('viewer-participants')
  await expect(strip.getByText('Участники', { exact: true })).toBeVisible()
  await expect(strip.getByText('3 в комнате', { exact: true })).toBeVisible()
  await expect(strip.getByText('Участник говорит', { exact: true })).toBeVisible()
  await expect(strip.getByText('Участник показывает экран', { exact: true })).toBeVisible()
  await expect(page.locator('.screen-stage-label')).toContainText('Ваш экран')
  await expect(page.locator('.screen-stage-label')).toContainText('ЭФИР')
  await expect(page.getByTestId('stream-select')).toHaveCount(2)
  await expect(page.getByRole('heading', { name: 'Демонстрации в канале' })).toBeVisible()
  await expect(page.locator('.stream-option.selected .stream-option-copy > span')).toHaveCSS('white-space', 'nowrap')
  await expect(page.getByTestId('stream-rail')).not.toContainText('Участники ·')
  await expect(strip.getByRole('img', { name: 'Показывает экран' })).toHaveCount(2)
  await expect(strip.getByRole('img', { name: 'Микрофон выключен' })).toHaveCount(2)
  await expect(strip.getByRole('img', { name: 'Говорит' })).toHaveCount(1)
  await clean(page)
  const layout = await page.evaluate(() => {
    const list = document.querySelector<HTMLElement>('.voice-viewer-participant-strip ul')!
    const summary = document.querySelector<HTMLElement>('.voice-viewer-participant-summary')!
    const name = document.querySelector<HTMLElement>('.voice-viewer-participant-name')!
    const rail = document.querySelector<HTMLElement>('.screen-rail-section')!
    const participants = document.querySelector<HTMLElement>('.voice-viewer-participant-strip')!
    return { documentWidth: document.documentElement.scrollWidth, viewportWidth: innerWidth, listWidth: list.clientWidth, listContentWidth: list.scrollWidth, listLeft: list.getBoundingClientRect().left, summaryRight: summary.getBoundingClientRect().right, nameWidth: name.clientWidth, nameContentWidth: name.scrollWidth, railBottom: rail.getBoundingClientRect().bottom, participantsTop: participants.getBoundingClientRect().top }
  })
  expect(layout.documentWidth).toBeLessThanOrEqual(layout.viewportWidth)
  expect(layout.listContentWidth).toBeGreaterThan(layout.listWidth)
  expect(layout.listLeft).toBeGreaterThanOrEqual(layout.summaryRight)
  expect(layout.nameContentWidth).toBeGreaterThan(layout.nameWidth)
  expect(layout.railBottom).toBeLessThanOrEqual(layout.participantsTop)
  await page.screenshot({ path: info.outputPath('viewer-participants-320.png') })

  await open(page, 'viewer-strip', 390, 200)
  await clean(page)
  await expect(page.getByTestId('viewer-participants').getByText('3 в комнате', { exact: true })).toBeVisible()
  const zoomedRows = await page.evaluate(() => {
    const rail = document.querySelector<HTMLElement>('.screen-rail-section')!
    const participants = document.querySelector<HTMLElement>('.voice-viewer-participant-strip')!
    const card = document.querySelector<HTMLElement>('.stream-option.selected')!
    const footer = card.querySelector<HTMLElement>('.stream-option-copy')!
    const badge = footer.querySelector<HTMLElement>('b')!
    return { railBottom: rail.getBoundingClientRect().bottom, participantsTop: participants.getBoundingClientRect().top, footerTop: footer.getBoundingClientRect().top, footerBottom: footer.getBoundingClientRect().bottom, badgeTop: badge.getBoundingClientRect().top, badgeBottom: badge.getBoundingClientRect().bottom }
  })
  expect(zoomedRows.railBottom).toBeLessThanOrEqual(zoomedRows.participantsTop)
  expect(zoomedRows.badgeTop).toBeGreaterThanOrEqual(zoomedRows.footerTop)
  expect(zoomedRows.badgeBottom).toBeLessThanOrEqual(zoomedRows.footerBottom)
  await page.screenshot({ path: info.outputPath('viewer-participants-390-200.png') })

  await open(page, 'viewer-strip', 1440)
  await clean(page)
  await page.screenshot({ path: info.outputPath('viewer-participants-1440.png') })
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
for (const width of [320, 390, 1024, 1440]) for (const scale of [100, 200]) {
  test(`layout and disclosure ${width}px text ${scale}%`, async ({ page }, info) => {
    for (const view of ['', 'updating', 'unsupported', 'sender', 'receiver']) {
      await open(page, view, width, scale)
      if (view === 'receiver') await page.locator('summary[aria-label="Статистика"]').click()
      await clean(page)
      await page.screenshot({ path: info.outputPath(`${view || 'launch'}-${width}-${scale}.png`) })
      if (view === 'sender' || view === 'receiver') {
        await page.locator(view === 'sender' ? '.screen-sender-details > summary' : '.stream-diagnostics-technical > summary').click()
        await clean(page)
        await page.screenshot({ path: info.outputPath(`technical-${view}-${width}-${scale}.png`) })
      }
      if (view === '' || view === 'updating') {
        const footer = page.locator('.screen-share-setup__footer')
        await expect(footer).toBeInViewport({ ratio: 0.99 })
        const details = page.locator('.screen-share-capabilities__details')
        await details.locator('summary').click()
        await clean(page)
        await page.screenshot({ path: info.outputPath(`details-${view || 'launch'}-${width}-${scale}.png`) })
      }
    }
  })
}
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
  await expect(diagnosis).toHaveText('Данные о приёме отсутствуют или устарели. Причина качества не определена.', { timeout: 2000 })
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
