import { expect, test } from '@playwright/test'
import { mount, first, second } from '../dm_clipboard/helpers'
import { paste as clipboardPaste } from '../clipboard_paste/helpers'
import type { Page } from '@playwright/test'
const paste = (page: Page, text = '', count = 1, bytes?: number) => clipboardPaste(page, text, count, bytes, '#direct-message-body')

for (const width of [1440, 393, 320]) for (const scale of [1, 2]) test(`DM mixed paste keeps a visible draft and waits for Send at ${width}px scale${scale}`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  const state = await mount(page), input = page.locator('#direct-message-body')
  await page.evaluate(scale => { document.documentElement.style.fontSize = `${100*scale}%` }, scale)
  await input.fill('До OLD после'); await input.evaluate(node => node.setSelectionRange(3, 6))
  await paste(page, 'подпись')
  await expect(input).toHaveValue('До подпись после')
  await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
  expect(state.uploads).toEqual([{ path: `/api/v1/direct-messages/${first}/attachments`, imageBytes: true }])
  expect(state.sends).toHaveLength(0)
  await page.evaluate(() => document.fonts.ready)
  const rect = await input.boundingBox()
  await page.screenshot({ path: info.outputPath(`dm-clipboard-ready-${width}-${scale}.png`) })
  expect(rect?.width).toBeGreaterThanOrEqual(96)
  expect(await input.evaluate(node => document.elementFromPoint(node.getBoundingClientRect().x+10, node.getBoundingClientRect().y+10)?.tagName)).toBe('TEXTAREA')
  await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  await expect(input).toHaveValue(''); expect(state.sends).toHaveLength(1)
  expect(state.sends[0]).toMatchObject({ body: 'До подпись после', attachment_ids: [expect.any(String)] })
})

for (const width of [1440, 393]) for (const scale of [1, 2]) test(`DM explains507 and retains bytes for retry at ${width}px scale${scale}`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  const state = await mount(page); state.fail = true
  await page.evaluate(scale => { document.documentElement.style.fontSize = `${100*scale}%` }, scale)
  await paste(page, 'Черновик')
  await expect(page.locator('[data-upload-status="failed"]')).toHaveCount(1)
  await page.screenshot({ path: info.outputPath(`dm-clipboard-storage-full-${width}-${scale}.png`) })
  await expect(page.locator('.attachment-picker')).toContainText('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
  await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
  const input = await page.locator('#direct-message-body').boundingBox()
  expect(input?.width).toBeGreaterThanOrEqual(96); expect(input!.y+input!.height).toBeLessThanOrEqual(900)
  await expect(page.getByRole('button', { name: 'Повторить загрузку image.png', exact: true })).toBeInViewport()
  state.fail = false; await page.getByRole('button', { name: 'Повторить загрузку image.png', exact: true }).click()
  await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
  expect(state.uploads).toHaveLength(2); expect(state.uploads.every(upload => upload.imageBytes)).toBe(true)
  expect(state.sends).toHaveLength(0); await expect(page.locator('#direct-message-body')).toHaveValue('Черновик')
})

test('DM switch cancels a pending paste and never imports the old file into another dialog', async ({ page }) => {
  const state = await mount(page); state.hold = true
  try {
    await paste(page, 'Первый черновик')
    await expect(page.locator('[data-upload-status="uploading"]')).toHaveCount(1)
    await page.evaluate(() => window.dmClipboardFixture.select('second'))
    await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await expect(page.locator('#direct-message-body')).toHaveValue('')
    state.hold = false; state.release(); await paste(page, 'Другой черновик')
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
    expect(state.uploads[1]?.path).toBe(`/api/v1/direct-messages/${second}/attachments`)
    await page.evaluate(() => window.dmClipboardFixture.select('first'))
    await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await expect(page.locator('#direct-message-body')).toHaveValue('Первый черновик')
    await page.evaluate(() => window.dmClipboardFixture.select('second'))
    await expect(page.locator('#direct-message-body')).toHaveValue('Другой черновик')
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
    expect(state.sends).toHaveLength(0)
  } finally { state.release() }
})

test('DM rejects eleven files and oversize before any upload', async ({ page }) => {
  const state = await mount(page)
  await paste(page, '', 11)
  await expect(page.locator('.attachment-picker')).toContainText('не более 10 файлов')
  await paste(page, '', 1, 25_000_001)
  await expect(page.locator('[data-upload-status="failed"]')).toHaveCount(1)
  expect(state.uploads).toHaveLength(0); expect(state.sends).toHaveLength(0)
})
