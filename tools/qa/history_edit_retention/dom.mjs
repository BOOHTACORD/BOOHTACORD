import { expect } from '../client_lifecycle/request.mjs'

export const settle = page => page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
export const editor = page => page.getByRole('textbox', { name: 'Изменённый текст сообщения', exact: true })
export async function historyState(page) {
  return page.evaluate(() => {
    const store = document.querySelector('#app').__vue_app__.config.globalProperties.$pinia._s.get('text-messages')
    const list = document.querySelector('[role="log"][aria-label="История сообщений"]')
    return { channel: store.channelId, count: store.messages.length, loaded: store.historyLoaded,
      older: Boolean(store.nextCursor), newer: Boolean(store.newerCursor),
      // The production store keeps newest first; expose chronological bounds.
      first: store.messages.at(-1)?.id, last: store.messages[0]?.id,
      rows: list.querySelectorAll('[data-message-id], [data-retained-message-id]').length,
      detached: list.querySelectorAll('[data-retained-message-id]').length }
  })
}
export async function pageOlder(page) {
  const control = page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })
  const before = (await historyState(page)).first
  await control.click()
  await expect.poll(async () => (await historyState(page)).first).not.toBe(before)
  await settle(page)
}
export async function pageNewer(page) {
  const control = page.getByRole('button', { name: 'Показать следующие сообщения', exact: true })
  const before = (await historyState(page)).last
  await control.click()
  await expect.poll(async () => (await historyState(page)).last).not.toBe(before)
  await settle(page)
}
export async function beginLatest(page) {
  const list = page.getByRole('log', { name: 'История сообщений' })
  await list.evaluate(element => { element.scrollTop = element.scrollHeight; element.dispatchEvent(new Event('scroll')) })
  await settle(page)
  const row = page.locator('[data-message-id="'+(await historyState(page)).last+'"]')
  await row.hover()
  const menu = row.getByRole('button', { name: 'Действия с сообщением', exact: true })
  if (await menu.isVisible()) await menu.click()
  await row.getByRole('button', { name: 'Изменить', exact: true }).click()
  await expect(editor(page)).toBeFocused()
  return row
}
