import { expect, test } from '@playwright/test'
import { expectAxeClear } from './axe'

async function mountProductionComponent(
  page: import('@playwright/test').Page,
  component: string,
  props: Record<string, unknown> = {},
  wrapperClass = '',
): Promise<void> {
  await page.goto('/')
  await page.evaluate(async ({ component, props, wrapperClass }) => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Component } = await load(component)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(wrapperClass ? 'main' : 'div', { class: wrapperClass }, [h(Component, props)]) }).mount('#mount')
  }, { component, props, wrapperClass })
}

test('WCAG smoke covers navigation, search and connected voice dock', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/fixture.html')

  await expectAxeClear(page, '#app')
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await expectAxeClear(page, '#app')
  await page.getByTestId('workspace-sidebar').getByRole('button', { name: 'Закрыть навигацию' }).click()
  await page.getByRole('button', { name: 'Открыть поиск' }).click()
  await expectAxeClear(page, '#app')
})

test('WCAG keyboard smoke covers visible navigation focus, focus trap and restoration', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/focus_fixture.html')
  const trigger = page.getByRole('button', { name: 'Открыть навигацию' })
  const selection = page.getByRole('button', { name: 'Выбрать канал' })
  await trigger.press('Enter')
  const dialog = page.getByRole('dialog', { name: 'Навигация по каналам' })
  await expect(dialog).toBeVisible()
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
  await expectAxeClear(page, '.app-frame')
  await page.keyboard.press('Tab')
  await expect(selection).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
})

test('WCAG smoke covers guild admin members on a phone', async ({ page }) => {
  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER', blocked: false,
      created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z',
    }] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1 }, 'workspace-main-panel workspace-main-panel--admin')
  await expect(page.locator('.admin-mobile-card summary strong')).toHaveText('Участник')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const memberSearch = page.getByRole('searchbox', { name: 'Поиск участников' })
  await memberSearch.fill('без совпадений')
  await expect(page.getByText('Показано: 0 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('По текущим фильтрам участников нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(memberSearch).toHaveValue('')
  await expect(page.locator('.admin-mobile-card summary strong')).toHaveText('Участник')
  const statusFilter = page.getByRole('combobox', { name: 'Фильтр по статусу' })
  await statusFilter.selectOption('BLOCKED')
  await expect(page.getByText('Показано: 0 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('По текущим фильтрам участников нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(statusFilter).toHaveValue('ALL')
  for (const width of [320, 390]) {
    await page.setViewportSize({ width, height: 844 })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    for (const select of await page.locator('.admin-member-filters select').all()) {
      const bounds = await select.boundingBox()
      expect(bounds).not.toBeNull()
      expect((bounds?.x ?? 0) + (bounds?.width ?? 0)).toBeLessThanOrEqual(width)
    }
  }
  await page.setViewportSize({ width: 390, height: 844 })
  await expectAxeClear(page, '.admin-panel')
})

test('WCAG smoke covers profile settings', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: {
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER',
    },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')
  await expect(page.getByRole('heading', { name: 'Настройки' })).toBeVisible()
  await expectAxeClear(page, '.profile-settings')
})

test('browser text scaling to 200 percent reflows channel, admin, and settings controls', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })

  const expectRootScaledText = async (selector: string) => {
    const target = page.locator(selector).first()
    await page.evaluate(() => { document.documentElement.style.fontSize = '100%' })
    const baseline = Number.parseFloat(await target.evaluate(element => getComputedStyle(element).fontSize))
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
    const scaled = Number.parseFloat(await target.evaluate(element => getComputedStyle(element).fontSize))
    expect(scaled, `${selector} follows 200% browser text sizing`).toBeCloseTo(baseline * 2, 1)
  }
  const expectNoDocumentOverflow = async () => {
    const dimensions = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      viewportWidth: window.innerWidth,
      overflowing: [...document.querySelectorAll<HTMLElement>('*')]
        .filter(element => element.getBoundingClientRect().right > window.innerWidth + 1)
        .map(element => {
          const rect = element.getBoundingClientRect()
          return `${element.tagName.toLowerCase()}.${element.className.toString()}(${rect.left}-${rect.right}; parent=${element.parentElement?.getBoundingClientRect().left}-${element.parentElement?.getBoundingClientRect().right})`
        }),
    }))
    expect(dimensions.scrollWidth, JSON.stringify(dimensions)).toBeLessThanOrEqual(dimensions.viewportWidth)
  }

  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: { account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник', role: 'MEMBER' },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')
  const settingsHeading = page.locator('#profile-settings-title')
  await expect(settingsHeading).toHaveCSS('font-size', '22px')
  await page.setViewportSize({ width: 1440, height: 844 })
  await expect(settingsHeading).toHaveCSS('font-size', '24px')
  await page.setViewportSize({ width: 390, height: 844 })
  await expectRootScaledText('#profile-settings-title')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeVisible()
  }

  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{ account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник', role: 'MEMBER', blocked: false, created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z' }] }),
  }))
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1 }, 'workspace-main-panel workspace-main-panel--admin')
  await expectRootScaledText('#admin-panel-title')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    await expect(page.getByRole('navigation', { name: 'Разделы администрирования' }).getByRole('button', { name: 'Участники' })).toBeVisible()
    if (width >= 1024) {
      const tabs = page.locator('.admin-section-tabs')
      const tabsBounds = await tabs.boundingBox()
      expect(tabsBounds).not.toBeNull()
      for (const tab of await tabs.getByRole('button').all()) {
        const bounds = await tab.boundingBox()
        expect(bounds).not.toBeNull()
        expect(bounds?.x ?? 0).toBeGreaterThanOrEqual(tabsBounds?.x ?? 0)
        expect((bounds?.x ?? 0) + (bounds?.width ?? 0)).toBeLessThanOrEqual((tabsBounds?.x ?? 0) + (tabsBounds?.width ?? 0))
      }
    }
  }

  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const message = { id: 'scale-message', channelId: 'channel-1', authorId: 'user-1', clientMessageId: 'scale-client', body: 'Длинная строка сообщения проверяет перенос текста и доступность действий при увеличении системного размера шрифта.', createdAt: '2026-10-04T12:00:00Z', revision: 1, deleted: false }
    const app = createApp({ render: () => h('div', { class: 'message-list' }, [h(MessageItem, { message, canEdit: false, canDelete: false })]) })
    app.use(createPinia())
    app.mount('#mount')
  })
  await expectRootScaledText('.message-item p')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    if (width <= 600) {
      await expect(page.getByRole('button', { name: 'Действия с сообщением' })).toBeVisible()
      const message = await page.locator('.message-item p').first().boundingBox()
      const actions = await page.getByRole('button', { name: 'Действия с сообщением' }).boundingBox()
      expect(message).not.toBeNull()
      expect(actions).not.toBeNull()
      expect((message?.x ?? 0) + (message?.width ?? 0)).toBeLessThanOrEqual(actions?.x ?? 0)
    } else {
      await page.locator('.message-item').hover()
      await expect(page.getByRole('button', { name: 'Ответить' })).toBeVisible()
    }
  }

  await mountProductionComponent(page, '/src/shared/workspace_header/SettingsWorkspaceHeader.vue', {
    panel: 'admin',
    navExpanded: false,
  })
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
  const adminTitleFull = page.locator('.settings-workspace-title-full')
  const adminTitleCompact = page.locator('.settings-workspace-title-compact')
  await expect(adminTitleFull).toHaveText('Администрирование')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    const adminTitle = width <= 1023 ? adminTitleCompact : adminTitleFull
    await expect(adminTitle).toBeVisible()
    const bounds = await adminTitle.evaluate(element => {
      const text = element as HTMLElement
      const titleRect = text.getBoundingClientRect()
      const headerRect = text.parentElement!.getBoundingClientRect()
      return {
        clientWidth: titleRect.width,
        scrollWidth: text.scrollWidth,
        titleBottom: titleRect.bottom,
        headerBottom: headerRect.bottom,
      }
    })
    expect(bounds.scrollWidth, JSON.stringify(bounds)).toBeLessThanOrEqual(bounds.clientWidth + 1)
    expect(bounds.titleBottom, JSON.stringify(bounds)).toBeLessThanOrEqual(bounds.headerBottom + 1)
  }
})

test('reduced-motion preference suppresses UI transitions and smooth scrolling', async ({ page }) => {
  await page.goto('/')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  const style = await page.evaluate(() => {
    const button = document.createElement('button')
    button.className = 'gc-button'
    button.textContent = 'Проверка движения'
    document.body.append(button)
    const computed = getComputedStyle(button)
    const result = { transitionDuration: computed.transitionDuration, scrollBehavior: getComputedStyle(document.documentElement).scrollBehavior }
    button.remove()
    return result
  })
  const transitionSeconds = style.transitionDuration.endsWith('ms')
    ? Number.parseFloat(style.transitionDuration) / 1000
    : Number.parseFloat(style.transitionDuration)
  expect(transitionSeconds).toBeLessThanOrEqual(0.0001)
  expect(style.scrollBehavior).toBe('auto')
})

test('profile settings preserve a dirty name across tabs and expose pending and saved states', async ({ page }) => {
  let profileSaveAttempts = 0
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.route('**/api/v1/me', async route => {
    if (route.request().method() !== 'PATCH') {
      return route.fulfill({
        status: 200, contentType: 'application/json',
        body: JSON.stringify({ account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' }),
      })
    }
    profileSaveAttempts += 1
    await new Promise(resolve => setTimeout(resolve, 600))
    if (profileSaveAttempts === 1) {
      return route.fulfill({
        status: 503, contentType: 'application/json',
        body: JSON.stringify({ error: { message: 'Сервис временно недоступен. Повторите попытку.' } }),
      })
    }
    const body = route.request().postDataJSON() as { display_name: string }
    return route.fulfill({
      status: 200, contentType: 'application/json',
      body: JSON.stringify({ account_id: 'self', login: 'member', display_name: body.display_name, role: 'MEMBER', profile_revision: 2 }),
    })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const [{ createApp, h, ref }, { default: Component }] = await Promise.all([
      import('/node_modules/.vite/deps/vue.js'),
      import('/src/identity/ProfileSettings.vue'),
    ]) as any
    const profile = ref({ account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' })
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(Component, {
      profile: profile.value, loading: false, loadError: null,
      onSaved: (saved: typeof profile.value) => { profile.value = saved },
    }) }).mount('#mount')
  })

  const name = page.getByRole('textbox', { name: 'Отображаемое имя' })
  await name.fill('Новое имя')
  await expect(page.getByText('Есть несохранённые изменения', { exact: true })).toBeVisible()
  await page.getByRole('tab', { name: 'Безопасность' }).click()
  await page.getByRole('tab', { name: 'Профиль' }).click()
  await expect(name).toHaveValue('Новое имя')

  const save = page.getByRole('button', { name: 'Сохранить профиль' })
  await save.click()
  await expect(page.getByText('Сохраняем имя профиля…', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохраняем…' })).toBeDisabled()
  await expect(page.getByText('Сервис временно недоступен. Повторите попытку.', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeEnabled()
  await page.getByRole('button', { name: 'Сохранить профиль' }).click()
  await expect(page.getByText('Сохраняем имя профиля…', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохраняем…' })).toBeDisabled()
  await expect(page.getByText('Имя профиля сохранено.', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeDisabled()
  await name.fill('Следующее имя')
  await expect(page.getByText('Есть несохранённые изменения', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeEnabled()
})

test('profile logout waits for an explicit confirmation', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const [{ createApp, h }, { default: Component }] = await Promise.all([
      import('/node_modules/.vite/deps/vue.js'),
      import('/src/identity/ProfileSettings.vue'),
    ]) as any
    const profile = { account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' }
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(Component, {
      profile, loading: false, loadError: null,
      onLogout: () => { document.body.dataset.logout = 'confirmed' },
    }) }).mount('#mount')
  })

  const name = page.getByRole('textbox', { name: 'Отображаемое имя' })
  await name.fill('Несохранённое имя')
  await page.getByRole('tab', { name: 'Безопасность' }).click()
  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  const discard = page.getByRole('dialog', { name: 'Несохранённые изменения' })
  await expect(discard).toBeVisible()
  await discard.getByRole('button', { name: 'Отмена' }).click()
  await expect(discard).toHaveCount(0)
  expect(await page.locator('body').getAttribute('data-logout')).toBeNull()

  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  await page.getByRole('dialog', { name: 'Несохранённые изменения' }).getByRole('button', { name: 'Выйти без сохранения' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' })
  await expect(dialog).toBeVisible()
  await dialog.getByRole('button', { name: 'Отмена' }).click()
  await expect(dialog).toHaveCount(0)
  expect(await page.locator('body').getAttribute('data-logout')).toBeNull()

  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  await page.getByRole('dialog', { name: 'Несохранённые изменения' }).getByRole('button', { name: 'Выйти без сохранения' }).click()
  await page.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' }).getByRole('button', { name: 'Выйти' }).click()
  await expect(page.locator('body')).toHaveAttribute('data-logout', 'confirmed')
})

test('empty direct-message navigation offers a visible start-conversation action', async ({ page }, testInfo) => {
  await page.route('**/api/v1/members?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ members: [{
      user_id: 'member-1', login: 'alice', display_name: 'Алиса', role: 'MEMBER',
    }] }),
  }))
  await page.route('**/api/v1/auth/session', route => route.fulfill({
    status: 200, contentType: 'application/json',
    body: JSON.stringify({ authenticated: true, account_id: 'self', role: 'MEMBER' }),
  }))
  await page.route('**/api/v1/direct-message-candidates*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ candidates: [{ id: 'member-1', display_name: 'Алиса' }] }),
  }))
  await page.route('**/api/v1/direct-messages', route => route.fulfill({
    status: 201,
    contentType: 'application/json',
    body: JSON.stringify({
      id: 'dm-1', participant_one_id: 'self', participant_two_id: 'member-1',
      created_at: '2026-10-09T12:00:00Z',
    }),
  }))
  await page.route('**/api/v1/direct-messages/dm-1/messages*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ messages: [] }),
  }))
  await page.setViewportSize({ width: 320, height: 720 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const [{ createApp, h, ref }, { createPinia }, { useDirectMessageStore }, { default: Navigation }, { default: Conversation }] = await Promise.all([
      load('/node_modules/.vite/deps/vue.js'),
      load('/node_modules/.vite/deps/pinia.js'),
      load('/src/direct_message/direct_message_store.ts'),
      load('/src/direct_message/DirectMessageNavigation.vue'),
      load('/src/direct_message/DirectMessageConversation.vue'),
    ]) as any
    const pinia = createPinia()
    const directMessages = useDirectMessageStore(pinia)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({
      setup() {
        const opened = ref('')
        return () => h('main', [
          h(Navigation, {
            directMessages: [], error: null, loading: false,
            onOpen: (id: string) => { opened.value = id; void directMessages.open(id) },
          }),
          h('output', { 'data-testid': 'opened-direct-message' }, opened.value),
          opened.value ? h(Conversation, {
            accountId: 'self', active: true, directMessageId: opened.value,
            otherParticipantId: 'member-1', otherParticipantDisplayName: 'Алиса', navOpen: false,
          }) : null,
        ])
      },
    }).use(pinia).mount('#mount')
  })

  await expect(page.getByText('Начните личный разговор с участником.', { exact: true })).toBeVisible()
  const start = page.getByRole('button', { name: 'Начать диалог' })
  await expect(start).toBeVisible()
  await expect(start).toContainText('Начать диалог')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await expectAxeClear(page, '.direct-message-navigation')
  await start.click()
  await expect(page.getByRole('dialog', { name: 'Новый личный диалог' })).toBeVisible()
  await page.getByRole('button', { name: 'Алиса' }).click()
  await expect(page.getByTestId('opened-direct-message')).toHaveText('dm-1')
  await expect(page.getByRole('heading', { name: 'Алиса' })).toBeVisible()
  await expect(page.getByRole('textbox', { name: 'Сообщение' })).toBeVisible()
  await expect(page.getByText('Сообщений пока нет.')).toBeVisible()
  await page.screenshot({ path: testInfo.outputPath('direct-message-empty-after.png'), fullPage: true })
})

test('direct-message search keeps its query and results after opening and returning from context', async ({ page }) => {
  await page.route('**/api/v1/**', route => {
    const url = new URL(route.request().url())
    const message = {
      id: 'message-1', direct_message_id: 'dm-1', author_id: 'member-1',
      client_message_id: 'client-message-1', body: 'Оригинальный контекст',
      created_at: '2026-10-09T12:00:00Z', revision: 1, deleted: false,
      attachments: [], mention_user_ids: [],
    }
    if (url.pathname === '/api/v1/auth/session') {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ authenticated: true, account_id: 'self', role: 'MEMBER' }) })
    }
    if (url.pathname.endsWith('/search')) {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ messages: [{
        id: message.id, direct_message_id: 'dm-1', author_id: 'member-1',
        body: 'Найденный результат', created_at: message.created_at, revision: 1,
      }] }) })
    }
    if (url.pathname.endsWith('/messages')) {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ messages: url.searchParams.has('at') ? [message] : [] }) })
    }
    if (url.pathname === '/api/v1/members') {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ members: [{
        user_id: 'member-1', login: 'alice', display_name: 'Алиса', role: 'MEMBER',
      }] }) })
    }
    return route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const [{ createApp, h, ref }, { createPinia }, { useDirectMessageStore }, { default: Component }] = await Promise.all([
      load('/node_modules/.vite/deps/vue.js'),
      load('/node_modules/.vite/deps/pinia.js'),
      load('/src/direct_message/direct_message_store.ts'),
      load('/src/direct_message/DirectMessageConversation.vue'),
    ]) as any
    const pinia = createPinia()
    const store = useDirectMessageStore(pinia)
    const conversationId = ref('dm-1')
    await store.open(conversationId.value)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h('main', [
      h('button', {
        type: 'button',
        onClick: () => {
          conversationId.value = conversationId.value === 'dm-1' ? 'dm-2' : 'dm-1'
          void store.open(conversationId.value)
        },
      }, 'Переключить диалог'),
      h(Component, {
        accountId: 'self', active: true, directMessageId: conversationId.value,
        otherParticipantId: 'member-1',
        otherParticipantDisplayName: conversationId.value === 'dm-1' ? 'Алиса' : 'Борис',
        navOpen: false,
      }),
    ]) }).use(pinia).mount('#mount')
  })

  const directSearch = page.getByRole('button', { name: 'Найти сообщение' })
  const openSearch = async () => {
    await expect(directSearch).toBeVisible()
    await directSearch.click()
  }
  await expect(directSearch).toBeVisible()
  const searchBounds = await directSearch.boundingBox()
  expect(searchBounds?.width).toBeGreaterThanOrEqual(44)
  expect(searchBounds?.height).toBeGreaterThanOrEqual(44)
  await openSearch()
  const query = page.getByRole('searchbox', { name: 'Запрос' })
  await query.fill('контекст')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect(page.getByText('Найденный результат')).toBeVisible()
  await page.getByRole('button', { name: 'Открыть сообщение' }).click()
  await expect(page.getByRole('heading', { name: 'Контекст найденного сообщения' })).toBeVisible()
  await page.getByRole('button', { name: 'Вернуться к исходной позиции' }).click()
  await expect(page.getByText('Найденный результат')).toBeVisible()

  await page.getByRole('searchbox', { name: 'Запрос' }).press('Escape')
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Переключить диалог' }).click()
  await expect(page.getByRole('heading', { name: 'Борис' })).toBeVisible()
  await openSearch()
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveValue('')
  await page.getByRole('searchbox', { name: 'Запрос' }).press('Escape')
  await page.getByRole('button', { name: 'Переключить диалог' }).click()
  await expect(page.getByRole('heading', { name: 'Алиса' })).toBeVisible()
  await openSearch()
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveValue('контекст')
  await expect(page.getByText('Найденный результат')).toBeVisible()
})

test('profile settings tabs support Arrow, Home and End keyboard navigation', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: {
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER',
    },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')

  await expect(page.getByRole('heading', { name: 'Настройки' })).toBeFocused()
  const profile = page.getByRole('tab', { name: 'Профиль' })
  const security = page.getByRole('tab', { name: 'Безопасность' })
  const about = page.getByRole('tab', { name: 'О приложении' })
  await profile.focus()
  await page.keyboard.press('ArrowRight')
  await expect(security).toBeFocused()
  await expect(security).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('tabpanel', { name: 'Безопасность' })).toBeVisible()
  await page.keyboard.press('ArrowLeft')
  await expect(profile).toBeFocused()
  await page.keyboard.press('ArrowLeft')
  await expect(about).toBeFocused()
  await expect(about).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('Home')
  await expect(profile).toBeFocused()
  await expect(profile).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('End')
  await expect(about).toBeFocused()
  await expect(about).toHaveAttribute('aria-selected', 'true')
})

test('WCAG smoke covers voice prejoin actions', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1', voiceError: null, voiceState: 'DISCONNECTED', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })
  const joinWithMicrophone = page.getByRole('button', { name: 'Войти' })
  const joinAsListener = page.getByRole('button', { name: 'Без микрофона' })
  await expect(joinWithMicrophone).toBeVisible()
  await expect(joinAsListener).toBeVisible()
  await expect(joinWithMicrophone).toHaveClass(/gc-button--primary/)
  await expect(joinAsListener).toHaveClass(/gc-button--secondary/)
  expect(await page.locator('.voice-prejoin-actions button').evaluateAll((buttons) => buttons.map(button => button.textContent?.trim()))).toEqual([
    'Войти', 'Без микрофона',
  ])
  await expectAxeClear(page, '.voice-prejoin')
})

test('voice prejoin announces connecting and blocks duplicate joins', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1', voiceError: null, voiceState: 'JOINING', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })

  await expect(page.getByRole('heading', { name: 'Входим в голос…' })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Входим в голос…' })).toHaveAttribute('aria-live', 'polite')
  await expect(page.locator('.voice-prejoin-copy')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Подключаемся…' })).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Без микрофона' })).toBeDisabled()
  await expectAxeClear(page, '.voice-prejoin')
})

test('connected voice room keeps connection status and stream action available', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { default: VoiceRoomConnected } = await load('/src/voice/VoiceRoomConnected.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(VoiceRoomConnected, {
      roomName: 'Основная комната', voiceState: 'CONNECTED', screenState: 'IDLE',
      screenError: null,
      screenDiagnostics: { audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', source: 'UNKNOWN', measured: null },
      screenProfile: null, selectedScreenProfile: 'P1080_30', screenViewerCards: [],
      voiceVolumeError: null, voiceVolumeParticipants: [], selfName: 'Алексей',
      selfDeafened: false, selfMicrophoneMuted: false, selfMicrophoneUnavailable: false,
      selfSpeaking: false, toggleMicrophone: () => {}, toggleDeafen: () => {},
    }) }).mount('#mount')
  })

  const intro = page.locator('.room-intro')
  await expect(intro.getByRole('status')).toHaveText('В голосе')
  await expect(intro.getByRole('status')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Начать демонстрацию экрана', exact: true })).toBeEnabled()
  await expect(page.getByRole('button', { name: 'Выйти из голосового канала' })).toBeEnabled()
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('desktop-voice-room-after.png'), fullPage: true })

  await page.setViewportSize({ width: 390, height: 844 })
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('mobile-voice-room-after.png'), fullPage: true })
})

test('voice prejoin explains a missing microphone and keeps the listener path available', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1',
    voiceError: 'Микрофон не найден. Подключитесь без микрофона или подключите устройство и повторите попытку.',
    voiceState: 'ERROR', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })

  await expect(page.getByRole('alert')).toContainText('Микрофон не найден')
  await expect(page.getByRole('button', { name: 'Без микрофона' })).toBeEnabled()
  await expectAxeClear(page, '.voice-prejoin')
  await page.screenshot({ path: testInfo.outputPath('voice-prejoin-microphone-missing.png') })
  await page.setViewportSize({ width: 1440, height: 900 })
  await expectAxeClear(page, '.voice-prejoin')
  await page.screenshot({ path: testInfo.outputPath('voice-prejoin-desktop-after.png') })
})

test('voice dock explains denied microphone access and exposes a retry at mobile 2x text', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoiceDock.vue', {
    channel: { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false },
    activeSession: true, error: null, activationMode: 'VAD', deafened: false,
    deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: true,
    state: 'LISTENER', participantCount: 2,
  })
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })

  const dock = page.getByTestId('voice-dock')
  const notice = dock.getByRole('status').filter({ hasText: 'Вы подключены как слушатель' })
  const retry = dock.getByRole('button', { name: 'Повторить доступ к микрофону' })
  await expect(notice).toContainText('браузер запретил доступ к микрофону')
  await expect(notice).toContainText('нажмите «Повторить доступ к микрофону»')
  await expect(retry).toBeEnabled()
  await expect(retry).toHaveAttribute('aria-pressed', 'false')
  const bounds = await retry.boundingBox()
  expect(bounds).not.toBeNull()
  expect(bounds!.x).toBeGreaterThanOrEqual(0)
  expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(320)
  expect(bounds!.y + bounds!.height).toBeLessThanOrEqual(640)
  await expectAxeClear(page, '.voice-dock')
  await page.screenshot({ path: testInfo.outputPath('voice-dock-mic-denied-2x.png') })
})

test('voice dock keeps muted and deafened states red without a red border', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, reactive } = await load('/node_modules/.vite/deps/vue.js')
    const { default: VoiceDock } = await load('/src/voice/VoiceDock.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const props = reactive({
      channel: { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false },
      activeSession: true,
      error: null,
      activationMode: 'VAD',
      deafened: false,
      deafenChanging: false,
      microphoneMuted: false,
      microphonePermissionDenied: false,
      state: 'CONNECTED',
    })
    createApp({
      render: () => h(VoiceDock, {
        ...props,
        onToggleMicrophone: () => { props.microphoneMuted = !props.microphoneMuted },
        onToggleDeafen: () => { props.deafened = !props.deafened },
      }),
    }).mount('#mount')
  })

  const mutedToggle = page.getByRole('button', { name: 'Выключить микрофон' })
  await mutedToggle.click()
  const mutedButton = page.getByRole('button', { name: 'Включить микрофон' })
  await expect(mutedButton).toHaveClass(/voice-icon-button--danger-active/)
  await expect(mutedButton).toHaveCSS('background-color', 'rgb(185, 28, 28)')
  await expect(mutedButton).toHaveCSS('border-top-width', '0px')
  await expect(mutedButton).toHaveCSS('color', 'rgb(255, 255, 255)')
  await mutedButton.click()
  await expect(page.getByRole('button', { name: 'Выключить микрофон' })).not.toHaveClass(/voice-icon-button--danger-active/)

  await page.getByRole('button', { name: 'Выключить удалённый звук' }).click()
  const deafenedButton = page.getByRole('button', { name: 'Включить удалённый звук' })
  await expect(deafenedButton).toHaveClass(/voice-icon-button--danger-active/)
  await expect(deafenedButton).toHaveCSS('background-color', 'rgb(185, 28, 28)')
  await expect(deafenedButton).toHaveCSS('border-top-width', '0px')
  await expect(deafenedButton).toHaveCSS('color', 'rgb(255, 255, 255)')
  await expectAxeClear(page, '.voice-dock')
  await page.screenshot({ path: testInfo.outputPath('voice-dock-muted-deafened-active.png') })
})

test('voice dock and audio settings icons expose keyboard names, focus and activation', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, reactive } = await load('/node_modules/.vite/deps/vue.js')
    const { default: VoiceDock } = await load('/src/voice/VoiceDock.vue')
    const { default: WorkspaceUserFooter } = await load('/src/workspace/WorkspaceUserFooter.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    Object.assign(window, { __uiuxSettingsActivated: false })
    const state = reactive({
      channel: { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false },
      activeSession: true,
      error: null,
      activationMode: 'VAD',
      deafened: false,
      deafenChanging: false,
      microphoneMuted: false,
      microphonePermissionDenied: false,
      screenShareState: 'IDLE',
      state: 'CONNECTED',
    })
    createApp({
      render: () => h('main', [
        h(WorkspaceUserFooter, {
          role: 'ADMINISTRATOR', displayName: 'Алексей',
          onOpenSettings: () => Object.assign(window, { __uiuxSettingsActivated: true }),
        }),
        h(VoiceDock, {
          ...state,
          onToggleMicrophone: () => { state.microphoneMuted = !state.microphoneMuted },
          onToggleDeafen: () => { state.deafened = !state.deafened },
          onStartScreen: () => { state.screenShareState = 'STARTING' },
          onLeave: () => { state.state = 'LEAVING' },
        }),
      ]),
    }).mount('#mount')
  })

  const profileButton = page.getByRole('button', { name: 'Открыть настройки профиля' })
  const settingsButton = page.getByRole('button', { name: 'Настройки аудио' })
  const muteButton = page.getByRole('button', { name: 'Выключить микрофон' })
  const deafenButton = page.getByRole('button', { name: 'Выключить удалённый звук' })
  const shareButton = page.locator('.voice-actions button').nth(2)
  const leaveButton = page.getByRole('button', { name: 'Выйти из голосового канала' })
  const userAgent = await page.evaluate(() => navigator.userAgent)
  const webkitUsesSystemTabPolicy = userAgent.includes('AppleWebKit') && !userAgent.includes('Chrome')
  const focusButton = async (button: typeof profileButton) => {
    if (webkitUsesSystemTabPolicy) {
      // The WebKit host follows Safari's default Full Keyboard Access setting, which excludes buttons from Tab traversal.
      await page.keyboard.press('Tab')
      await button.focus()
    } else {
      await page.keyboard.press('Tab')
    }
    await expect(button).toBeFocused()
  }

  await focusButton(profileButton)
  await focusButton(settingsButton)
  await expect(settingsButton).toHaveCSS('outline-style', 'solid')
  await expect(settingsButton).toHaveCSS('outline-width', '2px')
  await page.keyboard.press('Enter')
  expect(await page.evaluate(() => Boolean((window as typeof window & { __uiuxSettingsActivated?: boolean }).__uiuxSettingsActivated))).toBe(true)

  await focusButton(muteButton)
  await expect(muteButton).toHaveCSS('outline-style', 'solid')
  await page.keyboard.press('Space')
  const mutedButton = page.getByRole('button', { name: 'Включить микрофон' })
  await expect(mutedButton).toHaveAttribute('aria-pressed', 'false')
  await expect(mutedButton).toHaveClass(/voice-icon-button--danger-active/)

  await focusButton(deafenButton)
  await page.keyboard.press('Enter')
  const deafenedButton = page.getByRole('button', { name: 'Включить удалённый звук' })
  await expect(deafenedButton).toHaveAttribute('aria-pressed', 'true')
  await expect(deafenedButton).toHaveClass(/voice-icon-button--danger-active/)

  await expect(shareButton).toHaveAttribute('aria-label', /.+/)
  if (await shareButton.isEnabled()) {
    await focusButton(shareButton)
    await page.keyboard.press('Enter')
    await expect(shareButton).toBeDisabled()
  }
  await focusButton(leaveButton)
  await page.keyboard.press('Enter')
  await expect(leaveButton).toBeDisabled()
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('voice-settings-dock-keyboard.png') })
})

test('voice and settings icon targets meet desktop and mobile minimum dimensions', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { default: VoiceDock } = await load('/src/voice/VoiceDock.vue')
    const { default: WorkspaceUserFooter } = await load('/src/workspace/WorkspaceUserFooter.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const channel = { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false }
    createApp({ render: () => h('aside', { class: 'sidebar' }, [
      h('div', { class: 'mobile-voice-dock mobile-visible' }, [h(VoiceDock, {
        channel, activeSession: true, error: null, activationMode: 'VAD', deafened: false,
        deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: false,
        screenShareState: 'IDLE', state: 'CONNECTED',
      })]),
      h(WorkspaceUserFooter, { role: 'ADMINISTRATOR', displayName: 'Алексей' }),
    ]) }).mount('#mount')
  })

  const settings = page.getByRole('button', { name: 'Настройки аудио' })
  const dockButtons = page.locator('.mobile-voice-dock .voice-actions .voice-icon-button')
  await expect(settings).toBeVisible()
  await expect(dockButtons).toHaveCount(4)
  const desktopSettings = await settings.boundingBox()
  expect(desktopSettings).not.toBeNull()
  expect(desktopSettings!.width).toBe(40)
  expect(desktopSettings!.height).toBe(40)
  const desktopGear = await settings.locator('svg').boundingBox()
  expect(desktopGear).not.toBeNull()
  expect(desktopGear!.width).toBe(22)
  expect(desktopGear!.height).toBe(22)
  for (const button of await dockButtons.all()) {
    const bounds = await button.boundingBox()
    expect(bounds).not.toBeNull()
    expect(bounds!.width).toBeGreaterThanOrEqual(40)
    expect(bounds!.height).toBe(40)
  }
  await page.screenshot({ path: testInfo.outputPath('voice-settings-targets-desktop.png') })

  await page.setViewportSize({ width: 390, height: 844 })
  await page.locator('.sidebar').evaluate(element => element.classList.add('is-open'))
  const mobileSettings = await settings.boundingBox()
  expect(mobileSettings).not.toBeNull()
  expect(mobileSettings!.width).toBe(44)
  expect(mobileSettings!.height).toBe(44)
  for (const button of await dockButtons.all()) {
    const bounds = await button.boundingBox()
    expect(bounds).not.toBeNull()
    expect(bounds!.width).toBeGreaterThanOrEqual(44)
    expect(bounds!.height).toBe(44)
  }
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await page.screenshot({ path: testInfo.outputPath('voice-settings-targets-mobile.png') })
})

test('screen-share setup keeps selection primary and capabilities discoverable', async ({ page, browser }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { default: ScreenShareSetupDialog } = await load('/src/voice/ScreenShareSetupDialog.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    Object.assign(window, { __startedScreenProfile: null })
    createApp({ render: () => h(ScreenShareSetupDialog, {
      initialProfile: 'P1080_30',
      onCancel: () => {},
      onStart: (profile: string) => { Object.assign(window, { __startedScreenProfile: profile }) },
    }) }).mount('#mount')
  })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const header = dialog.locator('.screen-share-setup__header')
  const qualitySettings = dialog.locator('.screen-share-quality__settings')
  const capabilityDetails = dialog.locator('.screen-share-capabilities__details')
  await expect(capabilityDetails).not.toHaveAttribute('open', '')
  await expect(dialog.locator('.screen-share-capabilities__availability')).not.toBeVisible()
  await expect(dialog.getByText('Рекомендуемый профиль', { exact: true })).toHaveCount(0)
  await expect(dialog.getByText('Текущий выбор: 1080p · 30 FPS', { exact: true })).toBeVisible()
  await expect(header).toBeInViewport({ ratio: 0.99 })
  await expect(dialog.locator('.screen-share-setup__footer')).toBeInViewport({ ratio: 0.99 })
  await page.screenshot({ path: testInfo.outputPath('screen-share-setup-320x640-initial.png') })
  await capabilityDetails.locator('summary').click()
  await expect(dialog.locator('.screen-share-capabilities__availability')).toContainText('Поддержка видео до выбора источника')
  await page.screenshot({ path: testInfo.outputPath('screen-share-setup-capabilities.png') })
  await capabilityDetails.locator('summary').click()
  await expect(qualitySettings).toBeVisible()
  await expect(dialog.getByRole('radio', { name: '1440p' })).toBeVisible()
  await dialog.getByRole('radio', { name: '60 FPS', exact: true }).check()
  await expect(dialog.getByText('Текущий выбор: 1080p · 60 FPS', { exact: true })).toBeVisible()
  await dialog.getByRole('radio', { name: '720p' }).check()
  await expect(dialog.getByText('Текущий выбор: 720p · 60 FPS', { exact: true })).toBeVisible()
  await expectAxeClear(page, '.screen-share-setup-dialog')
  await page.screenshot({ path: testInfo.outputPath('screen-share-setup-progressive-options.png') })
  await page.setViewportSize({ width: 1440, height: 900 })
  await expect(dialog.getByText('Текущий выбор: 720p · 60 FPS', { exact: true })).toBeVisible()
  await expectAxeClear(page, '.screen-share-setup-dialog')
  await page.evaluate(() => window.scrollTo(0, 0))
  await dialog.evaluate(element => { element.scrollTop = 0 })
  await dialog.locator('.screen-share-setup__body').evaluate(element => { element.scrollTop = 0 })
  await header.scrollIntoViewIfNeeded()
  await expect(header).toBeInViewport({ ratio: 0.99 })
  await page.screenshot({ path: testInfo.outputPath('desktop-stream-launch-settings-after.png'), fullPage: true })
  await page.screenshot({ path: testInfo.outputPath('desktop-stream-launch-actions-after.png'), fullPage: true })
  await dialog.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => (window as Window & { __startedScreenProfile?: string }).__startedScreenProfile)).toBe('P720_60')

  const captureContext = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 2 })
  try {
    const capturePage = await captureContext.newPage()
    await capturePage.goto('/')
    await capturePage.evaluate(async () => {
      const load = (path: string) => import(path)
      const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
      const { default: CaptureDialog } = await load('/src/voice/ScreenShareSetupDialog.vue')
      document.body.innerHTML = '<div id="mount"></div>'
      createApp({ render: () => h(CaptureDialog, { initialProfile: 'P1080_30', onCancel: () => {}, onStart: () => {} }) }).mount('#mount')
    })
    const captureDialog = capturePage.getByRole('dialog', { name: 'Демонстрация экрана' })
    await expect(captureDialog).toBeVisible()
    await expect(captureDialog.locator('.screen-share-setup__header')).toBeInViewport()
    await capturePage.screenshot({ path: testInfo.outputPath('mobile-stream-launch-settings-after.png'), scale: 'device' })
    await capturePage.setViewportSize({ width: 1440, height: 900 })
    await capturePage.evaluate(() => window.scrollTo(0, 0))
    await captureDialog.evaluate(element => { element.scrollTop = 0 })
    await captureDialog.locator('.screen-share-setup__body').evaluate(element => { element.scrollTop = 0 })
    await captureDialog.locator('.screen-share-setup__header').scrollIntoViewIfNeeded()
    await expect(captureDialog.locator('.screen-share-setup__header')).toBeInViewport({ ratio: 0.99 })
    await capturePage.screenshot({ path: testInfo.outputPath('desktop-stream-launch-settings-source-scale-after.png'), fullPage: true, scale: 'device' })
    await captureDialog.evaluate(element => { element.scrollTop = element.scrollHeight })
    await captureDialog.locator('.screen-share-setup__body').evaluate(element => { element.scrollTop = element.scrollHeight })
    await captureDialog.locator('.screen-share-setup__footer').scrollIntoViewIfNeeded()
    await expect(captureDialog.locator('.screen-share-setup__footer')).toBeInViewport()
    await capturePage.screenshot({ path: testInfo.outputPath('desktop-stream-launch-actions-source-scale-after.png'), fullPage: true, scale: 'device' })
  } finally {
    await captureContext.close()
  }
})

test('screen-share selectors fit their options and preserve scenario for the 1440p profile', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await mountProductionComponent(page, '/src/voice/ScreenShareSetupDialog.vue', { initialProfile: 'P1080_60' })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const header = dialog.locator('.screen-share-setup__header')
  const body = dialog.locator('.screen-share-setup__body')
  const footer = dialog.locator('.screen-share-setup__footer')

  await expect(header).toBeInViewport({ ratio: 0.99 })
  await expect(footer).toBeInViewport({ ratio: 0.99 })
  await expect(body).toHaveCSS('overflow-y', 'auto')
  expect(await body.evaluate(element => element.scrollHeight > element.clientHeight)).toBe(true)
  const groups = dialog.locator('.screen-share-quality__row')
  const readSelectorLayout = () => groups.evaluateAll(elements => elements.map(field => {
    const selector = field.querySelector<HTMLElement>('.screen-share-quality__scenarios, .screen-share-quality__segments, .screen-share-quality__single-value')!
    const label = field.querySelector<HTMLElement>('legend, .screen-share-quality__frame-rate-label')!
    const selectorBox = selector.getBoundingClientRect()
    const labelBox = label.getBoundingClientRect()
    const columns = getComputedStyle(selector).gridTemplateColumns.split(/\s+/).filter(Boolean).length
    const labels = selector.querySelectorAll('.screen-share-quality__scenario-title, .screen-share-quality__scenario-copy small, .screen-share-quality__option span')
    const labelsFit = [...labels].every(label => label.scrollWidth <= label.clientWidth && label.scrollHeight <= label.clientHeight)
    const placedBeforeOrBeside = labelBox.bottom <= selectorBox.top + 1
      || (labelBox.right <= selectorBox.left + 1
        && Math.abs((labelBox.top + labelBox.bottom) / 2 - (selectorBox.top + selectorBox.bottom) / 2) <= selectorBox.height)
    const labelFits = placedBeforeOrBeside
    return { columns, labelsFit, labelFits }
  }))
  const motionLayout = await readSelectorLayout()
  expect(motionLayout.map(group => group.columns)).toEqual([2, 3, 3])
  expect(motionLayout.every(group => group.labelsFit && group.labelFits)).toBe(true)

  const resolution = dialog.getByRole('radio', { name: '1440p' })
  await expect(dialog.locator('.screen-share-quality__mode')).toBeInViewport({ ratio: 0.99 })
  await expect(dialog.locator('[aria-label=\"Верхний предел разрешения трансляции\"]')).toBeInViewport({ ratio: 0.99 })
  await expect(resolution).toBeInViewport({ ratio: 0.99 })
  await expect(resolution).toBeEnabled()
  await expectAxeClear(page, '.screen-share-setup-dialog')
  await resolution.check()
  await expect(dialog.getByRole('radio', { name: /Плавность/ })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeChecked()
  await expect(dialog.getByText('Текущий выбор: 1440p · 30 FPS', { exact: true })).toBeVisible()
  await expect(dialog.locator('.screen-share-quality__mode')).toBeInViewport({ ratio: 0.99 })
  await expect(resolution).toBeInViewport({ ratio: 0.99 })
  await expect(header).toBeInViewport({ ratio: 0.99 })
  await expect(footer).toBeInViewport({ ratio: 0.99 })
  await expectAxeClear(page, '.screen-share-setup-dialog')
  await page.screenshot({ path: testInfo.outputPath('screen-share-selector-layout-637x584.png') })

  const layout = await Promise.all([header, body, footer].map(element => element.boundingBox()))
  expect(layout[0]!.y + layout[0]!.height).toBeLessThanOrEqual(layout[1]!.y + 1)
  expect(layout[1]!.y + layout[1]!.height).toBeLessThanOrEqual(layout[2]!.y + 1)
})

test('WCAG smoke covers screen share setup and destructive confirmation dialogs', async ({ page }) => {
  await mountProductionComponent(page, '/src/voice/ScreenShareSetupDialog.vue', { initialProfile: 'P1080_30' })
  await expect(page.getByRole('dialog', { name: 'Демонстрация экрана' })).toBeVisible()
  await expectAxeClear(page, '.screen-share-setup-dialog')

  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Confirm } = await load('/src/channel/AdminConfirmation.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const prompt = ref(null)
    createApp({ render: () => h('div', [
      h('button', { onClick: () => void prompt.value.ask('Удалить канал «общее»?') }, 'Удалить канал'),
      h(Confirm, { ref: prompt, id: 'delete-channel', title: 'Удалить канал', confirmLabel: 'Удалить' }),
    ]) }).mount('#mount')
  })
  await page.getByRole('button', { name: 'Удалить канал', exact: true }).click()
  await expect(page.getByRole('dialog', { name: 'Удалить канал' })).toBeVisible()
  await expectAxeClear(page, '.admin-confirm-dialog')
})

test('destructive confirmation defaults to cancel, traps focus and requires an explicit choice', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Confirm } = await load('/src/channel/AdminConfirmation.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const prompt = ref(null)
    const answer = ref('pending')
    createApp({ render: () => h('div', [
      h('button', {
        onClick: () => void prompt.value.ask('Удалить канал «общее»?').then((confirmed: boolean) => { answer.value = String(confirmed) }),
      }, 'Удалить канал'),
      h('output', { id: 'confirmation-result' }, answer.value),
      h(Confirm, { ref: prompt, id: 'delete-channel', title: 'Удалить канал', confirmLabel: 'Удалить' }),
    ]) }).mount('#mount')
  })

  const trigger = page.getByRole('button', { name: 'Удалить канал', exact: true })
  await trigger.click()
  const dialog = page.getByRole('dialog', { name: 'Удалить канал' })
  const cancel = dialog.getByRole('button', { name: 'Отмена' })
  const confirm = dialog.getByRole('button', { name: 'Удалить', exact: true })
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
  await expect(page.locator('#confirmation-result')).toHaveText('false')

  await trigger.click()
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(confirm).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(confirm).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(cancel).toBeFocused()
  await page.mouse.click(1, 1)
  await expect(dialog).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
  await expect(page.locator('#confirmation-result')).toHaveText('false')

  await trigger.click()
  await expect(cancel).toBeFocused()
  await confirm.click()
  await expect(dialog).toBeHidden()
  await expect(page.locator('#confirmation-result')).toHaveText('true')
})

test('WCAG smoke distinguishes readiness loading, refresh, stale failure and retry states', async ({ page }, testInfo) => {
  let requests = 0
  let releaseInitial: (() => void) | undefined
  let releaseRefresh: (() => void) | undefined
  const checkedAt = new Date().toISOString()
  const readyProbe = {
    status: 'ready', sampled_at: checkedAt, pending_revocations: 0,
    available_bytes: 1024, total_bytes: 2048, reserved_bytes: 0,
    protected_bytes: 0, headroom_bytes: 1024,
  }
  const ready = {
    status: 'ready', checked_at: checkedAt,
    database: readyProbe, sfu: readyProbe, storage: readyProbe,
  }
  await page.route('**/api/v1/admin/readiness', async route => {
    requests += 1
    if (requests === 1) {
      await new Promise<void>(resolve => { releaseInitial = resolve })
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(ready) })
    } else if (requests === 2) {
      await new Promise<void>(resolve => { releaseRefresh = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: '{}' })
    } else {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(ready) })
    }
  })
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/admin/readiness/Panel.vue')

  const status = page.getByRole('status')
  await expect(status).toHaveText('Проверяем готовность сервисов')
  releaseInitial?.()
  await expect(status).toHaveText('Сервисы готовы')
  await expectAxeClear(page, '#mount')
  const dependencyTopWhenReady = await page.locator('.readiness-dependencies').evaluate(element => element.getBoundingClientRect().top + window.scrollY)

  const refresh = page.locator('section[aria-labelledby="readiness-title"] > button')
  await refresh.click()
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Проверяем…')
  await expect(status).toHaveText('Обновляем проверку; показан предыдущий результат')
  const dependencyTopWhenRefreshing = await page.locator('.readiness-dependencies').evaluate(element => element.getBoundingClientRect().top + window.scrollY)
  expect(Math.abs(dependencyTopWhenRefreshing - dependencyTopWhenReady)).toBeLessThanOrEqual(1)
  releaseRefresh?.()
  await expect(page.getByRole('alert')).toHaveText('Сервис временно не отвечает. Попробуйте позже.')
  await expect(status).toHaveText('Нет свежего подтверждения готовности')
  await expect(page.locator('dl dd').first()).toHaveText('Устарело')
  const dependencyTopAfterFailure = await page.locator('.readiness-dependencies').evaluate(element => element.getBoundingClientRect().top + window.scrollY)
  expect(Math.abs(dependencyTopAfterFailure - dependencyTopWhenReady)).toBeLessThanOrEqual(1)
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('readiness-stale-503-mobile-after.png'), fullPage: true })

  await refresh.click()
  await expect(status).toHaveText('Сервисы готовы')
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('readiness service and capacity values use a responsive dashboard layout', async ({ page }, testInfo) => {
  const sampledAt = new Date().toISOString()
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.route('**/api/v1/admin/readiness', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      status: 'ready', checked_at: sampledAt,
      database: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: 2,
        available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
      sfu: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: null,
        available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
      storage: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: null,
        available_bytes: 67108864, total_bytes: 134217728, reserved_bytes: 1048576,
        protected_bytes: 2097152, headroom_bytes: 63963136 },
    }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1, section: 'readiness' }, 'workspace-main-panel workspace-main-panel--admin')

  const section = page.locator('[aria-labelledby="readiness-title"]')
  const tab = page.getByRole('button', { name: 'Готовность', exact: true })
  await expect(tab).toHaveAttribute('aria-current', 'page')
  await expect(page.locator('.readiness-capacity')).not.toBeVisible()
  await page.getByText(/Запас и технические показатели ·/).click()
  await expect(page.locator('.readiness-capacity')).toBeVisible()
  for (const width of [320, 390, 600, 840, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expect(page.getByRole('status').filter({ hasText: 'Сервисы готовы' })).toBeVisible()
    for (const selector of ['.readiness-dependencies', '.readiness-capacity']) {
      const grid = page.locator(selector)
      const bounds = await grid.boundingBox()
      const sectionBounds = await section.boundingBox()
      expect(bounds).not.toBeNull()
      expect(sectionBounds).not.toBeNull()
      expect(bounds!.width).toBeGreaterThan(sectionBounds!.width * 0.9)
      expect(bounds!.x).toBeGreaterThanOrEqual(sectionBounds!.x)
      expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(sectionBounds!.x + sectionBounds!.width + 1)
    }
    for (const pair of await page.locator('.readiness-dependencies > div, .readiness-capacity > div').all()) {
      const bounds = await pair.boundingBox()
      const label = await pair.locator('dt').boundingBox()
      const value = await pair.locator('dd').boundingBox()
      expect(bounds).not.toBeNull()
      expect(label).not.toBeNull()
      expect(value).not.toBeNull()
      expect(label!.x).toBeGreaterThanOrEqual(bounds!.x)
      expect(value!.x + value!.width).toBeLessThanOrEqual(bounds!.x + bounds!.width + 1)
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  }
  await page.screenshot({ path: testInfo.outputPath('readiness-dashboard-desktop-after.png'), fullPage: true })
})

test('readiness access denial is explained and stops automatic retry', async ({ page }) => {
  await page.clock.install()
  let requests = 0
  await page.route('**/api/v1/admin/readiness', async route => {
    requests += 1
    await route.fulfill({ status: 403, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/readiness/Panel.vue')

  await expect(page.getByRole('alert')).toHaveText('Нет доступа к этому разделу.')
  const refresh = page.locator('section[aria-labelledby="readiness-title"] > button')
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Обновление недоступно')
  await page.clock.fastForward(5_000)
  expect(requests).toBe(1)
})

test('mobile role warning can scroll fully above the persistent save actions', async ({ page }, testInfo) => {
  const memberPermissions = {
    'channel.text.create': false, 'channel.text.delete': false,
    'channel.voice.create': false, 'channel.voice.delete': false,
    'category.create': false, 'category.delete': false,
  }
  const adminPermissions = Object.fromEntries(Object.keys(memberPermissions).map(key => [key, true]))
  await page.route('**/api/v1/admin/roles**', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ revision: 7, roles: [
      { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions: adminPermissions },
      { role: 'MEMBER', display_name: 'Пользователь', editable: true, permissions: memberPermissions },
    ] }),
  }))
  await page.setViewportSize({ width: 393, height: 852 })
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1, section: 'roles' }, 'workspace-main-panel workspace-main-panel--admin')

  const warning = page.locator('.role-permission-notice')
  const actions = page.locator('.role-policy-actions')
  await expect(warning).toBeVisible()
  await warning.scrollIntoViewIfNeeded()
  const warningBounds = await warning.boundingBox()
  const actionBounds = await actions.boundingBox()
  expect(warningBounds).not.toBeNull()
  expect(actionBounds).not.toBeNull()
  expect(warningBounds!.y + warningBounds!.height).toBeLessThanOrEqual(actionBounds!.y + 1)
  await expectAxeClear(page, '.admin-panel')
  await page.screenshot({ path: testInfo.outputPath('mobile-role-warning-above-save-actions-after.png'), fullPage: true })
})

test('role mutation keeps its draft across 403/404/429/503 and reports one pending outcome', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  let reads = 0
  let writes = 0
  let saved = false
  let releaseFirst!: () => void
  let firstStarted!: () => void
  const firstWrite = new Promise<void>(resolve => { firstStarted = resolve })
  const memberPermissions = {
    'channel.text.create': false, 'channel.text.delete': false,
    'channel.voice.create': false, 'channel.voice.delete': false,
    'category.create': false, 'category.delete': false,
  }
  const adminPermissions = Object.fromEntries(Object.keys(memberPermissions).map(key => [key, true]))

  await page.route('**/api/v1/admin/roles**', async route => {
    if (route.request().method() === 'GET') {
      reads++
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({
        revision: 7,
        roles: [
          { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions: adminPermissions },
          { role: 'MEMBER', display_name: 'Пользователь', editable: true, permissions: { ...memberPermissions, 'channel.text.create': saved } },
        ],
      }) })
      return
    }

    writes++
    if (writes === 1) {
      firstStarted()
      await new Promise<void>(resolve => { releaseFirst = resolve })
      await route.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ error: { code: 'FORBIDDEN', message: 'fixture 403' } }) })
      return
    }
    const failures = [404, 429, 503]
    const status = failures[writes - 2]
    if (status) {
      await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ error: { code: `FIXTURE_${status}`, message: `fixture ${status}` } }) })
      return
    }
    if (writes === 5) {
      await route.abort('failed')
      return
    }
    saved = true
    await route.fulfill({ status: 204, body: '' })
  })

  await mountProductionComponent(page, '/src/admin/role_permissions/AdminRolePermissions.vue')
  const permission = page.getByRole('checkbox', { name: 'Создавать текстовые каналы' })
  const save = page.locator('.role-policy-actions button').last()
  await expect(permission).toBeVisible()
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('role-mutation-before.png'), fullPage: true })
  await permission.check()
  await save.click()
  await firstWrite
  await expect(save).toBeDisabled()
  await expect(page.getByRole('status')).toHaveText('Сохраняем…')
  expect(writes).toBe(1)
  releaseFirst()

  for (const status of [403, 404, 429, 503]) {
    await expect(page.getByRole('alert')).toHaveText(status === 403 ? 'Нет доступа к изменению разрешений этой роли.' : `fixture ${status}`)
    await expect(permission).toBeChecked()
    await expect(page.locator('.role-policy-status')).toHaveText('Есть несохранённые изменения')
    if (status === 403) {
      await expect(save).toBeDisabled()
      await page.getByRole('button', { name: 'Обновить' }).click()
      await expect(page.getByRole('alert')).toHaveCount(0)
      await expect(save).toBeEnabled()
    } else await expect(save).toBeEnabled()
    if (status === 503) await page.screenshot({ path: testInfo.outputPath('role-mutation-failure-503.png'), fullPage: true })
    expect(writes).toBe(status === 403 ? 1 : status === 404 ? 2 : status === 429 ? 3 : 4)
    expect(reads).toBe(2)
    if (status !== 503) await save.click()
  }

  await save.click()
  await expect(page.getByRole('alert')).toHaveText('Нет соединения с сервером. Проверьте подключение.')
  await expect(permission).toBeChecked()
  await expect(save).toBeEnabled()
  await page.screenshot({ path: testInfo.outputPath('role-mutation-offline.png'), fullPage: true })
  expect(reads).toBe(2)
  await save.click()
  await expect(page.locator('.admin-status')).toHaveText('Разрешения участников сохранены.')
  await expect(permission).toBeChecked()
  await expect(page.getByRole('alert')).toHaveCount(0)
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('role-mutation-after.png'), fullPage: true })
  expect(writes).toBe(6)
  expect(reads).toBe(3)
})

test('role 409 requires conflict review before a deliberate retry', async ({ page }, testInfo) => {
  let reads = 0
  let writes = 0
  let saved = false
  const permissions = {
    'channel.text.create': false, 'channel.text.delete': false,
    'channel.voice.create': false, 'channel.voice.delete': false,
    'category.create': false, 'category.delete': false,
  }
  const adminPermissions = Object.fromEntries(Object.keys(permissions).map(key => [key, true]))
  await page.route('**/api/v1/admin/roles**', async route => {
    if (route.request().method() === 'GET') {
      reads++
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ revision: reads, roles: [
        { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions: adminPermissions },
        { role: 'MEMBER', display_name: 'Пользователь', editable: true, permissions: { ...permissions, 'channel.text.create': saved } },
      ] }) })
      return
    }
    writes++
    if (writes === 1) {
      await route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ error: { code: 'PERMISSIONS_REVISION_CONFLICT', message: 'Настройки изменились.' } }) })
      return
    }
    saved = true
    await route.fulfill({ status: 204, body: '' })
  })

  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/role_permissions/AdminRolePermissions.vue')
  const permission = page.getByRole('checkbox', { name: 'Создавать текстовые каналы' })
  await permission.check()
  await page.locator('.role-policy-actions button').last().click()
  await expect(page.getByRole('alert')).toHaveText('Настройки уже изменены другим администратором. Черновик сохранён; обновите данные или отмените изменения.')
  const review = page.getByRole('region', { name: 'Сравнение конфликтующих изменений' })
  await expect(review).toBeVisible()
  await expect(review).toContainText('Ваше изменение')
  await expect(permission).toBeChecked()
  await expectAxeClear(page, '#mount')
  await page.screenshot({ path: testInfo.outputPath('role-conflict-review.png'), fullPage: true })
  expect(writes).toBe(1)
  expect(reads).toBe(2)

  await review.getByRole('button', { name: 'Проверено — применить моё изменение' }).click()
  await expect(page.locator('.admin-status')).toHaveText('Разрешения участников сохранены.')
  await expect(permission).toBeChecked()
  expect(writes).toBe(2)
  expect(reads).toBe(3)
  await page.screenshot({ path: testInfo.outputPath('role-conflict-after-review.png'), fullPage: true })
})

test('screen-share setup keeps keyboard focus inside its modal dialog', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/voice/ScreenShareSetupDialog.vue', { initialProfile: 'P1080_30', initialMode: 'text' })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const close = dialog.getByRole('button', { name: 'Закрыть' })
  const start = dialog.getByRole('button', { name: 'Начать трансляцию' })
  const selectedMode = dialog.getByRole('radio', { name: /Чёткость текста/ })
  const resolution = dialog.getByRole('radio', { name: '1080p' })
  await expect(close).toBeFocused()
  await selectedMode.focus()
  await page.keyboard.press('Tab')
  await expect(resolution).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(selectedMode).toBeFocused()
  await start.focus()
  await page.keyboard.press('Tab')
  await expect(close).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(start).toBeFocused()
})

test('WCAG smoke distinguishes media metric loading, refresh and failure states', async ({ page }, testInfo) => {
  let requests = 0
  let releaseInitial: (() => void) | undefined
  let releaseRefresh: (() => void) | undefined
  const sample = {
    sampled_at_utc: new Date().toISOString(),
    report: { platform: 'desktop_web', direction: 'sender', state: 'playing', encoded_fps: 30 },
  }
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    if (requests === 1) {
      await new Promise<void>(resolve => { releaseInitial = resolve })
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [sample] }) })
    } else if (requests === 2) {
      await new Promise<void>(resolve => { releaseRefresh = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: '{}' })
    } else {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [sample] }) })
    }
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const status = page.getByRole('status')
  await expect(status).toContainText('Загружаем показатели')
  releaseInitial?.()
  await expect(status).toContainText('Есть измерения')
  const sampleCard = page.locator('.admin-media-sample').first()
  await expect(sampleCard).toContainText('Воспроизводит')
  const details = sampleCard.locator('details')
  await expect(details).not.toHaveAttribute('open', '')
  await details.locator('summary').click()
  await expect(details).toHaveAttribute('open', '')
  await expectAxeClear(page, '.admin-media-freshness')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await refresh.click()
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Проверяем…')
  await expect(status).toContainText('Обновляем показатели; предыдущий ответ сохранён')
  releaseRefresh?.()
  await expect(status).toContainText('Ошибка обновления')
  await expect(page.getByRole('alert')).toContainText('Сервис временно не отвечает. Попробуйте позже.')
  await expect(page.getByRole('alert')).toContainText('Прежние измерения нельзя считать текущими')
  await expectAxeClear(page, '.admin-media-freshness')
  await page.screenshot({ path: testInfo.outputPath('media-stale-503-mobile-after.png'), fullPage: true })

  await refresh.click()
  await expect(status).toContainText('Есть измерения')
  await expect(page.getByRole('alert')).toHaveCount(0)
  await page.screenshot({ path: testInfo.outputPath('media-recovered-mobile-after.png'), fullPage: true })
})

test('media access denial stops automatic polling and disables retry', async ({ page }) => {
  await page.clock.install()
  let requests = 0
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    await route.fulfill({ status: 403, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await expect(page.getByRole('alert')).toHaveText('Нет доступа к этому разделу.')
  await expect(refresh).toBeDisabled()
  await page.clock.fastForward(15_000)
  expect(requests).toBe(1)
})

test('media rate limit remains retryable and recovers after a manual retry', async ({ page }) => {
  let requests = 0
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    if (requests === 1) await route.fulfill({ status: 429, contentType: 'application/json', body: '{}' })
    else await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [] }) })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await expect(page.getByRole('alert')).toHaveText('Слишком много запросов. Подождите немного и повторите попытку. Повторите обновление.')
  await expect(refresh).toBeEnabled()
  await refresh.click()
  await expect(page.getByRole('status')).toContainText('Нет данных')
  await expect(page.getByRole('alert')).toHaveCount(0)
  expect(requests).toBe(2)
})

test('admin media does not present old measurements as fresh after an empty refresh', async ({ page }) => {
  let requests = 0
  const oldSample = {
    sampled_at_utc: new Date(Date.now() - 120_000).toISOString(),
    report: { platform: 'android_native', direction: 'receiver', state: 'playing', frame_width: 540, frame_height: 1170 },
  }
  await page.route('**/api/v1/admin/screen-metrics', route => {
    requests += 1
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ samples: requests === 1 ? [oldSample] : [] }),
    })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const status = page.getByRole('status')
  await expect(status).toContainText('Данные устарели')
  await expect(status).toContainText('Свежих отчётов: 0')
  await expect(page.locator('.admin-media-sample')).toHaveCount(0)
  await expect(page.locator('.admin-media-stale')).toContainText('Последнее измерение')

  await page.locator('.admin-media-diagnostics > header > button').click()
  await expect(status).toContainText('Данные устарели')
  await expect(status).toContainText('Свежих отчётов: 0')
  await expect(page.locator('.admin-media-stale')).toContainText('Последнее измерение')
  await expect(page.locator('.admin-media-empty')).toHaveCount(0)
})

test('admin shell exposes all seven sections at 320–1440px and avoids page overflow', async ({ page }, testInfo) => {
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" style="display:flex;width:100%;height:100vh;flex-direction:column"><header class="settings-workspace-header"><strong>Администрирование</strong></header><div id="mount"></div></div>'
    const section = ref('members')
    const app = createApp({ render: () => h(AdminPanel, { categories: [], revision: 1, section: section.value, 'onUpdate:section': (next: string) => { section.value = next } }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const panelHeading = page.getByRole('heading', { name: 'Администрирование', exact: true })
  await expect(panelHeading).toBeAttached()
  expect(await panelHeading.evaluate(element => {
    const style = getComputedStyle(element.parentElement!.parentElement!)
    return { position: style.position, width: style.width, overflow: style.overflow, clip: style.clip }
  })).toEqual({ position: 'absolute', width: '1px', overflow: 'hidden', clip: 'rect(0px, 0px, 0px, 0px)' })
  await expect(page.getByRole('heading', { name: /Участники/ })).toBeVisible()

  const nav = page.getByRole('navigation', { name: 'Разделы администрирования' })
  const hint = page.getByText('Прокрутите список разделов по горизонтали', { exact: true })
  await expect(nav.getByRole('button', { name: 'Участники', exact: true })).toBeFocused()
  await expect(hint).toBeVisible()
  const dimensions = await nav.evaluate(element => ({ client: element.clientWidth, scroll: element.scrollWidth }))
  expect(dimensions.scroll).toBeGreaterThan(dimensions.client)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)

  const labels = ['Гильдия', 'Участники', 'Роли', 'Каналы', 'Аудит', 'Медиа', 'Готовность']
  if (testInfo.project.name === 'webkit') {
    // WebKit's default keyboard policy skips buttons unless macOS Full Keyboard Access is enabled.
    for (const label of labels) {
      const button = nav.getByRole('button', { name: label, exact: true })
      await button.focus()
      await expect(button).toBeFocused()
      await expect(button).toBeInViewport()
    }
  } else {
    const first = nav.getByRole('button', { name: labels[0], exact: true })
    await first.focus()
    for (const label of labels) {
      const button = nav.getByRole('button', { name: label, exact: true })
      await expect(button).toBeFocused()
      await expect(button).toBeInViewport()
      await page.keyboard.press('Tab')
    }
  }

  for (const label of labels) {
    const button = nav.getByRole('button', { name: label, exact: true })
    await button.click()
    await expect(button).toHaveAttribute('aria-current', 'page')
    await expect(button).toBeInViewport()
  }

  for (const width of [375, 390, 430, 600, 840, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    if (width <= 540) await expect(hint).toBeVisible()
    else await expect(hint).toBeHidden()
    const viewport = await nav.evaluate(element => ({ client: element.clientWidth, scroll: element.scrollWidth }))
    if (width <= 430) expect(viewport.scroll).toBeGreaterThan(viewport.client)
    else expect(viewport.scroll).toBeLessThanOrEqual(viewport.client)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    const panelBounds = await page.locator('.admin-panel').boundingBox()
    expect(panelBounds).not.toBeNull()
    expect(panelBounds!.width).toBeLessThanOrEqual(Math.min(width, 880))
    for (const label of labels) {
      const button = nav.getByRole('button', { name: label, exact: true })
      await button.click()
      await expect(button).toHaveAttribute('aria-current', 'page')
      await expect(button).toBeInViewport()
    }
  }
})

test('admin section selection survives closing and reopening its workspace panel', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" id="mount"></div>'
    const visible = ref(true)
    const section = ref('members')
    Object.assign(window, { __adminPanelState: {
      close: () => { visible.value = false },
      open: () => { visible.value = true },
    } })
    const app = createApp({ render: () => visible.value ? h(AdminPanel, {
      categories: [], revision: 1, section: section.value,
      'onUpdate:section': (next: string) => { section.value = next },
    }) : null })
    app.use(createPinia())
    app.mount('#mount')
  })

  const roles = page.getByRole('button', { name: 'Роли', exact: true })
  await roles.click()
  await expect(roles).toHaveAttribute('aria-current', 'page')
  await page.evaluate(() => (window as Window & { __adminPanelState: { close: () => void } }).__adminPanelState.close())
  await expect(page.getByTestId('admin-panel')).toHaveCount(0)
  await page.evaluate(() => (window as Window & { __adminPanelState: { open: () => void } }).__adminPanelState.open())
  await expect(page.getByRole('button', { name: 'Роли', exact: true })).toHaveAttribute('aria-current', 'page')
})

test('admin member filters survive switching to another admin section', async ({ page }) => {
  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{
      account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник',
      role: 'MEMBER', blocked: false, created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z',
    }] }),
  }))
  await page.route('**/api/v1/admin/audit?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ events: [] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" id="mount"></div>'
    const section = ref('members')
    const app = createApp({ render: () => h(AdminPanel, {
      categories: [], revision: 1, section: section.value,
      'onUpdate:section': (next: string) => { section.value = next },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const search = page.getByRole('searchbox', { name: 'Поиск участников' })
  await search.fill('участник')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Аудит', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Аудит', exact: true })).toBeVisible()
  await page.getByLabel('Область').selectOption('voice')
  await page.getByRole('button', { name: 'Участники', exact: true }).click()
  await expect(page.getByRole('searchbox', { name: 'Поиск участников' })).toHaveValue('участник')
  await page.getByRole('button', { name: 'Аудит', exact: true }).click()
  await expect(page.getByLabel('Область')).toHaveValue('voice')
})

test('admin audit filters expose result count, empty state and reset', async ({ page }) => {
  await page.route('**/api/v1/admin/audit?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ events: [{
      id: 'audit-event', event_type: 'CHANNEL_RENAMED', created_at: '2026-10-04T10:00:00Z',
    }] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/audit/AdminAuditSection.vue', {}, 'workspace-main-panel--admin')

  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const scope = page.getByLabel('Область')
  await scope.selectOption('voice')
  await expect(page.getByRole('button', { name: 'Сбросить фильтры' })).toBeVisible()
  await expect(page.getByText('Среди загруженных записей совпадений нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(scope).toHaveValue('all')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('Система → Канал переименован', { exact: true })).toBeVisible()
  await expectAxeClear(page, '.admin-audit')
})
