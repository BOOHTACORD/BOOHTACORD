import { test, expect } from '@playwright/test'
import { kinds, mount, row } from './helpers'
for (const kind of kinds) {
  test(`${kind} preserves actions ownership, draft, Shift+Enter and IME guard`, async ({ page }) => {
    const commands = await mount(page, kind)
    await row(page, 4).hover()
    await expect(row(page, 4).getByRole('button', { name: 'Ответить', exact: true })).toBeVisible()
    await expect(row(page, 4).getByRole('button', { name: 'Изменить', exact: true })).toHaveCount(0)
    await expect(row(page, 4).getByRole('button', { name: 'Удалить', exact: true })).toHaveCount(0)
    await row(page, 1).hover()
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
  test(`${kind} prepending older messages retains visible anchor`, async ({ page }) => {
    await mount(page, kind, true)
    const before = (await row(page, 1).boundingBox())!.y
    await page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true }).click()
    await expect(page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })).toHaveCount(0)
    await expect(row(page, 1)).toBeVisible()
    await expect.poll(async () => { const box=await row(page, 1).boundingBox(); return box?Math.abs(box.y-before):Infinity }).toBeLessThanOrEqual(2)
  })
}
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
