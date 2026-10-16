import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { expect, test } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'

test('R02 keeps only the touched message action disclosure open', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const messages = [1, 2, 3].map((index) => ({
      id: `message-${index}`,
      channelId: 'channel-1',
      authorId: `user-${index}`,
      clientMessageId: `client-${index}`,
      body: `Сообщение ${index}`,
      createdAt: '2026-10-04T12:00:00Z',
      revision: 1,
      deleted: false,
    }))
    const app = createApp({ render: () => h('div', [
      h('div', { class: 'message-list' }, messages.map((message) =>
        h(MessageItem, { message, canEdit: false, canDelete: false,
          onReply: () => { document.body.dataset.replies = String(Number(document.body.dataset.replies ?? '0') + 1) },
        }))),
      h('button', { id: 'outside' }, 'Вне списка'),
    ]) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const rows = page.locator('.message-row')
  const firstToggle = rows.nth(0).locator('.message-actions-toggle')
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  await expect(firstToggle).toHaveCSS('opacity', '1')
  expect((await firstToggle.boundingBox())?.height).toBeGreaterThanOrEqual(44)
  await rows.nth(0).getByText('Сообщение 1').tap()
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)

  const firstBounds = await rows.nth(0).boundingBox()
  await rows.nth(0).dispatchEvent('pointerdown', {
    pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 80, clientY: (firstBounds?.y ?? 20) + 12,
  })
  await page.waitForTimeout(80)
  await rows.nth(0).dispatchEvent('pointermove', {
    pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 82, clientY: (firstBounds?.y ?? 20) + 42,
  })
  await page.waitForTimeout(550)
  await rows.nth(0).dispatchEvent('pointerup', { pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0 })
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)

  await rows.nth(0).dispatchEvent('pointerdown', {
    pointerType: 'touch', pointerId: 102, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 80, clientY: (firstBounds?.y ?? 20) + 12,
  })
  await page.waitForTimeout(550)
  await rows.nth(0).dispatchEvent('pointerup', { pointerType: 'touch', pointerId: 102, isPrimary: true, button: 0 })
  await expect(rows.nth(0).locator('.message-actions')).toHaveClass(/is-open/)
  expect((await rows.nth(0).getByRole('button', { name: 'Ответить' }).boundingBox())?.height).toBeGreaterThanOrEqual(44)
  await rows.nth(1).locator('.message-actions-toggle').tap()
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)
  await expect(rows.nth(1).locator('.message-actions')).toHaveClass(/is-open/)
  const captureDir = process.env.BOOHTACORD_VISUAL_CAPTURE_DIR
  if (captureDir) {
    await mkdir(captureDir, { recursive: true })
    await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-open-actual.png') })
  }
  await rows.nth(1).getByRole('button', { name: 'Ответить' }).tap()
  await expect(page.locator('body')).toHaveAttribute('data-replies', '1')
  await expect(rows.nth(1).locator('.message-actions-toggle')).toBeFocused()
  await rows.nth(2).locator('.message-actions-toggle').tap()
  await page.locator('#outside').tap()
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  if (captureDir) await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-closed-actual.png') })
})

test('R02 preserves touch actions and passes WCAG axe scan for grouped, system, deleted and failed messages', async ({ page }) => {
  await page.route(/message-reactions/, route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ reactions: [], can_pin: true }),
  }))
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const base = {
      channelId: '11111111-1111-4111-8111-111111111111',
      authorId: 'user-1',
      clientMessageId: 'client-1',
      body: 'Сообщение для проверки',
      createdAt: '2026-10-04T12:00:00Z',
      revision: 1,
      deleted: false,
    }
    const messages = [
      { ...base, id: '22222222-2222-4222-8222-222222222221' },
      { ...base, id: '22222222-2222-4222-8222-222222222222', kind: 'SYSTEM_WELCOME' },
      { ...base, id: '22222222-2222-4222-8222-222222222223', deleted: true },
      { ...base, id: '22222222-2222-4222-8222-222222222224', sendStatus: 'failed', retryBlocked: false },
    ]
    const app = createApp({ render: () => h('div', { class: 'message-list' }, messages.map((message, index) =>
      h(MessageItem, { message, grouped: index === 0, canEdit: false, canDelete: index === 1,
        retryDisabled: false,
        onReply: () => {}, onRetry: () => {}, onRemove: () => {},
      }))) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const rows = page.locator('.message-row')
  const grouped = rows.filter({ has: page.getByText('Сообщение для проверки') }).first()
  const groupedButton = grouped.locator('.message-actions-toggle')
  await expect(groupedButton).toBeVisible()
  expect((await groupedButton.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  const reactionGroup = grouped.getByRole('group', { name: 'Реакции на сообщение' })
  await reactionGroup.locator('summary').click()
  const reactions = reactionGroup.getByRole('button', { name: /^Реакция / })
  await expect(reactions).toHaveCount(6)
  for (const button of await reactions.all()) {
    const bounds = await button.boundingBox()
    expect(bounds?.width).toBeGreaterThanOrEqual(44)
    expect(bounds?.height).toBeGreaterThanOrEqual(44)
  }
  const pin = reactionGroup.getByRole('button', { name: 'Закрепить сообщение' })
  await expect(pin).toBeVisible()
  const pinBounds = await pin.boundingBox()
  expect(pinBounds?.width).toBeGreaterThanOrEqual(44)
  expect(pinBounds?.height).toBeGreaterThanOrEqual(44)

  const captureDir = process.env.BOOHTACORD_VISUAL_CAPTURE_DIR
  if (captureDir) {
    await mkdir(captureDir, { recursive: true })
    await grouped.screenshot({ path: join(captureDir, 'message-social-touch-targets.png') })
  }

  const systemDelete = page.getByRole('button', { name: 'Удалить системное приветствие' })
  await expect(systemDelete).toBeVisible()
  expect((await systemDelete.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  const deleted = rows.filter({ hasText: 'Сообщение удалено' })
  await expect(deleted.locator('.message-actions-toggle')).toHaveCount(0)

  const failed = rows.filter({ hasText: 'Не отправлено' })
  const retry = failed.getByRole('button', { name: 'Повторить отправку' })
  await expect(retry).toBeVisible()
  await expect(failed.locator('.message-actions-toggle')).toHaveCount(0)
  expect((await retry.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  await expectAxeClear(page, '.message-list')
})

test('R02 requires explicit confirmation before a message can be deleted', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    document.body.dataset.removeCount = '0'
    const message = {
      id: 'delete-confirmation-message',
      channelId: 'channel-1',
      authorId: 'user-1',
      clientMessageId: 'client-1',
      body: 'Сообщение перед удалением',
      createdAt: '2026-10-04T12:00:00Z',
      revision: 1,
      deleted: false,
    }
    const app = createApp({ render: () => h(MessageItem, {
      message,
      canEdit: true,
      canDelete: true,
      onRemove: () => { document.body.dataset.removeCount = String(Number(document.body.dataset.removeCount ?? '0') + 1) },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const row = page.locator('.message-row')
  await row.locator('.message-actions-toggle').tap()
  await expect(row.locator('.message-actions')).toHaveClass(/is-open/)
  const captureDir = process.env.BOOHTACORD_VISUAL_CAPTURE_DIR
  if (captureDir) {
    await mkdir(captureDir, { recursive: true })
    await row.screenshot({ path: join(captureDir, 'message-actions-all-open-actual.png') })
  }
  let confirmationMessage = ''
  page.once('dialog', async (dialog) => {
    confirmationMessage = dialog.message()
    await dialog.dismiss()
  })
  await row.getByRole('button', { name: 'Удалить' }).tap()
  expect(confirmationMessage).toBe('Удалить это сообщение?')
  await expect(page.locator('body')).toHaveAttribute('data-remove-count', '0')
  await expect(row.locator('.message-actions-toggle')).toBeVisible()
})
