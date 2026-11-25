import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { api, status, login, channel, openNavigation, expect } from '../client_lifecycle/request.mjs'
import { qaImage } from '../../../clients/web/tests/protected_image_viewer/image.ts'
export { api, status, expect, login }
export const original = qaImage(2048, 1280)
export async function setup(admin, password, suffix) {
  const names = ['a', 'b'].map(name => `qa_viewer_${suffix}_${name}`)
  const accounts = []
  for (const name of names) {
    const result = await api(admin, '/auth/register', 'POST', { login: name, password })
    status(result, 201); accounts.push(result.body.id)
  }
  const category = await api(admin, '/admin/categories', 'POST', { name: 'Viewer'+suffix })
  status(category, 201)
  const created = await api(admin, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'Viewer'+suffix, kind: 'TEXT' })
  status(created, 201)
  return { names, accounts, channel: created.body.id, name: 'Viewer'+suffix }
}
export async function select(page, kind, fixture, peer = fixture.names[1]) {
  await openNavigation(page)
  if (kind === 'TEXT') {
    await page.getByRole('button', { name: 'Каналы', exact: true }).click()
    await channel(page, fixture.name)
  } else {
    await page.getByRole('button', { name: 'Личные', exact: true }).click()
    await page.locator('.direct-message-navigation .channel-button').filter({ hasText: peer }).click()
  }
}
export async function upload(page, prefix, name) {
  await page.locator(prefix.startsWith('/channels/') ? '#message-attachments' : '#dm-attachments')
    .setInputFiles({ name, mimeType: 'image/png', buffer: original })
  await expect(page.locator('.attachment-picker [data-upload-status="done"]')).toHaveCount(1)
  const pending = page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === '/api/v1'+prefix+'/messages')
  await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  const response = await pending; assert.equal(response.status(), 201)
  const sent = await response.json()
  const history = await api(page, prefix+'/messages?at='+sent.id+'&limit=20'); status(history, 200)
  return history.body.messages.find(message => message.id === sent.id)
}
export async function fileStatuses(page, prefix, attachment) {
  return page.evaluate(async ({ prefix, attachment }) => {
    const result = []
    for (const suffix of ['', '/preview']) {
      const response = await fetch('/api/v1'+prefix+'/attachments/'+attachment+suffix, { credentials: 'same-origin', cache: 'no-store' })
      result.push(response.status); await response.arrayBuffer()
    }
    return result
  }, { prefix, attachment })
}
export async function view(page, name, prefix, attachment, directory, capture, download = true) {
  const opener = page.getByRole('button', { name: 'Открыть изображение '+name, exact: true })
  await opener.click()
  const dialog = page.getByRole('dialog', { name: 'Просмотр изображения '+name, exact: true })
  const image = dialog.locator('img')
  await expect(image).toBeVisible()
  await expect.poll(() => image.evaluate(node => [node.naturalWidth, node.naturalHeight])).toEqual([1024, 640])
  await expect(dialog.getByRole('button', { name: 'Закрыть просмотр изображения' })).toBeFocused()
  const bounds = await image.boundingBox(), viewport = page.viewportSize()
  assert.ok(bounds && viewport && bounds.x >= 0 && bounds.y >= 0 && bounds.x+bounds.width <= viewport.width && bounds.y+bounds.height <= viewport.height)
  await image.evaluate(node => node.decode())
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  await page.screenshot({ path: directory+'/'+capture+'.png' })
  const link = dialog.getByRole('link', { name: 'Скачать', exact: true })
  await expect(link).toHaveAttribute('href', '/api/v1'+prefix+'/attachments/'+attachment)
  if (download) {
    const pending = page.waitForEvent('download'); await link.click(); const saved = await pending
    assert.equal(saved.suggestedFilename(), name)
    assert.deepEqual(await readFile(await saved.path()), original)
  }
  await page.keyboard.press('Escape'); await expect(dialog).not.toBeVisible(); await expect(opener).toBeFocused()
  return { opener, dialog }
}
