import { test, expect } from '@playwright/test'
import { kinds, mount, row } from './helpers'
import { uid } from './data'
for (const kind of kinds) for (const width of [320, 390, 768, 1024, 1440, 1920, 3440]) {
  test(`${kind} preserves actions ownership, draft, Shift+Enter and IME guard at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    const commands = await mount(page, kind)
    async function revealActions(message: number) {
      if (width <= 600) {
        const toggle = row(page, message).getByRole('button', { name: 'Действия с сообщением', exact: true })
        expect((await toggle.boundingBox())!.height).toBeGreaterThanOrEqual(44)
        await toggle.focus()
        await toggle.press('Enter')
        await expect(toggle).toHaveAttribute('aria-expanded', 'true')
      } else {
        await row(page, message).hover()
      }
    }
    await revealActions(4)
    await expect(row(page, 4).getByRole('button', { name: 'Ответить', exact: true })).toBeVisible()
    await expect(row(page, 4).getByRole('button', { name: 'Изменить', exact: true })).toHaveCount(0)
    await expect(row(page, 4).getByRole('button', { name: 'Удалить', exact: true })).toHaveCount(0)
    await revealActions(1)
    await row(page, 1).getByRole('button', { name: 'Изменить', exact: true }).click()
    await expect(row(page, 1).getByRole('textbox', { name: 'Изменённый текст сообщения' })).toHaveValue('Начало разговора.')
    await row(page, 1).getByRole('button', { name: 'Отмена', exact: true }).click()
    const input = page.getByRole('textbox', { name: 'Сообщение', exact: true })
    await input.fill('Черновик до перезагрузки')
    await input.press('Shift+Enter')
    await input.pressSequentially('Вторая строка')
    await expect(input).toHaveValue('Черновик до перезагрузки\nВторая строка')
    await input.dispatchEvent('keydown', { key: 'Enter', code: 'Enter', isComposing: true, keyCode: 229, bubbles: true })
    expect(commands.filter(c => c.method === 'POST' && c.path.endsWith('/messages'))).toHaveLength(0)
    await page.evaluate(() => (window as any).rhythmFixture.remount())
    await expect(input).toHaveValue('Черновик до перезагрузки\nВторая строка')
    await input.press('Enter')
    await expect(input).toHaveValue('')
    expect(commands.filter(c => c.method === 'POST' && c.path.endsWith('/messages'))).toHaveLength(1)
  })
  test(`${kind} prepending older messages retains visible anchor at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await mount(page, kind, true)
    const before = (await row(page, 1).boundingBox())!.y
    await page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true }).click()
    await expect(page.getByRole('button', { name: /^(Показать предыдущие сообщения|Загружаем старые сообщения…)$/ })).toHaveCount(0)
    await expect(page.getByText('Загрузка реакций…', { exact: true })).toHaveCount(0)
    await expect(row(page, 1)).toBeVisible()
    try {
      await expect.poll(async () => { const box=await row(page, 1).boundingBox(); return box?Math.abs(box.y-before):Infinity }).toBeLessThanOrEqual(2)
    } catch (error) {
      const diagnostics = await page.evaluate(() => {
        const list = document.querySelector<HTMLElement>('.message-list')!
        const anchor = document.querySelector<HTMLElement>('[data-message-id="00000000-0000-4000-8000-000000000001"]')!
        return { scrollTop: list.scrollTop, scrollHeight: list.scrollHeight, clientHeight: list.clientHeight,
          overflowAnchor: getComputedStyle(list).overflowAnchor, anchorTop: anchor.getBoundingClientRect().top }
      })
      console.log(`HISTORY_ANCHOR_DIAGNOSTICS ${JSON.stringify({ before, ...diagnostics })}`)
      throw error
    }
  })
}
test('DIRECT_MESSAGE retains the reading anchor while an older-page loading label wraps', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 900 })
  await mount(page, 'DIRECT_MESSAGE', true)
  // Force wrapped feedback and late row shrink independently of platform font metrics.
  await page.addStyleTag({ content: '.message-list > .message-actions > button { width:120px; max-width:100%; padding-inline:0; font-family:monospace; line-height:26px; } .reaction-tools > [role="status"] { flex-basis:100%; }' })
  await page.locator('.message-list').evaluate(list => { list.scrollTop = 0 })
  const before = (await row(page, 1).boundingBox())!.y
  await page.screenshot({ path: info.outputPath('dm-pagination-before.png') })
  let release!: () => void
  const response = new Promise<void>(resolve => { release = resolve })
  let releaseReactions!: () => void
  const reactions = new Promise<void>(resolve => { releaseReactions = resolve })
  const olderIds = new Set(Array.from({ length: 25 }, (_, index) => uid(1000 + index)))
  await page.route('**/api/v1/**', async route => {
    const url = new URL(route.request().url())
    if (url.searchParams.has('before')) await response
    if (url.pathname.includes('/message-reactions') && url.searchParams.get('message_ids')?.split(',').some(id => olderIds.has(id))) await reactions
    await route.fallback()
  })
  try {
    await page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true }).click()
    await expect(page.getByRole('button', { name: 'Загружаем старые сообщения…', exact: true })).toBeDisabled()
    expect(Math.abs((await row(page, 1).boundingBox())!.y - before)).toBeLessThanOrEqual(2)
    await page.screenshot({ path: info.outputPath('dm-pagination-loading.png') })
    release()
    await expect(page.getByRole('button', { name: 'Загружаем старые сообщения…', exact: true })).toHaveCount(0)
    await expect(page.getByText('Загрузка реакций…', { exact: true })).toHaveCount(25)
    await expect.poll(async () => Math.abs((await row(page, 1).boundingBox())!.y - before)).toBeLessThanOrEqual(2)
    await page.screenshot({ path: info.outputPath('dm-pagination-reactions-pending.png') })
    releaseReactions()
    await expect(page.getByText('Загрузка реакций…', { exact: true })).toHaveCount(0)
    await expect.poll(async () => Math.abs((await row(page, 1).boundingBox())!.y - before)).toBeLessThanOrEqual(2)
    await page.screenshot({ path: info.outputPath('dm-pagination-after.png') })
    const history = page.locator('.message-list')
    await history.evaluate(list => { list.scrollTop += 250; list.dispatchEvent(new Event('scroll')) })
    const reading = await history.evaluate(list => {
      const top = list.getBoundingClientRect().top
      const item = [...list.querySelectorAll<HTMLElement>('[data-message-id]')].find(row => row.getBoundingClientRect().bottom > top)!
      return { id: item.dataset.messageId!, y: item.getBoundingClientRect().top }
    })
    expect(reading.id).not.toBe(uid(1))
    // Emulate an attachment above the user's new reading position expanding later.
    await history.evaluate(list => { list.querySelector<HTMLElement>('[data-message-id]')!.style.paddingBottom = '120px' })
    await expect.poll(async () => Math.abs((await page.locator(`[data-message-id="${reading.id}"]`).boundingBox())!.y - reading.y)).toBeLessThanOrEqual(2)
    await history.evaluate(list => { list.scrollTop = list.scrollHeight; list.dispatchEvent(new Event('scroll')) })
    await page.evaluate(() => (window as any).rhythmFixture.append())
    await expect(row(page, 8000)).toBeVisible()
    await expect(page.getByText('Загрузка реакций…', { exact: true })).toHaveCount(0)
    await expect.poll(() => history.evaluate(list => list.scrollHeight - list.clientHeight - list.scrollTop)).toBeLessThanOrEqual(2)
  } finally { release(); releaseReactions() }
})
test('TEXT keeps 1,000-message DOM bounded and new-message jump retains middle anchor', async ({ page }) => {
  await mount(page, 'CHANNEL')
  await page.evaluate(() => (window as any).rhythmFixture.replaceHistory(1000))
  const list = page.locator('.message-list')
  await expect(page.locator('.virtual-spacer')).not.toHaveCount(0)
  await list.evaluate(el => { el.scrollTop = el.scrollHeight / 2; el.dispatchEvent(new Event('scroll')) })
  const anchor = async () => list.evaluate(el => {
    const top = el.getBoundingClientRect().top
    const item = [...el.querySelectorAll<HTMLElement>('[data-message-id]')].find(r => r.getBoundingClientRect().top >= top)!
    return item ? { id: item.dataset.messageId, y: item.getBoundingClientRect().top } : null
  })
  await expect.poll(async () => page.locator('[data-message-id]').count()).toBeLessThan(80)
  await expect.poll(async () => Boolean((await anchor())?.id)).toBe(true)
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))))
  const before = (await anchor())!
  await page.evaluate(() => (window as any).rhythmFixture.append())
  await expect(page.getByRole('button', { name: 'К новым сообщениям (1)', exact: true })).toBeVisible()
  const after = (await anchor())!
  expect(after.id).toBe(before.id)
  expect(Math.abs(after.y - before.y)).toBeLessThanOrEqual(2)
  await page.getByRole('button', { name: 'К новым сообщениям (1)', exact: true }).click()
  await expect(row(page, 8000)).toBeVisible()
  await expect(page.getByRole('button', { name: /К новым сообщениям/ })).toHaveCount(0)
})
