import { expect, type Page } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { historyPage, uid, wire } from './history_edit_data'

export async function setup(page: Page, count = 500, width = 1440, fullCapacity = false) {
  await page.setViewportSize({ width, height: 900 })
  const requests: { method: string; body: Record<string, unknown> | null }[] = []
  const state = { conflict: false, deleted: false, revision: 1, pending: null as null | Promise<void> }
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request(), url = new URL(request.url()), match = url.pathname.match(/\/channels\/([^/]+)\/messages(?:\/([^/]+))?$/)
    if (match && request.method() === 'PATCH') {
      const body = request.postDataJSON(); requests.push({ method: 'PATCH', body })
      if (state.pending) await state.pending
      if (state.conflict) { state.conflict = false; return route.fulfill({ status: 409, json: { error: { code: 'CONFLICT' } } }) }
      return route.fulfill({ json: { ...wire(Number(match[2]!.slice(-12)) - 1000, match[1], state.revision + 1), body: body.body } })
    }
    if (match && request.method() === 'GET') {
      const result = historyPage(url.searchParams.get('before'), url.searchParams.get('after'), count, match[1])
      result.messages = result.messages.map((message) => ({ ...message, revision: state.revision,
        ...(state.deleted && message.id === uid(1999) ? { deleted: true, body: '' } : {}) }))
      return route.fulfill({ json: result })
    }
    if (url.pathname.endsWith('/message-reactions')) return route.fulfill({ json: { reactions: [], can_pin: false } })
    if (url.pathname.includes('/members')) return route.fulfill({ json: { members: [] } })
    return route.fulfill({ json: {} })
  })
  await page.goto('/tests/chat_rhythm/history_edit.html' + (fullCapacity ? '?capacity=full' : ''))
  await page.waitForFunction(() => Boolean((window as any).historyEditFixture))
  await expect.poll(() => cacheSize(page)).toBe(count)
  return { state, requests }
}
export const editor = (page: Page) => page.getByRole('textbox', { name: 'Изменённый текст сообщения', exact: true })
export async function scrollToRow(page: Page, index = 999) {
  const row = page.locator(`[data-message-id="${uid(1000 + index)}"]`)
  const list = page.getByRole('log', { name: 'История сообщений' })
  await list.evaluate((element, target) => {
    const ids = (window as any).historyEditFixture.cache().map((id: string) => Number(id.slice(-12)) - 1000)
    const ratio = (target - Math.min(...ids)) / Math.max(1, Math.max(...ids) - Math.min(...ids))
    element.scrollTop = Math.max(0, ratio * element.scrollHeight - element.clientHeight / 2)
    element.dispatchEvent(new Event('scroll'))
  }, index)
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  await expect(row).toHaveCount(1)
  return row
}
export async function begin(page: Page, index = 999) {
  const row = await scrollToRow(page, index)
  await row.hover()
  const menu = row.getByRole('button', { name: 'Действия с сообщением' })
  if (await menu.isVisible()) await menu.click()
  await row.getByRole('button', { name: 'Изменить', exact: true }).click()
  await expect(editor(page)).toBeFocused()
  return editor(page)
}
export async function older(page: Page) {
  const button = page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })
  await button.click(); await expect.poll(() => page.evaluate(() => (window as any).historyEditFixture.busy())).toBe(false)
}
export async function newer(page: Page) {
  const button = page.getByRole('button', { name: 'Показать следующие сообщения', exact: true })
  await button.click(); await expect.poll(() => page.evaluate(() => (window as any).historyEditFixture.busy())).toBe(false)
}
export const cacheSize = (page: Page) => page.evaluate(() => (window as any).historyEditFixture.cache().length)
export const cacheHas = (page: Page, index: number) => page.evaluate((id) => (window as any).historyEditFixture.cache().includes(id), uid(1000 + index))
export const geometry = (page: Page) => page.getByRole('log', { name: 'История сообщений' }).evaluate((list) => ({
  rows: list.querySelectorAll('[data-message-id], [data-retained-message-id]').length,
  detached: list.querySelectorAll('[data-retained-message-id]').length,
  scrollWidth: list.scrollWidth, clientWidth: list.clientWidth, scrollHeight: list.scrollHeight,
}))
export async function roundtrip(page: Page) { await older(page); for (let i = 0; i < 3; i++) await newer(page) }
export async function capture(page: Page, name: string) {
  const destination = process.env.BOOHTACORD_QA141_CAPTURE_DIR
  if (!destination) return
  await mkdir(destination, { recursive: true })
  await page.evaluate(() => document.fonts.ready)
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  await page.screenshot({ path: join(destination, `${name}.png`) })
}
