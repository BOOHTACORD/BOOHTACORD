import { expect, test, type Page } from '@playwright/test'
import {
  ux2026BreakpointViewports,
  ux2026FunctionalViewports,
  ux2026RequiredViewports,
  ux2026ShortViewports,
  ux2026ShellViewports,
} from '../uiux_2026/viewport_matrix'

const viewports = ux2026ShellViewports
const screenshotViewports = new Set(viewports.map(({ width, height }) => `${width}x${height}`))
const shellSweepViewports = [
  ...viewports,
  ...ux2026BreakpointViewports.filter(({ width, height }) =>
    !viewports.some(viewport => viewport.width === width && viewport.height === height)),
]

async function dismissDrawerOutsideNavigation(page: Page) {
  const scrim = page.locator('.drawer-scrim')
  const scrimBox = await scrim.boundingBox()
  const drawerBox = await page.getByTestId('workspace-drawer').boundingBox()

  expect(scrimBox).not.toBeNull()
  expect(drawerBox).not.toBeNull()
  await scrim.click({
    position: {
      x: drawerBox!.x + drawerBox!.width + 8 - scrimBox!.x,
      y: Math.min(16, scrimBox!.height - 1),
    },
  })
}

test('production shell CSS stays within the viewport and preserves its workspace while resizing', async ({ page }, testInfo) => {
  await page.setViewportSize(viewports[2])
  await page.goto('/tests/responsive_shell/fixture.html')

  for (const viewport of shellSweepViewports) {
    await page.setViewportSize(viewport)
    const main = await page.getByTestId('workspace-main').boundingBox()
    const shell = await page.getByTestId('workspace-shell').boundingBox()
    const composer = await page.getByTestId('composer-wrap').boundingBox()

    expect(shell?.width).toBe(viewport.width)
    expect(main?.x).toBe(viewport.width < 1024 ? 0 : 280)
    expect(main?.width).toBe(viewport.width < 1024 ? viewport.width : viewport.width < 1280 ? viewport.width - 280 : viewport.width - 528)
    expect(composer?.x).toBeGreaterThanOrEqual(0)
    expect((composer?.x ?? 0) + (composer?.width ?? 0)).toBeLessThanOrEqual(viewport.width)
    expect((composer?.y ?? 0) + (composer?.height ?? 0)).toBeLessThanOrEqual(viewport.height)
    expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('general')
    await expect(page.getByTestId('message-list').getByText(/Состояние беседы сохраняется/)).toBeVisible()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)

    const dock = page.getByTestId('mobile-voice-dock')
    await expect(dock).toBeVisible()
    const dockBox = await dock.boundingBox()
    if (viewport.width < 1024) {
      expect(dockBox!.height).toBeGreaterThanOrEqual(53)
      expect(dockBox!.y).toBeGreaterThanOrEqual(main!.y + main!.height - 1)
      expect(composer!.y + composer!.height).toBeLessThanOrEqual(dockBox!.y)
      expect(Math.abs(dockBox!.y + dockBox!.height - viewport.height)).toBeLessThanOrEqual(1)
      expect((dockBox?.y ?? 0) + (dockBox?.height ?? 0)).toBeLessThanOrEqual(viewport.height)
    } else {
      const sidebar = await page.getByTestId('workspace-sidebar').boundingBox()
      expect(dockBox?.x).toBeGreaterThanOrEqual(sidebar?.x ?? 0)
      expect((dockBox?.x ?? 0) + (dockBox?.width ?? 0)).toBeLessThanOrEqual((sidebar?.x ?? 0) + (sidebar?.width ?? 0))
    }
    if (screenshotViewports.has(`${viewport.width}x${viewport.height}`)) {
      await page.screenshot({ path: testInfo.outputPath(`shell-${viewport.width}x${viewport.height}.png`), fullPage: true })
    }
  }
})

test('navigation and message history scroll independently', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 })
  await page.goto('/tests/responsive_shell/fixture.html')
  await page.evaluate(() => {
    const drawer = document.querySelector<HTMLElement>('.nav-drawer')!
    const navContent = drawer.querySelector<HTMLElement>('.nav-content')!
    const navFill = document.createElement('div')
    navFill.style.height = '1200px'
    navFill.setAttribute('aria-hidden', 'true')
    navContent.append(navFill)

    const history = document.querySelector<HTMLOListElement>('.message-list')!
    history.replaceChildren(...Array.from({ length: 80 }, (_, index) => {
      const item = document.createElement('li')
      item.className = 'message-item'
      item.textContent = `Сообщение ${index + 1}: история сохраняет собственную область прокрутки.`
      return item
    }))
  })

  const navigation = page.locator('.nav-content')
  const history = page.getByTestId('message-list')
  const navigationSize = await navigation.evaluate(element => ({
    client: element.clientHeight,
    scroll: element.scrollHeight,
  }))
  const historySize = await history.evaluate(element => ({
    client: element.clientHeight,
    scroll: element.scrollHeight,
  }))
  expect(navigationSize.scroll).toBeGreaterThan(navigationSize.client)
  expect(historySize.scroll).toBeGreaterThan(historySize.client)

  const initialHistoryPosition = await history.evaluate(element => element.scrollTop)
  await navigation.evaluate(element => { element.scrollTop = 240 })
  expect(await navigation.evaluate(element => element.scrollTop)).toBeGreaterThan(0)
  expect(await history.evaluate(element => element.scrollTop)).toBe(initialHistoryPosition)

  const navigationPosition = await navigation.evaluate(element => element.scrollTop)
  await history.evaluate(element => { element.scrollTop = 320 })
  expect(await history.evaluate(element => element.scrollTop)).toBeGreaterThan(0)
  expect(await navigation.evaluate(element => element.scrollTop)).toBe(navigationPosition)
})

test('the mobile navigation drawer opens inside its available width', async ({ page }) => {
  for (const width of [320, 390, 600, 840]) {
    await page.setViewportSize({ width, height: 844 })
    await page.goto('/tests/responsive_shell/fixture.html')
    await page.getByRole('button', { name: 'Открыть навигацию' }).click()
    const sidebar = await page.getByTestId('workspace-sidebar').boundingBox()
    const drawer = await page.getByTestId('workspace-drawer').boundingBox()
    expect(drawer?.x).toBe(0)
    if (width < 1024) {
      expect(sidebar?.width).toBe(Math.min(320, width - 40))
      expect(sidebar?.x).toBe(0)
      expect(drawer!.width).toBeGreaterThan(0)
      expect(drawer!.x + drawer!.width).toBeLessThanOrEqual(sidebar!.x + sidebar!.width)
    } else {
      expect(drawer?.width).toBe(Math.min(320, width - 40))
    }
    if (width < 1024) {
      await page.getByTestId('workspace-sidebar').getByRole('button', { name: 'Закрыть навигацию' }).click()
    } else {
      await dismissDrawerOutsideNavigation(page)
    }
    await expect(page.getByTestId('workspace-drawer')).toBeHidden()
  }
})

test('the mobile account profile stays above the voice dock with an update banner', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/tests/responsive_shell/fixture.html')
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()

  const footer = page.locator('.user-footer')
  const dock = page.getByTestId('mobile-voice-dock')
  await page.evaluate(() => {
    const root = document.querySelector('#app')!
    const banner = document.createElement('section')
    banner.className = 'update-banner'
    banner.setAttribute('aria-live', 'polite')
    banner.textContent = 'Доступна новая версия BOOHTACORD'
    root.prepend(banner)

    const navContent = document.querySelector('.nav-content')!
    const status = document.createElement('section')
    status.className = 'connection-status'
    status.textContent = 'Чат обновляется · Голос подключён · Состав устарел'
    const warning = document.createElement('p')
    warning.className = 'state state-error'
    warning.textContent = 'Нет соединения с сервером. Проверьте подключение.'
    navContent.prepend(warning)
    navContent.prepend(status)
  })

  const after = await footer.boundingBox()
  const dockBox = await dock.boundingBox()
  expect(after).not.toBeNull()
  expect(dockBox).not.toBeNull()
  expect(after!.y + after!.height).toBeLessThanOrEqual(dockBox!.y + 1)
  expect(after!.y + after!.height).toBeLessThanOrEqual(640)
  expect(dockBox!.y + dockBox!.height).toBeLessThanOrEqual(640)
  await expect(footer).toBeVisible()
  await page.screenshot({ path: testInfo.outputPath('account-footer-with-update-banner-320x640.png') })
})

test('the channel favorite toggle stays inside its row at representative layout sizes', async ({ page }) => {
  for (const viewport of ux2026FunctionalViewports) {
    const { width, height } = viewport
    await page.setViewportSize(viewport)
    await page.goto('/tests/responsive_shell/fixture.html')
    if (width < 1024) await page.getByRole('button', { name: 'Открыть навигацию' }).click()

    const row = page.getByTestId('channel-favorite-row')
    const channel = row.locator('.channel-button')
    const favorite = row.locator('.channel-favorite-toggle')
    const actions = row.locator('.channel-actions-button')
    const rowBox = await row.boundingBox()
    const channelBox = await channel.boundingBox()
    const favoriteBox = await favorite.boundingBox()
    const actionsBox = await actions.boundingBox()

    expect(rowBox).not.toBeNull()
    expect(channelBox).not.toBeNull()
    expect(favoriteBox).not.toBeNull()
    expect(actionsBox).not.toBeNull()
    expect(channelBox!.x).toBeGreaterThanOrEqual(rowBox!.x)
    expect(channelBox!.x + channelBox!.width).toBeLessThanOrEqual(favoriteBox!.x + 1)
    expect(favoriteBox!.x + favoriteBox!.width).toBeLessThanOrEqual(actionsBox!.x + 1)
    expect(actionsBox!.x + actionsBox!.width).toBeLessThanOrEqual(rowBox!.x + rowBox!.width + 1)
    expect(await row.evaluate(element => element.scrollWidth <= element.clientWidth)).toBe(true)
    await expect(favorite).toBeVisible()
    await expect(actions).toBeVisible()
    if (width < 1024) {
      expect(favoriteBox!.width).toBeGreaterThanOrEqual(44)
      expect(actionsBox!.width).toBeGreaterThanOrEqual(44)
      if (width < 1024) {
        await page.getByTestId('workspace-sidebar').getByRole('button', { name: 'Закрыть навигацию' }).click()
      } else {
        await dismissDrawerOutsideNavigation(page)
      }
    }
  }
})

const representativeFavoriteViewports = [
  ux2026RequiredViewports[0],
  ux2026FunctionalViewports[0],
  ux2026RequiredViewports[3],
  { width: 1280, height: 800 },
  ux2026FunctionalViewports[3],
]
// Each viewport gets the unchanged per-test timeout and a fresh browser context.
for (const viewport of [...representativeFavoriteViewports, ...ux2026ShortViewports]) {
  test(`production channel favorites remain reachable when adding a lower channel on narrow drawers (${viewport.width}x${viewport.height})`, async ({ page, browserName }) => {
    const { width } = viewport
    await page.setViewportSize(viewport)
    await page.goto('/')
    await page.evaluate(async () => {
      const load = (path: string) => import(path)
      const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
      const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
      const { default: ChannelNavigation } = await load('/src/channel/ChannelNavigation.vue')
      localStorage.clear()
      if (window.innerWidth === 320 && window.innerHeight === 568) {
        document.documentElement.style.fontSize = '32px'
      }
      document.body.innerHTML = '<div class="app-frame"><div class="gc-shell no-aside"><aside class="sidebar is-open"><div class="nav-drawer"><div class="nav-content" id="mount"></div></div></aside><main class="main"></main></div></div>'
      const channels = Array.from({ length: 18 }, (_, position) => ({
        id: `channel-${position + 1}`,
        name: `Канал ${position + 1}`,
        kind: 'TEXT',
        position,
        admissionClosed: false,
      }))
      const app = createApp({ render: () => h(ChannelNavigation, {
        accountId: 'favorite-regression-account',
        selectedChannelId: 'channel-18',
        topology: { revision: 1, categories: [{ id: 'category-1', name: 'Общение', position: 0, channels }] },
        voicePresence: null,
      }) })
      app.use(createPinia())
      app.mount('#mount')
    })

    const navContent = page.locator('.nav-content')
    const targetRow = page.locator('.channel-row').filter({ hasText: 'Канал 18' })
    await targetRow.scrollIntoViewIfNeeded()
    const favorite = targetRow.locator('.channel-favorite-toggle')
    await expect(favorite).toBeVisible()
    await expect(favorite).toHaveRole('button')
    await expect(favorite).toHaveAccessibleName('Добавить в избранное: Канал 18')
    await expect(favorite).toHaveAttribute('aria-pressed', 'false')
    await favorite.click()
    await expect(favorite).toHaveAttribute('aria-pressed', 'true')
    await expect(favorite).toHaveAccessibleName('Убрать из избранного: Канал 18')
    await expect(favorite).toBeInViewport({ ratio: 0.99 })
    await expect(page.locator('.channel-favorite-link')).toBeVisible()
    await expect(favorite).toBeVisible()
    expect(await navContent.evaluate(element => element.scrollWidth <= element.clientWidth)).toBe(true)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    const navBox = await navContent.boundingBox()
    const favoriteBox = await favorite.boundingBox()
    expect(navBox).not.toBeNull()
    expect(favoriteBox).not.toBeNull()
    expect(favoriteBox!.x).toBeGreaterThanOrEqual(navBox!.x)
    expect(favoriteBox!.x + favoriteBox!.width).toBeLessThanOrEqual(navBox!.x + navBox!.width + 1)
    expect(favoriteBox!.y).toBeGreaterThanOrEqual(navBox!.y)
    expect(favoriteBox!.y + favoriteBox!.height).toBeLessThanOrEqual(navBox!.y + navBox!.height + 1)

    if (browserName === 'webkit') {
      await favorite.focus()
    } else {
      await targetRow.locator('.channel-button').focus()
      await page.keyboard.press('Tab')
    }
    await expect(favorite).toBeFocused()
    await page.keyboard.press('Space')
    await expect(favorite).toHaveCSS('outline-style', 'solid')
    await expect(favorite).toHaveCSS('outline-width', '2px')
    await expect(favorite).toHaveAttribute('aria-pressed', 'false')
    await expect(favorite).toHaveAccessibleName('Добавить в избранное: Канал 18')
    await expect(favorite).toBeInViewport({ ratio: 0.99 })

    await page.keyboard.press('Space')
    await expect(favorite).toHaveAttribute('aria-pressed', 'true')
    await expect(favorite).toHaveAccessibleName('Убрать из избранного: Канал 18')
    await expect(favorite).toBeInViewport({ ratio: 0.99 })
  })
}

test('browser Back and Forward close and restore overlays without losing workspace or voice state', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/fixture.html')
  const initialUrl = page.url()
  const drawer = page.getByTestId('workspace-drawer')
  const search = page.getByTestId('search-drawer')

  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await expect(drawer).toBeVisible()
  await page.reload()
  await expect(drawer).toBeVisible()
  await page.goBack()
  await expect(drawer).toBeHidden()
  await expect(page.getByText('Голос подключён')).toBeVisible()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('general')
  expect(page.url()).toBe(initialUrl)

  await page.goForward()
  await expect(drawer).toBeVisible()
  await page.getByTestId('workspace-sidebar').getByRole('button', { name: 'Закрыть навигацию' }).click()
  await expect(drawer).toBeHidden()
  await page.getByRole('button', { name: 'Открыть поиск' }).click()
  await expect(page.locator('#app')).toHaveAttribute('data-drawer-state', 'search')
  await expect(search).toBeVisible()
  await page.goBack()
  await expect(search).toBeHidden()
  await page.goForward()
  await expect(search).toBeVisible()

  await page.getByRole('button', { name: 'Закрыть поиск' }).click()
  await expect(search).toBeHidden()
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await page.getByRole('button', { name: 'Выбрать канал' }).click()
  await expect(drawer).toBeHidden()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('announcements')
  await page.goBack()
  await expect(drawer).toBeHidden()
  await expect(search).toBeHidden()

  const admin = page.getByTestId('admin-panel')
  await page.getByRole('button', { name: 'Открыть администрирование' }).click()
  await expect(admin).toBeVisible()
  await page.goBack()
  await expect(admin).toBeHidden()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('announcements')
  await page.goForward()
  await expect(admin).toBeVisible()
  await page.getByRole('button', { name: 'Закрыть администрирование' }).click()
  await expect(admin).toBeHidden()
})

test('the production drawer focus manager exposes visible focus, traps traversal and restores it', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/focus_fixture.html')
  const trigger = page.getByRole('button', { name: 'Открыть навигацию' })
  const membersTrigger = page.getByRole('button', { name: 'Открыть участников' })
  const selection = page.getByRole('button', { name: 'Выбрать канал' })

  await trigger.press('Enter')
  await expect(page.getByRole('dialog', { name: 'Навигация по каналам' })).toHaveAttribute('aria-modal', 'true')
  await expect(selection).toBeFocused()
  const focusStyle = await selection.evaluate((element) => {
    const style = getComputedStyle(element)
    return {
      focusVisible: element.matches(':focus-visible'),
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth,
      outlineColor: style.outlineColor,
    }
  })
  expect(focusStyle.focusVisible).toBe(true)
  expect(focusStyle.outlineStyle).toBe('solid')
  expect(Number.parseFloat(focusStyle.outlineWidth)).toBeGreaterThanOrEqual(2)
  expect(focusStyle.outlineColor).toBe('rgb(180, 164, 255)')
  await page.screenshot({ path: testInfo.outputPath('navigation-keyboard-focus-visible.png') })
  await page.keyboard.press('Tab')
  await expect(selection).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(trigger).toBeFocused()
  await expect(page.getByRole('dialog')).toHaveCount(0)

  await trigger.click()
  await expect(selection).toBeFocused()
  await selection.click()
  await expect(trigger).toBeFocused()
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByText('Канал: общий')).toBeVisible()

  await membersTrigger.click()
  await expect(page.getByRole('dialog', { name: 'Панель участников' })).toHaveAttribute('aria-modal', 'true')
  await page.keyboard.press('Escape')
  await expect(membersTrigger).toBeFocused()
})
