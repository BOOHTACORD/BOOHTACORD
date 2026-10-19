import { expect, test, type Page } from '@playwright/test'
import axe from 'axe-core'

const patch = (page: Page, value: Record<string, unknown>) => page.evaluate(value => (window as any).__voiceFixture.patch(value), value)
async function open(page: Page, width = 1440, scale = 100, scenario = '') {
  await page.setViewportSize({ width, height: 900 })
  await page.route('**/api/**', route => route.request().url().includes('/avatar')
    ? route.fulfill({ status: 200, contentType: 'image/svg+xml', body: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#278b82"/><circle cx="20" cy="14" r="7" fill="#f4f5fa"/><path d="M7 39c1-9 6-14 13-14s12 5 13 14" fill="#f4f5fa"/></svg>' })
    : route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
  await page.goto(`/tests/voice_interface/fixture.html?scale=${scale}${scenario ? `&${scenario}` : ''}`)
  await expect(page.locator('.voice-room-controls').first()).toBeVisible()
}

test('prejoin has two short explicit actions, retains listener mode and blocks double joins', async ({ page }) => {
  await open(page, 390)
  await patch(page, { active: false, state: 'IDLE' })
  const join = page.getByRole('button', { name: 'Войти', exact: true })
  await expect(join).toBeVisible()
  await expect(page.getByRole('button', { name: 'Без микрофона', exact: true })).toBeEnabled()
  await join.focus(); await page.keyboard.press('Enter')
  await expect(page.getByRole('button', { name: 'Подключаемся…' })).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Без микрофона', exact: true })).toBeDisabled()
  await patch(page, { state: 'IDLE' })
  await page.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['join', 'listener'])
})

test('empty voice roster centers its message and the dock hides voluntary-leave copy', async ({ page }, info) => {
  await open(page, 390)
  await patch(page, { active: false, state: 'IDLE' })
  const empty = page.locator('.voice-roster-empty')
  await expect(empty).toHaveText('Пока никого нет.')
  expect(await empty.evaluate(element => getComputedStyle(element).textAlign)).toBe('center')
  const centering = await page.evaluate(() => {
    const message = document.querySelector<HTMLElement>('.voice-roster-empty')!.getBoundingClientRect()
    const card = document.querySelector<HTMLElement>('.voice-prejoin-card')!.getBoundingClientRect()
    return { messageCenter: message.left + message.width / 2, cardCenter: card.left + card.width / 2 }
  })
  expect(Math.abs(centering.messageCenter - centering.cardCenter)).toBeLessThanOrEqual(1)
  await page.screenshot({ path: info.outputPath('empty-voice-roster.png') })

  await patch(page, { notice: { reason: 'VOLUNTARY_LEAVE', source: 'local', message: 'Голосовое подключение завершено.', explanation: '', reconnectAllowed: true } })
  await expect(page.getByTestId('voice-dock').getByText('Голосовое подключение завершено.', { exact: true })).toHaveCount(0)
  await patch(page, { notice: { reason: 'KICK', source: 'server', message: 'Администратор отключил вас от голосового канала.', explanation: '', reconnectAllowed: true } })
  await expect(page.getByTestId('voice-dock').getByText('Администратор отключил вас от голосового канала.', { exact: true })).toHaveCount(1)
})

test('connected voice room shows profile avatars on remote and self participant cards', async ({ page }, info) => {
  await open(page)
  const cards = page.getByTestId('voice-participants').getByTestId('participant-card')
  await expect(cards).toHaveCount(2)
  const avatars = cards.locator('.avatar img')
  await expect(avatars).toHaveCount(2)
  await expect(avatars.nth(0)).toHaveAttribute('src', '/api/v1/members/peer/avatar?revision=3')
  await expect(avatars.nth(1)).toHaveAttribute('src', '/api/v1/members/self/avatar?revision=2')
  await expect.poll(() => avatars.nth(0).evaluate(image => (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0)
  await expect.poll(() => avatars.nth(1).evaluate(image => (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0)
  await page.screenshot({ path: info.outputPath('connected-participant-avatars.png') })
})

test('connected room header uses the singular participant form when only the local user is present', async ({ page }, info) => {
  await open(page)
  const subtitle = page.locator('.voice-room .conversation-header .main-title small')
  await expect(subtitle).toHaveText('2 участника в голосовом канале')
  await patch(page, { voiceVolumeParticipants: [] })
  await expect(subtitle).toHaveText('1 участник в голосовом канале')
  await page.screenshot({ path: info.outputPath('solo-channel-header.png') })
})

test('room and dock share icons, named states and keyboard actions without opening details', async ({ page }) => {
  await open(page)
  for (const scope of [page.locator('.room-wrap'), page.getByTestId('voice-dock')]) {
    const mute = scope.getByRole('button', { name: 'Выключить микрофон', exact: true })
    await mute.focus(); await page.keyboard.press('Space')
    await expect(scope.getByRole('button', { name: 'Включить микрофон', exact: true })).toHaveAttribute('data-state', 'muted')
    await expect(scope.locator('[data-state=muted] svg .voice-control-slash')).toHaveCount(1)
    await scope.getByRole('button', { name: 'Включить микрофон', exact: true }).click()
    await scope.getByRole('button', { name: 'Выключить удалённый звук', exact: true }).focus(); await page.keyboard.press('Enter')
    await expect(scope.getByRole('button', { name: 'Включить удалённый звук', exact: true })).toHaveAttribute('aria-pressed', 'true')
    await expect(scope.getByRole('button', { name: 'Включить микрофон', exact: true })).toBeDisabled()
    await scope.getByRole('button', { name: 'Включить удалённый звук', exact: true }).click()
    await scope.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true }).click()
    await expect(scope.getByRole('button', { name: 'Запускаем демонстрацию экрана', exact: true })).toBeDisabled()
    await patch(page, { screen: 'SHARING' })
    await expect(scope.getByRole('button', { name: 'Остановить демонстрацию экрана', exact: true })).toHaveAttribute('aria-pressed', 'true')
    await scope.getByRole('button', { name: 'Остановить демонстрацию экрана', exact: true }).click()
    await expect(scope.locator('[data-state=stopping]')).toBeDisabled()
    await patch(page, { screen: 'IDLE' })
  }
  await expect(page.locator('.voice-advanced')).toHaveCount(0)
  await expect(page.getByText('Микрофон и звук трансляции управляются отдельно.', { exact: true })).not.toBeVisible()
})

test('permission denial and PTT keep the existing retry and activation contract in both places', async ({ page }) => {
  await open(page)
  await patch(page, { state: 'LISTENER', denied: true })
  await expect(page.getByTestId('voice-dock').getByRole('status').filter({ hasText: 'браузер запретил' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Повторить доступ к микрофону', exact: true })).toHaveCount(2)
  for (const retry of await page.getByRole('button', { name: 'Повторить доступ к микрофону', exact: true }).all()) await expect(retry).toBeEnabled()
  await patch(page, { mode: 'PTT' })
  await expect(page.getByRole('button', { name: 'Микрофон управляется push-to-talk', exact: true })).toHaveCount(2)
  for (const mic of await page.getByRole('button', { name: 'Микрофон управляется push-to-talk', exact: true }).all()) await expect(mic).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Повторить доступ к микрофону', exact: true })).toHaveCount(0)
})

test('reconnect remains actionable; leaving immediately removes stale streams and roster actions', async ({ page }) => {
  await open(page)
  await patch(page, { state: 'RECONNECTING' })
  await expect(page.locator('.room-wrap').getByRole('status')).toContainText('Восстанавливаем')
  await expect(page.getByTestId('voice-dock').getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeDisabled()
  await expect(page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала' })).toBeEnabled()
  await patch(page, { state: 'CONNECTED', screen: 'SHARING' })
  await expect(page.getByRole('button', { name: 'Смотреть экран', exact: true })).toBeVisible()
  await page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала' }).click()
  await expect(page.locator('.participant-watch, .participant-volume, .screen-viewer')).toHaveCount(0)
  await patch(page, { active: false, state: 'IDLE', selected: 'screen-peer' })
  await expect(page.getByRole('button', { name: 'Войти', exact: true })).toBeVisible()
  await expect(page.locator('.screen-viewer, .stream-rail, .participant-watch')).toHaveCount(0)
})

test('mobile reconnect status wraps into balanced lines at a narrow width', async ({ page }, info) => {
  await open(page, 320, 100)
  await patch(page, { state: 'RECONNECTING' })
  const status = page.getByTestId('voice-dock').getByRole('status')
  await expect(status).toHaveText('Восстанавливаем голосовое соединение')
  const lineWidths = await status.evaluate(element => {
    const textNode = element.firstChild!
    const text = textNode.textContent ?? ''
    const lines = new Map<number, { left: number; right: number }>()
    for (const match of text.matchAll(/\S+/g)) {
      const range = document.createRange()
      range.setStart(textNode, match.index!)
      range.setEnd(textNode, match.index! + match[0].length)
      const rect = range.getBoundingClientRect()
      const top = Math.round(rect.top)
      const line = lines.get(top) ?? { left: rect.left, right: rect.right }
      line.left = Math.min(line.left, rect.left)
      line.right = Math.max(line.right, rect.right)
      lines.set(top, line)
    }
    return [...lines.values()].map(line => line.right - line.left)
  })
  expect(lineWidths).toHaveLength(2)
  expect(Math.min(...lineWidths) / Math.max(...lineWidths)).toBeGreaterThan(0.7)
  await page.screenshot({ path: info.outputPath('mobile-reconnecting-status-balanced.png'), fullPage: true })
})

test('leaving removes the members rail and an already open voice participant popover', async ({ page }) => {
  await open(page)
  await page.goto('/tests/voice_interface/fixture.html?members')
  await page.locator('.members-voice-roster').getByRole('button', { name: /Профиль: Тестовый участник/ }).click()
  await expect(page.getByTestId('member-popover')).toBeVisible()
  await patch(page, { state: 'LEAVING' })
  await expect(page.locator('.members-voice-roster')).toHaveCount(0)
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
})

for (const width of [320, 390, 768, 1024, 1440]) for (const scale of [100, 200]) test(`compact voice states fit at ${width}px / text ${scale}%`, async ({ page }, info) => {
  await open(page, width, scale)
  if (width >= 721 && scale === 200) {
    const header = await page.locator('.voice-room .conversation-header').boundingBox()
    const title = await page.locator('.voice-room .conversation-header .main-title').boundingBox()
    expect(title!.y, 'the enlarged title must remain inside the voice header').toBeGreaterThanOrEqual(header!.y)
    expect(title!.y + title!.height, 'the enlarged subtitle must remain inside the voice header').toBeLessThanOrEqual(header!.y + header!.height)
  }
  for (const [name, value] of Object.entries({ connected: {}, muted: { muted: true }, deafened: { deafened: true }, denied: { deafened: false, denied: true, state: 'LISTENER' }, reconnecting: { state: 'RECONNECTING' }, starting: { screen: 'STARTING' }, sharing: { screen: 'SHARING' }, stopping: { screen: 'STOPPING' }, leaving: { state: 'LEAVING', screen: 'SHARING' }, prejoin: { active: false, state: 'IDLE' }, joining: { active: false, state: 'JOINING' } })) {
    await patch(page, { state: 'CONNECTED', active: true, muted: false, deafened: false, denied: false, screen: 'IDLE', ...value })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    const target = page.locator('.room-wrap')
    for (const button of await target.getByRole('button').all()) if (await button.isVisible()) {
      const rect = await button.boundingBox()
      expect(rect!.x).toBeGreaterThanOrEqual(0); expect(rect!.x + rect!.width).toBeLessThanOrEqual(width + 1)
      expect(rect!.height).toBeGreaterThanOrEqual(40)
    }
    await page.addScriptTag({ content: axe.source })
    const violations = await page.evaluate(async () => (await (window as any).axe.run('#app', { runOnly: { type: 'tag', values: ['wcag2a','wcag2aa','wcag21aa'] } })).violations)
    expect(violations, name).toEqual([])
    await page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true })
  }
})

for (const scale of [100, 200]) test(`mobile dock exposes all four actions with drawer closed, text ${scale}%`, async ({ page }, info) => {
  await open(page, 320, scale)
  await page.goto(`/tests/voice_interface/fixture.html?closed&scale=${scale}`)
  const dock = page.getByTestId('voice-dock')
  const buttons = dock.locator('.voice-actions button')
  await expect(buttons).toHaveCount(4)
  for (const button of await buttons.all()) {
    await expect(button).toBeVisible()
    const rect = await button.boundingBox()
    expect(rect!.width).toBeGreaterThanOrEqual(44); expect(rect!.height).toBeGreaterThanOrEqual(44)
  }
  await dock.getByRole('button', { name: 'Выключить удалённый звук', exact: true }).focus()
  await page.keyboard.press('Space')
  await expect(dock.getByRole('button', { name: 'Включить удалённый звук', exact: true })).toHaveAttribute('aria-pressed', 'true')
  await page.screenshot({ path: info.outputPath('closed-deafened.png'), fullPage: true })
})

test('mobile mute stays visibly filled without a red border and enlarged denied notice remains visible', async ({ page }, info) => {
  await open(page, 320, 200)
  await patch(page, { muted: true })
  const mic = page.getByTestId('voice-dock').locator('[data-state=muted]')
  expect(await mic.evaluate(button => getComputedStyle(button, '::before').backgroundColor)).toBe('rgb(185, 28, 28)')
  expect(await mic.evaluate(button => getComputedStyle(button).borderWidth)).toBe('0px')
  await page.screenshot({ path: info.outputPath('mobile-muted-dock-no-red-border.png'), fullPage: true })
  await patch(page, { denied: true, state: 'LISTENER' })
  const subtitle = await page.locator('.voice-dock-subtitle').boundingBox()
  const notice = await page.locator('.voice-dock-mic-notice').boundingBox()
  expect(notice!.y).toBeGreaterThanOrEqual(subtitle!.y + subtitle!.height)
})


test('a pending active join never claims to be connected and blocks microphone actions', async ({ page }, info) => {
  await open(page, 390)
  await patch(page, { state: 'JOINING', active: true })
  await expect(page.locator('.room-wrap').getByRole('status')).toHaveText('Подключаемся…')
  await expect(page.locator('.room-wrap').getByRole('button', { name: 'Выключить микрофон', exact: true })).toBeDisabled()
  await page.screenshot({ path: info.outputPath('pending-active-join.png') })
  await patch(page, { state: 'CONNECTED', deafenChanging: true })
  await expect(page.locator('.room-wrap').getByRole('button', { name: 'Выключить микрофон', exact: true })).toBeDisabled()
  await expect(page.getByTestId('voice-dock').getByRole('button', { name: 'Выключить удалённый звук', exact: true })).toBeDisabled()
})

test('unsupported capture keeps a visible explanation while voice and leave stay usable', async ({ page }, info) => {
  await page.addInitScript(() => { Object.defineProperty(navigator.mediaDevices, 'getDisplayMedia', { value: undefined }) })
  await open(page, 390)
  await expect(page.locator('.room-wrap').getByRole('status').filter({ hasText: 'Этот браузер не поддерживает показ экрана' })).toBeVisible()
  const share = page.locator('.voice-room-controls button').nth(2)
  await expect(share).toBeDisabled()
  await expect(share).toHaveAccessibleName(/Используйте браузер на ПК/)
  await expect(page.locator('.room-wrap').getByRole('button', { name: 'Выключить микрофон', exact: true })).toBeEnabled()
  await expect(page.locator('.room-wrap').getByRole('button', { name: 'Выйти из голосового канала' })).toBeEnabled()
  await page.screenshot({ path: info.outputPath('capture-unavailable.png') })
})

test('Android browser explains unavailable screen capture while voice remains usable', async ({ page }, info) => {
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      value: 'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/152.0 Mobile Safari/537.36',
    })
  })
  await open(page, 393)
  const notice = page.locator('.room-wrap').getByRole('status').filter({ hasText: 'нельзя начать трансляцию' })
  await expect(notice).toHaveClass(/voice-capture-unavailable/)
  await expect(notice).toHaveText('В браузере Android нельзя начать трансляцию экрана. Откройте приложение BOOHTACORD.')
  expect(await notice.evaluate(element => getComputedStyle(element).display)).toBe('flex')
  expect((await notice.boundingBox())!.height).toBeLessThanOrEqual(60)
  const controls = page.locator('.voice-room-controls')
  const share = controls.getByRole('button', { name: /Откройте приложение BOOHTACORD/ })
  await expect(share).toBeDisabled()
  await expect(controls.getByRole('button', { name: 'Выключить микрофон' })).toBeEnabled()
  await expect(controls.getByRole('button', { name: 'Выйти из голосового канала' })).toBeEnabled()
  await page.screenshot({ path: info.outputPath('android-capture-unavailable.png') })
})

for (const width of [320, 390]) test(`screen-sharing participant cards can scroll above the fixed voice dock at ${width}px / 200% text`, async ({ page }) => {
  await open(page, width, 200)
  await patch(page, { state: 'CONNECTED', active: true, screen: 'SHARING' })
  const room = page.locator('.voice-room .room-wrap')
  const lastParticipant = room.locator('.voice-participant-volumes .participant').last()
  const dock = page.locator('.mobile-voice-dock.mobile-visible')
  await expect(lastParticipant).toBeVisible()
  await room.evaluate(element => { element.scrollTop = element.scrollHeight })
  const [participantBox, dockBox, roomBox] = await Promise.all([lastParticipant.boundingBox(), dock.boundingBox(), room.boundingBox()])
  expect(participantBox).not.toBeNull()
  expect(dockBox).not.toBeNull()
  expect(roomBox).not.toBeNull()
  expect(participantBox!.y + participantBox!.height).toBeLessThanOrEqual(Math.min(dockBox!.y, roomBox!.y + roomBox!.height) + 1)
})

test('failed connection keeps the failure and explicit retry actions visible', async ({ page }, info) => {
  await open(page, 390)
  await patch(page, { state: 'ERROR', active: false, error: 'Не удалось подключиться. Проверьте связь и повторите вход.' })
  await expect(page.locator('.voice-prejoin').getByRole('alert')).toContainText('Проверьте связь')
  const retry = page.getByRole('button', { name: 'Войти', exact: true })
  await expect(retry).toBeEnabled()
  await expect(page.getByRole('button', { name: 'Без микрофона', exact: true })).toBeEnabled()
  await page.screenshot({ path: info.outputPath('join-failed.png') })
  await retry.focus(); await page.keyboard.press('Enter')
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['join'])
})

test('touch PTT dock transmits only while pressed and releases on cancellation or unmount', async ({ page }) => {
  await open(page, 390, 100, 'touchPtt=1&mode=PTT')
  const ptt = page.getByTestId('voice-dock').locator('.voice-ptt-button')
  await expect(ptt).toBeVisible()
  await expect(ptt).toBeEnabled()
  await expect(ptt).toHaveAttribute('aria-label', 'Удерживайте, чтобы говорить')
  await ptt.dispatchEvent('pointerdown', { pointerId: 9, pointerType: 'touch', isPrimary: true, button: 0, buttons: 1 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'true')
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['ptt:press'])
  await ptt.dispatchEvent('pointerup', { pointerId: 9, pointerType: 'touch', isPrimary: true, button: 0, buttons: 0 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'false')
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['ptt:press', 'ptt:release'])

  await ptt.dispatchEvent('pointerdown', { pointerId: 10, pointerType: 'touch', isPrimary: true, button: 0, buttons: 1 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'true')
  await ptt.dispatchEvent('pointercancel', { pointerId: 10, pointerType: 'touch', isPrimary: true, button: 0, buttons: 0 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'false')
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['ptt:press', 'ptt:release', 'ptt:press', 'ptt:release'])

  await ptt.dispatchEvent('pointerdown', { pointerId: 11, pointerType: 'touch', isPrimary: true, button: 0, buttons: 1 })
  await patch(page, { mode: 'VAD' })
  await expect(page.getByTestId('voice-dock').locator('.voice-ptt-button')).toHaveCount(0)
  expect(await page.evaluate(() => (window as any).__voiceFixture.events)).toEqual(['ptt:press', 'ptt:release', 'ptt:press', 'ptt:release', 'ptt:press', 'ptt:release'])
})

test('Android touch browsers show on-screen PTT without a keyboard binding', async ({ browser }, info) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    userAgent: 'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36',
  })
  const page = await context.newPage()
  await open(page, 390, 100, 'mode=PTT')
  await expect(page.getByTestId('voice-dock').getByTestId('touch-ptt-button')).toBeVisible()
  const ptt = page.getByTestId('voice-dock').getByTestId('touch-ptt-button')
  await expect(ptt).toBeEnabled()
  await expect(ptt).toHaveAttribute('aria-pressed', 'false')
  await page.screenshot({ path: info.outputPath('android-touch-ptt-ready-390x900.png') })
  await ptt.dispatchEvent('pointerdown', { pointerId: 19, pointerType: 'touch', isPrimary: true, button: 0, buttons: 1 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'true')
  const colors = await ptt.evaluate(element => {
    const expected = document.createElement('span')
    expected.style.color = 'var(--gc-danger-solid)'
    document.body.append(expected)
    const danger = getComputedStyle(expected).color
    expected.remove()
    return { actual: getComputedStyle(element).backgroundColor, danger }
  })
  const buttonStyle = await ptt.evaluate(element => ({ className: element.className, parentClass: element.parentElement?.className, color: getComputedStyle(element).color, background: getComputedStyle(element).backgroundColor }))
  expect(colors.actual, JSON.stringify(buttonStyle)).toBe(colors.danger)
  await page.screenshot({ path: info.outputPath('android-touch-ptt-held-390x900.png') })
  await ptt.dispatchEvent('pointercancel', { pointerId: 19, pointerType: 'touch', isPrimary: true, button: 0, buttons: 0 })
  await expect(ptt).toHaveAttribute('aria-pressed', 'false')
  await context.close()
})
