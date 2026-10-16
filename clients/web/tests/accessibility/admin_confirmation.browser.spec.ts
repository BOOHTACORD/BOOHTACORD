import { expect, test } from '@playwright/test'
import { expectAxeClear } from './axe'

test.use({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 2 })

test('destructive confirmation is named, starts safely, traps focus, and Escape cancels', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, defineComponent, h, ref } = await import('/node_modules/.vite/deps/vue.js')
    const { default: AdminConfirmation } = await import('/src/channel/AdminConfirmation.vue')
    document.body.innerHTML = '<main><button id="trigger">Архивировать канал</button><div id="mount"></div></main>'
    const confirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
    Object.assign(window, { __confirmationState: { ask: (message: string) => confirmation.value?.ask(message) } })
    createApp(defineComponent({ render: () => h(AdminConfirmation, {
      ref: confirmation,
      id: 'archive-confirm',
      title: 'Подтверждение архивации',
      confirmLabel: 'Архивировать канал',
    }) })).mount('#mount')
    document.querySelector<HTMLButtonElement>('#trigger')!.addEventListener('click', () => {
      void confirmation.value?.ask('Архивировать «Чат команды»? История сообщений сохранится, отправка будет отключена.')
    })
  })

  const trigger = page.getByRole('button', { name: 'Архивировать канал', exact: true })
  await trigger.click()
  const dialog = page.getByRole('dialog', { name: 'Подтверждение архивации' })
  const cancel = dialog.getByRole('button', { name: 'Отмена' })
  const destructive = dialog.getByRole('button', { name: 'Архивировать канал' })
  await expect(dialog).toBeVisible()
  await expect(dialog).toContainText('«Чат команды»')
  const dialogBounds = await dialog.boundingBox()
  const headingBounds = await dialog.getByRole('heading').boundingBox()
  expect(dialogBounds).not.toBeNull()
  expect(headingBounds).not.toBeNull()
  expect(headingBounds!.x).toBeGreaterThan(dialogBounds!.x + 12)
  await page.screenshot({ path: testInfo.outputPath('topology-destructive-confirmation.png') })
  await expectAxeClear(page, 'dialog')
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(destructive).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
})

test('screen-share setup remains scrollable and keeps the action reachable on a short phone viewport', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { default: ScreenShareSetupDialog } = await import('/src/voice/ScreenShareSetupDialog.vue')
    document.body.innerHTML = '<button id="trigger">Показать экран</button><div id="mount"></div>'
    const app = createApp({ render: () => h(ScreenShareSetupDialog, { initialProfile: 'P1080_30', onCancel: () => {}, onStart: () => {} }) })
    app.mount('#mount')
  })
  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const start = dialog.getByRole('button', { name: 'Начать трансляцию' })
  await expect(dialog).toBeVisible()
  await expect(start).toBeVisible()
  const bounds = await dialog.boundingBox()
  expect(bounds).not.toBeNull()
  expect(bounds!.x).toBeGreaterThanOrEqual(0)
  expect(bounds!.y).toBeGreaterThanOrEqual(0)
  expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(320)
  expect(bounds!.y + bounds!.height).toBeLessThanOrEqual(568)
  await start.scrollIntoViewIfNeeded()
  await expect(start).toBeInViewport()
})

test('screen-share setup keeps its actions visible in a short desktop viewport', async ({ page }) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { default: ScreenShareSetupDialog } = await import('/src/voice/ScreenShareSetupDialog.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(ScreenShareSetupDialog, { initialProfile: 'P1080_30', onCancel: () => {}, onStart: () => {} }) }).mount('#mount')
  })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const body = dialog.locator('.screen-share-setup__body')
  const footer = dialog.locator('.screen-share-setup__footer')
  const start = dialog.getByRole('button', { name: 'Начать трансляцию' })
  await expect(dialog).toBeVisible()
  await expect(body).toHaveCSS('overflow-y', 'auto')
  await expect(footer).toBeInViewport({ ratio: 0.99 })
  await expect(start).toBeInViewport({ ratio: 0.99 })
  expect(await body.evaluate(element => element.scrollHeight)).toBeGreaterThan(await body.evaluate(element => element.clientHeight))
})

const screenShareSetups = [
  { name: '393x852 phone', width: 393, height: 852, textScale: 1 },
  { name: '320x640 compact phone', width: 320, height: 640, textScale: 1 },
  { name: '844x390 landscape', width: 844, height: 390, textScale: 1 },
  { name: '390x844 phone at 2x text', width: 390, height: 844, textScale: 2 },
] as const

for (const viewport of screenShareSetups) {
  test(`screen-share setup keeps start and cancel reachable at ${viewport.name}`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height })
    await page.goto('/')
    await page.evaluate(async (textScale) => {
      const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
      const { default: ScreenShareSetupDialog } = await import('/src/voice/ScreenShareSetupDialog.vue')
      document.body.innerHTML = '<button id="trigger">Показать экран</button><div id="mount"></div>'
      if (textScale !== 1) document.documentElement.style.fontSize = `${16 * textScale}px`
      createApp({ render: () => h(ScreenShareSetupDialog, {
        initialProfile: 'P1080_30', onCancel: () => {}, onStart: () => {},
      }) }).mount('#mount')
    }, viewport.textScale)

    const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
    const start = dialog.getByRole('button', { name: 'Начать трансляцию' })
    const cancel = dialog.getByRole('button', { name: 'Отмена' })
    await expect(dialog).toBeVisible()
    await expect(dialog).toContainText('Источник выберете в окне браузера.')
    await page.screenshot({ path: testInfo.outputPath('screen-share-setup-open.png') })

    for (const control of [start, cancel]) {
      await control.scrollIntoViewIfNeeded()
      await expect(control).toBeInViewport({ ratio: 0.99 })
      await expect(control).toBeEnabled()
    }
    await page.screenshot({ path: testInfo.outputPath('screen-share-setup-actions.png') })
  })
}

test('a stale channel confirmation never submits a mutation for a refreshed target', async ({ page }) => {
  let mutationRequests = 0
  await page.route('**/api/v1/**', async route => {
    if (route.request().method() !== 'GET') mutationRequests++
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h, ref } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: ChannelTopologyActions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const topology = ref({
      revision: 7,
      categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [{
        id: 'channel-1', name: 'Чат команды', kind: 'TEXT', position: 0, admissionClosed: false,
      }] }],
    })
    Object.assign(window, { __topologyState: { removeTarget: () => { topology.value = { revision: 8, categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [] }] } } } })
    const app = createApp({ render: () => h(ChannelTopologyActions, {
      accountId: 'account-1', topology: topology.value, voicePresence: null,
      permissions: {
        'channel.text.create': false, 'channel.text.delete': true,
        'channel.voice.create': false, 'channel.voice.delete': false,
        'category.create': false, 'category.delete': false,
      },
      onChanged: () => {},
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Действия с каналом Чат команды' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтвердите действие' })
  await expect(dialog).toContainText('Архивировать «Чат команды»?')
  await page.evaluate(() => (window as Window & { __topologyState: { removeTarget: () => void } }).__topologyState.removeTarget())

  await expect(dialog).toBeHidden()
  await expect(page.getByRole('alert')).toContainText('Структура изменилась')
  expect(mutationRequests).toBe(0)
})

test('an account change closes a pending destructive confirmation without mutation', async ({ page }) => {
  let mutationRequests = 0
  await page.route('**/api/v1/**', async route => {
    if (route.request().method() !== 'GET') mutationRequests++
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h, ref } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: ChannelTopologyActions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const accountId = ref('account-1')
    const topology = { revision: 7, categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [{
      id: 'channel-1', name: 'Чат команды', kind: 'TEXT', position: 0, admissionClosed: false,
    }] }] }
    let nextAccount = 2
    Object.assign(window, { __accountState: { change: () => { accountId.value = `account-${nextAccount++}` } } })
    const app = createApp({ render: () => h(ChannelTopologyActions, {
      accountId: accountId.value, topology, voicePresence: null,
      permissions: {
        'channel.text.create': false, 'channel.text.delete': true,
        'channel.voice.create': false, 'channel.voice.delete': false,
        'category.create': true, 'category.delete': false,
      },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Действия с каналом Чат команды' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтвердите действие' })
  await expect(dialog).toBeVisible()
  await page.evaluate(() => (window as Window & { __accountState: { change: () => void } }).__accountState.change())

  await expect(dialog).toBeHidden()
  await expect(page.getByRole('alert')).toContainText('Учетная запись изменилась')

  await page.getByRole('button', { name: 'Создать раздел или канал' }).click()
  const createDialog = page.getByRole('dialog', { name: 'Создать раздел' })
  await expect(createDialog).toBeVisible()
  await page.evaluate(() => (window as Window & { __accountState: { change: () => void } }).__accountState.change())
  await expect(createDialog).toBeHidden()
  await expect(page.getByRole('alert')).toContainText('Учетная запись изменилась')
  expect(mutationRequests).toBe(0)
})

test('an admin TEXT archive confirmation closes when its account changes', async ({ page }) => {
  let mutationRequests = 0
  await page.route('**/api/v1/**', async route => {
    if (route.request().method() !== 'GET') mutationRequests++
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h, ref } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: AdminTextArchive } = await import('/src/channel/AdminTextArchive.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const state = ref({ accountId: 'account-1', revision: 7, categories: [{
      id: 'category-1', name: 'Общее', position: 0, channels: [{
        id: 'channel-1', name: 'Чат команды', kind: 'TEXT', position: 0, admissionClosed: false,
      }],
    }] })
    Object.assign(window, { __adminScope: { change: () => { state.value = { ...state.value, accountId: 'account-2' } } } })
    const app = createApp({ render: () => h(AdminTextArchive, state.value) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Архивировать канал' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтверждение архивации' })
  await expect(dialog).toBeVisible()
  await page.evaluate(() => (window as Window & { __adminScope: { change: () => void } }).__adminScope.change())

  await expect(dialog).toBeHidden()
  expect(mutationRequests).toBe(0)
})

test('an admin VOICE close confirmation closes when its target disappears', async ({ page }) => {
  let mutationRequests = 0
  await page.route('**/api/v1/**', async route => {
    if (route.request().method() !== 'GET') mutationRequests++
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h, ref } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: AdminVoiceClose } = await import('/src/channel/AdminVoiceClose.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const state = ref({ accountId: 'account-1', revision: 7, categories: [{
      id: 'category-1', name: 'Общее', position: 0, channels: [{
        id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false,
      }],
    }] })
    Object.assign(window, { __voiceTarget: { remove: () => { state.value = { ...state.value, revision: 8, categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [] }] } } } })
    const app = createApp({ render: () => h(AdminVoiceClose, state.value) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Закрыть вход' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтверждение закрытия' })
  await expect(dialog).toBeVisible()
  await page.evaluate(() => (window as Window & { __voiceTarget: { remove: () => void } }).__voiceTarget.remove())

  await expect(dialog).toBeHidden()
  expect(mutationRequests).toBe(0)
})

test('topology channel creation keeps its form and controls visible', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: ChannelTopologyActions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const app = createApp({ render: () => h(ChannelTopologyActions, {
      accountId: 'account-1', voicePresence: null,
      topology: { revision: 7, categories: [{ id: 'category-1', name: 'Общее', position: 0, channels: [] }] },
      permissions: {
        'channel.text.create': true, 'channel.text.delete': false,
        'channel.voice.create': true, 'channel.voice.delete': false,
        'category.create': true, 'category.delete': false,
      },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Создать канал в разделе Общее' }).click()
  const dialog = page.getByRole('dialog', { name: 'Создать канал' })
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('textbox', { name: 'Название канала' })).toBeFocused()
  await page.screenshot({ path: testInfo.outputPath('topology-create-channel.png') })
})

test('topology create ignores duplicate submits and preserves the draft across server errors', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  let requests = 0
  let releaseFirst!: () => void
  let firstStarted!: () => void
  const firstRequest = new Promise<void>(resolve => { firstStarted = resolve })
  await page.route('**/api/v1/categories', async route => {
    requests++
    if (requests === 1) {
      firstStarted()
      await new Promise<void>(resolve => { releaseFirst = resolve })
      await route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ error: { code: 'CONFLICT', message: 'Список каналов изменился.' } }) })
      return
    }
    if (requests === 2) {
      await route.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ error: { code: 'FORBIDDEN', message: 'Недостаточно прав для создания раздела.' } }) })
    } else if (requests === 3) {
      await route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ error: { code: 'SERVICE_UNAVAILABLE', message: 'Сервис временно недоступен.' } }) })
    } else {
      await route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({
        client_request_id: '11111111-1111-4111-8111-111111111111', topology_revision: 8,
        result: { resource_type: 'CATEGORY', resource_id: 'category-2', state: 'ACTIVE' },
      }) })
    }
  })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
    const { default: ChannelTopologyActions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const app = createApp({ render: () => h(ChannelTopologyActions, {
      accountId: 'account-1', voicePresence: null,
      topology: { revision: 7, categories: [] },
      permissions: {
        'channel.text.create': true, 'channel.text.delete': false,
        'channel.voice.create': true, 'channel.voice.delete': false,
        'category.create': true, 'category.delete': false,
      },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  await page.getByRole('button', { name: 'Создать раздел или канал' }).click()
  const dialog = page.getByRole('dialog', { name: 'Создать раздел' })
  const name = dialog.getByRole('textbox', { name: 'Название раздела' })
  await page.screenshot({ path: testInfo.outputPath('topology-create-section.png') })
  await name.fill('Новый раздел')
  await name.press('Enter')
  await firstRequest
  await dialog.evaluate(form => form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })))
  expect(requests).toBe(1)
  releaseFirst()
  await expect(dialog.getByRole('alert')).toContainText('Данные изменились. Обновите их перед повтором.')
  await expect(name).toHaveValue('Новый раздел')
  await page.screenshot({ path: testInfo.outputPath('topology-create-section-conflict-409.png') })

  await dialog.getByRole('button', { name: 'Создать раздел', exact: true }).click()
  await expect(dialog.getByRole('alert')).toContainText('Нет доступа к этому действию.')
  await expect(name).toHaveValue('Новый раздел')
  await dialog.getByRole('button', { name: 'Создать раздел', exact: true }).click()
  await expect(dialog.getByRole('alert')).toContainText('Сервис временно не отвечает. Попробуйте позже.')
  await expect(name).toHaveValue('Новый раздел')
  await page.screenshot({ path: testInfo.outputPath('topology-create-section-error-503.png') })
  await dialog.getByRole('button', { name: 'Создать раздел', exact: true }).click()
  await expect(dialog).toBeHidden()
  expect(requests).toBe(4)
})
