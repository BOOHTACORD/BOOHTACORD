import { expect, test } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'

const longName = 'ОченьДлинноеИмяУчастникаБезПробелов'.repeat(3)
const candidates = Array.from({ length: 30 }, (_, i) => ({ id: `peer-${i}`, display_name: i ? `Участник ${i}` : longName }))

test.beforeEach(async ({ page }) => {
  await page.route('**/api/v1/members?**', r => r.fulfill({ json: { members: [] } }))
  await page.route('**/api/v1/direct-message-candidates*', r => r.fulfill({ json: { candidates } }))
})

for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) {
  for (const scale of [1, 2]) {
    test(`modal escapes clipped sidebar at ${width}px / ${scale * 100}% text`, async ({ page }, info) => {
      await page.setViewportSize({ width, height: 900 })
      await page.goto('/tests/dm_starter/fixture.html')
      await page.evaluate(scale => { document.documentElement.style.fontSize = `${16 * scale}px` }, scale)
      const trigger = page.getByRole('button', { name: 'Начать диалог', exact: true })
      await trigger.click()
      const dialog = page.getByRole('dialog', { name: 'Новый личный диалог', exact: true })
      await expect(dialog.getByRole('button', { name: longName, exact: true })).toBeVisible()
      await page.screenshot({ path: info.outputPath('dm-starter.png') })
      expect(await dialog.evaluate(e => e.matches(':modal'))).toBe(true)
      const bounds = (await dialog.boundingBox())!
      expect(bounds.x).toBeGreaterThanOrEqual(0)
      expect(bounds.x + bounds.width).toBeLessThanOrEqual(width)
      expect(bounds.y).toBeGreaterThanOrEqual(0)
      expect(bounds.y + bounds.height).toBeLessThanOrEqual(900)
      expect(await dialog.evaluate(e => e.scrollWidth - e.clientWidth)).toBeLessThanOrEqual(1)
      const name = dialog.getByRole('button', { name: longName, exact: true })
      expect(await name.evaluate(e => e.scrollWidth - e.clientWidth)).toBeLessThanOrEqual(1)
      expect(await name.evaluate(e => e.scrollHeight - e.clientHeight)).toBeLessThanOrEqual(1)
      expect(await name.evaluate(e => {
        const range = document.createRange(); range.selectNodeContents(e)
        const text = range.getBoundingClientRect(), box = e.getBoundingClientRect()
        return text.top >= box.top && text.bottom <= box.bottom
      })).toBe(true)
      await expect(dialog.getByRole('button', { name: 'Закрыть выбор участника' })).toBeFocused()
      await page.keyboard.press('Shift+Tab')
      await expect(dialog.getByRole('button', { name: 'Участник 29', exact: true })).toBeFocused()
      await expect(dialog.getByRole('button', { name: 'Участник 29', exact: true })).toBeInViewport()
      await page.keyboard.press('Tab')
      await expect(dialog.getByRole('button', { name: 'Закрыть выбор участника' })).toBeFocused()
      await page.keyboard.press('Escape')
      await expect(dialog).not.toBeVisible()
      await expect(trigger).toBeFocused()
      await expect(page.getByLabel('Active DM')).toHaveText('existing-dm')
      await expect(page.getByLabel('Draft')).toHaveValue('Unsaved draft')
      await trigger.click()
      await page.mouse.click(2, 2)
      await expect(dialog).not.toBeVisible()
      await expect(trigger).toBeFocused()
    })
  }
}

test('loading, failed refresh, retry, pagination and one DM selection stay usable', async ({ page }) => {
  let reads = 0, opens = 0
  await page.route('**/api/v1/direct-message-candidates*', async r => {
    reads++
    if (reads === 1) return r.fulfill({ status: 503, json: {} })
    return r.fulfill({ json: reads === 2 ? { candidates: [candidates[0]], next_after: 'next' } : { candidates: [candidates[1]] } })
  })
  await page.route('**/api/v1/direct-messages', async r => {
    opens++
    expect(r.request().postDataJSON()).toEqual({ participant_id: 'peer-1' })
    await new Promise(resolve => setTimeout(resolve, 150))
    return r.fulfill({ json: { id: 'new-dm', participant_one_id: 'self', participant_two_id: 'peer-1', created_at: '2026-10-15T12:00:00Z' } })
  })
  await page.goto('/tests/dm_starter/fixture.html')
  await page.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByRole('alert')).toBeVisible()
  await dialog.getByRole('button', { name: 'Обновить список', exact: true }).click()
  await expect(dialog.getByRole('button', { name: longName, exact: true })).toBeVisible()
  await dialog.getByRole('button', { name: 'Загрузить ещё', exact: true }).click()
  await expect(dialog.getByRole('button', { name: longName, exact: true })).toBeVisible()
  const choose = dialog.getByRole('button', { name: 'Участник 1', exact: true })
  await choose.dblclick()
  await expect(page.getByLabel('Active DM')).toHaveText('new-dm')
  expect(opens).toBe(1)
  await expect(dialog).not.toBeVisible()
  await expect(page.getByLabel('Draft')).toHaveValue('Unsaved draft')
})

test('loading and empty candidates keep a reachable close action', async ({ page }) => {
  let release!: () => void
  const ready = new Promise<void>(resolve => { release = resolve })
  await page.route('**/api/v1/direct-message-candidates*', async r => {
    await ready
    return r.fulfill({ json: { candidates: [] } })
  })
  try {
    await page.goto('/tests/dm_starter/fixture.html')
    await page.getByRole('button', { name: 'Начать диалог', exact: true }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Загружаем участников…', { exact: true })).toBeVisible()
    await expect(dialog.getByRole('button', { name: 'Закрыть выбор участника' })).toBeEnabled()
    release()
    await expect(dialog.getByText('Нет доступных участников.', { exact: true })).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(dialog).not.toBeVisible()
  } finally { release() }
})

test('DM picker modal passes accessibility rules with populated candidates', async ({ page }) => {
  await page.goto('/tests/dm_starter/fixture.html')
  await page.getByRole('button', { name: 'Начать диалог', exact: true }).click()
  await expect(page.getByRole('dialog').getByRole('button', { name: longName, exact: true })).toBeVisible()
  await expectAxeClear(page)
})

test('cancelling a pending selection ignores its late completion', async ({ page }) => {
  let release!: () => void
  const ready = new Promise<void>(resolve => { release = resolve })
  let requested = false
  await page.route('**/api/v1/direct-messages', async r => {
    requested = true
    await ready
    return r.fulfill({ json: { id: 'late-dm', participant_one_id: 'self', participant_two_id: 'peer-0', created_at: '2026-10-15T12:00:00Z' } })
  })
  try {
    await page.goto('/tests/dm_starter/fixture.html')
    const trigger = page.getByRole('button', { name: 'Начать диалог', exact: true })
    await trigger.click()
    await page.getByRole('dialog').getByRole('button', { name: longName, exact: true }).click()
    await expect.poll(() => requested).toBe(true)
    await page.keyboard.press('Escape')
    const completed = page.waitForResponse(r => r.url().endsWith('/api/v1/direct-messages'))
    release()
    await completed
    await trigger.click()
    await expect(page.getByRole('dialog').getByRole('button', { name: longName, exact: true })).toBeEnabled()
    await expect(page.getByLabel('Active DM')).toHaveText('existing-dm')
    await expect(page.getByLabel('Draft')).toHaveValue('Unsaved draft')
  } finally { release() }
})

for (const width of [320, 390]) test(`touch opens a bounded DM picker and selects one candidate at ${width}px`, async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
  try {
    const page = await context.newPage()
    await page.route('**/api/v1/members?**', r => r.fulfill({ json: { members: [] } }))
    await page.route('**/api/v1/direct-message-candidates*', r => r.fulfill({ json: { candidates } }))
    await page.route('**/api/v1/direct-messages', r => r.fulfill({ json: { id: 'touch-dm', participant_one_id: 'self', participant_two_id: 'peer-1', created_at: '2026-10-15T12:00:00Z' } }))
    await page.goto('/tests/dm_starter/fixture.html')
    const trigger = page.getByRole('button', { name: 'Начать диалог', exact: true })
    expect((await trigger.boundingBox())!.height).toBeGreaterThanOrEqual(44)
    await trigger.tap()
    const dialog = page.getByRole('dialog', { name: 'Новый личный диалог', exact: true })
    const candidate = dialog.getByRole('button', { name: 'Участник 1', exact: true })
    await expect(candidate).toBeVisible()
    const bounds = (await dialog.boundingBox())!
    expect(bounds.x).toBeGreaterThanOrEqual(0)
    expect(bounds.x + bounds.width).toBeLessThanOrEqual(width)
    expect(await dialog.evaluate(element => element.scrollWidth - element.clientWidth)).toBeLessThanOrEqual(1)
    expect((await candidate.boundingBox())!.height).toBeGreaterThanOrEqual(44)
    await candidate.tap()
    await expect(page.getByLabel('Active DM')).toHaveText('touch-dm')
    await expect(dialog).not.toBeVisible()
    await expect(page.getByLabel('Draft')).toHaveValue('Unsaved draft')
  } finally {
    await context.close()
  }
})
