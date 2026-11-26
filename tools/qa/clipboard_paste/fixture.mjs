import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { existsSync, writeFileSync, renameSync } from 'node:fs'
import { setTimeout as delay } from 'node:timers/promises'
import { api, status, channel, expect } from '../client_lifecycle/request.mjs'
import { qaImage } from '../../../clients/web/tests/protected_image_viewer/image.ts'
export { api, status, channel, expect }
export async function signal(input, name, body = {}) {
  writeFileSync(input.private+'/'+name+'.tmp', JSON.stringify(body), { mode: 0o600 })
  renameSync(input.private+'/'+name+'.tmp', input.private+'/'+name+'.json')
  const deadline = Date.now()+20000
  while (!existsSync(input.private+'/'+name+'.ready')) {
    if (Date.now() > deadline) throw Error('Owned fixture phase did not become ready')
    await delay(50)
  }
}
export async function setup(admin, password, width) {
  const name = 'qa_clipboard_'+width
  status(await api(admin, '/auth/register', 'POST', { login: name, password }), 201)
  const category = await api(admin, '/admin/categories', 'POST', { name: 'Clipboard'+width }); status(category, 201)
  const ids = []
  for (const suffix of ['A', 'B']) {
    const c = await api(admin, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'Clipboard'+width+suffix, kind: 'TEXT' })
    status(c, 201); ids.push(c.body.id)
  }
  return { name, a: ids[0], b: ids[1], aName: 'Clipboard'+width+'A', bName: 'Clipboard'+width+'B' }
}
export async function observeClipboard(page) {
  await page.evaluate(() => {
    window.pastedImage = null
    document.addEventListener('paste', event => {
      const image = [...(event.clipboardData?.files ?? [])].find(file => file.type.startsWith('image/'))
      if (image) window.pastedImage = image.arrayBuffer().then(async bytes => ({ trusted: event.isTrusted,
        hash: [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(v => v.toString(16).padStart(2, '0')).join('') }))
    }, { capture: true })
  })
}
export async function clipboard(page, text, image = true, noise = false) {
  await page.bringToFront()
  await page.evaluate(async ({ text, image, noise, png }) => {
    const parts = {}
    if (text) parts['text/plain'] = new Blob([text], { type: 'text/plain' })
    if (image) {
      let blob = new Blob([Uint8Array.from(atob(png), c => c.charCodeAt(0))], { type: 'image/png' })
      if (noise) {
        const canvas = document.createElement('canvas'); canvas.width = canvas.height = 512
        const context = canvas.getContext('2d'), pixels = context.createImageData(512, 512)
        let seed = 17
        for (let i = 0; i < pixels.data.length; i++) { seed = (seed*1664525+1013904223) >>> 0; pixels.data[i] = i%4 === 3 ? 255 : seed >>> 24 }
        context.putImageData(pixels, 0, 0); blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
      }
      parts['image/png'] = blob
    }
    await navigator.clipboard.write([new ClipboardItem(parts)])
  }, { text, image, noise, png: qaImage().toString('base64') })
}
export async function paste(page, selector = '#message-body') {
  await page.locator(selector).focus(); await page.keyboard.press('Control+V')
}
export async function capture(page, directory, name, selector = '#message-body') {
  await page.evaluate(async () => { await document.fonts.ready; await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))) })
  const field = page.locator(selector)
  const bounds = await field.boundingBox(), viewport = page.viewportSize()
  assert.ok(bounds && bounds.width >= 96 && bounds.x >= 0 && bounds.x+bounds.width <= viewport.width && bounds.y+bounds.height <= viewport.height)
  await page.screenshot({ path: directory+'/'+name+'.png' })
}
export async function send(page, prefix, selector = '#message-body') {
  const observation = await page.evaluate(() => window.pastedImage); assert.equal(observation.trusted, true)
  const pending = page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === '/api/v1'+prefix+'/messages')
  await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  const response = await pending; assert.equal(response.status(), 201)
  const sent = await response.json(), history = await api(page, prefix+'/messages?at='+sent.id+'&limit=20'); status(history, 200)
  const confirmed = history.body.messages.find(m => m.id === sent.id); assert.equal(confirmed.attachments.length, 1)
  const row = page.locator(`[data-message-id="${sent.id}"]`), saving = page.waitForEvent('download')
  await row.locator('.attachment-card__download').click()
  assert.equal(createHash('sha256').update(await readFile(await (await saving).path())).digest('hex'), observation.hash)
  await expect(page.locator(selector)).toHaveValue('')
  return confirmed
}
