import { expect, test } from '@playwright/test'
import { mount, paste, first, second } from '../clipboard_paste/helpers'

for (const width of [1440, 393, 320]) for (const scale of [1, 2]) test(`TEXT mixed paste preserves the selection and waits for Send at ${width}px scale${scale}`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 900 })
  const state = await mount(page), input = page.locator('#message-body')
  await page.evaluate(scale => { document.documentElement.style.fontSize = `${100*scale}%` }, scale)
  await input.fill('До OLD после'); await input.evaluate(node => node.setSelectionRange(3, 6))
  await paste(page, 'подпись')
  await expect(input).toHaveValue('До подпись после')
  await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
  expect(state.uploads).toEqual([{ path: `/api/v1/channels/${first}/attachments`, imageBytes: true }])
  expect(state.sends).toHaveLength(0)
  await page.evaluate(() => document.fonts.ready)
  const geometry = await input.evaluate(node => {
    const css = getComputedStyle(node), rect = node.getBoundingClientRect()
    return { contentHeight: node.clientHeight - parseFloat(css.paddingTop) - parseFloat(css.paddingBottom), lineHeight: parseFloat(css.lineHeight), x: rect.x, y: rect.y, width: rect.width, height: rect.height, display: css.display, font: css.fontSize, color: css.color, opacity: css.opacity, visibility: css.visibility, topHit: document.elementFromPoint(rect.x+10,rect.y+10)?.tagName, scrollTop: node.scrollTop, clientHeight: node.clientHeight, scrollHeight: node.scrollHeight }
  })
  expect(geometry.width, JSON.stringify(geometry)).toBeGreaterThanOrEqual(96)
  expect(geometry.topHit).toBe('TEXTAREA')
  expect(geometry.scrollHeight).toBeLessThanOrEqual(geometry.clientHeight + 1)
  expect(geometry.contentHeight, JSON.stringify(geometry)).toBeGreaterThanOrEqual(geometry.lineHeight - 0.5)
  await page.screenshot({ path: info.outputPath(`clipboard-ready-${width}-${scale}.png`) })
  await page.getByRole('button', { name: 'Отправить сообщение', exact: true }).click()
  await expect(input).toHaveValue(''); expect(state.sends).toHaveLength(1)
  expect(state.sends[0]).toMatchObject({ body: 'До подпись после', attachment_ids: [expect.any(String)] })
})

test('TEXT explains 507 and retries the same pasted image without automatic send', async ({ page }, info) => {
  const state = await mount(page); state.fail = true
  await paste(page, 'Черновик')
  await expect(page.locator('[data-upload-status="failed"]')).toHaveCount(1)
  await expect(page.locator('.attachment-picker')).toContainText('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
  await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
  await page.screenshot({ path: info.outputPath('clipboard-storage-full.png') })
  state.fail = false; await page.getByRole('button', { name: 'Повторить загрузку image.png', exact: true }).click()
  await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
  expect(state.uploads).toHaveLength(2); expect(state.uploads.every(upload => upload.imageBytes)).toBe(true)
  expect(state.sends).toHaveLength(0); await expect(page.locator('#message-body')).toHaveValue('Черновик')
})

test('TEXT scope change cancels pending paste and never imports old IDs into the new channel', async ({ page }) => {
  const state = await mount(page); state.hold = true
  try {
    await paste(page, 'Первый черновик')
    await expect(page.locator('[data-upload-status="uploading"]')).toHaveCount(1)
    await page.evaluate(() => window.clipboardFixture.select('second'))
    await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await expect(page.locator('#message-body')).toHaveValue('')
    state.hold = false; state.release(); await paste(page, 'Другой черновик')
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
    expect(state.uploads[1]?.path).toBe(`/api/v1/channels/${second}/attachments`)
    await page.evaluate(() => window.clipboardFixture.select('first'))
    await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await expect(page.locator('#message-body')).toHaveValue('Первый черновик')
    await page.evaluate(() => window.clipboardFixture.select('second'))
    await expect(page.locator('#message-body')).toHaveValue('Другой черновик')
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
    expect(state.sends).toHaveLength(0)
  } finally { state.release() }
})

test('TEXT rejects an eleven-image paste and a file above25MB without transmitting it', async ({ page }) => {
  const state = await mount(page)
  await paste(page, '', 11)
  await expect(page.locator('.attachment-picker')).toContainText('не более 10 файлов')
  expect(state.uploads).toHaveLength(0)
  await paste(page, '', 1, 25_000_001)
  await expect(page.locator('[data-upload-status="failed"]')).toHaveCount(1)
  expect(state.uploads).toHaveLength(0); expect(state.sends).toHaveLength(0)
})
