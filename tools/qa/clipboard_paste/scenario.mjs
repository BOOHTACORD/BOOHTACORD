import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, login } from '../client_lifecycle/request.mjs'
import { api, status, channel, expect, signal, setup, observeClipboard, clipboard, paste, capture, send } from './fixture.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
assert.equal(process.env.QA_ORIGIN, 'https://localhost:4810')
assert.ok(process.env.DISPLAY, 'An owned virtual display/clipboard is required')
const browser = await chromium.launch({ headless: false }), contexts = []
const report = { task: 'FE-54', status: 'FAIL', checks: {}, browser: browser.version(), mocked_network: false, clipboard: 'trusted Ctrl+V on an owned Xvfb display' }
let phase = 'setup'
async function client(name, width) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width, height: 900 }, permissions: ['clipboard-read', 'clipboard-write'] })
  contexts.push(context); context.setDefaultTimeout(20000)
  const page = await context.newPage(); await login(page, name, input.password); return page
}
try {
  const admin = await client('qa_admin', 1440)
  for (const width of [1440, 393]) {
    const fixture = await setup(admin, input.password, width), page = await client(fixture.name, width)
    await channel(page, fixture.aName, fixture.a); await observeClipboard(page)
    const prefix = '/channels/'+fixture.a, composer = page.locator('#message-body')
    let sends = 0
    page.on('request', r => { if (r.method() === 'POST' && new URL(r.url()).pathname.endsWith('/messages')) sends++ })
    phase = width+' plain text OS clipboard'
    await clipboard(page, 'обычный текст', false); await paste(page)
    await expect(composer).toHaveValue('обычный текст'); await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    phase = width+' mixed OS clipboard and explicit send'
    await composer.fill('До OLD после'); await composer.evaluate(node => node.setSelectionRange(3, 6))
    await clipboard(page, 'подпись'); await page.keyboard.press('Control+V')
    await expect(composer).toHaveValue('До подпись после')
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1); assert.equal(sends, 0)
    await capture(page, input.directory, width+'-clipboard-ready')
    const mixed = await send(page, prefix); assert.equal(mixed.body, 'До подпись после')
    report.checks[width+'_trusted_mixed_plaintext_no_auto_send_original_bytes'] = 'PASS'
    phase = width+' actual storage reservation 507'
    await signal(input, 'arm-'+width, { channel: fixture.a })
    await clipboard(page, ''); await paste(page)
    await expect(page.locator('[data-upload-status="failed"]')).toHaveCount(1)
    await expect(page.locator('.attachment-picker')).toContainText('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
    await expect(page.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
    await capture(page, input.directory, width+'-clipboard-507')
    await clipboard(page, 'Буфер заменён после ошибки', false)
    await signal(input, 'release-'+width)
    await page.getByRole('button', { name: /^Повторить загрузку / }).click()
    await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1); assert.equal(sends, 1)
    await channel(page, fixture.bName, fixture.b); await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await channel(page, fixture.aName, fixture.a); await expect(page.locator('[data-upload-status="done"]')).toHaveCount(1)
    assert.equal((await send(page, prefix)).body, '')
    report.checks[width+'_actual_507_reservation_release_same_file_retry_attachment_only'] = 'PASS'
    phase = width+' real throttled upload and channel switch'
    await composer.fill('Черновик первого канала'); await clipboard(page, '', true, true)
    const cdp = await page.context().newCDPSession(page)
    await cdp.send('Network.enable')
    await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 20, downloadThroughput: 10000000, uploadThroughput: 1024 })
    await paste(page); await expect(page.locator('[data-upload-status="uploading"]')).toHaveCount(1)
    await signal(input, 'pending-'+width)
    await channel(page, fixture.bName, fixture.b)
    await expect(page.locator('[data-upload-status]')).toHaveCount(0)
    await expect(composer).toHaveValue('')
    await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }); await cdp.detach()
    await signal(input, 'cancelled-'+width)
    await composer.fill('Черновик второго канала')
    await channel(page, fixture.aName, fixture.a)
    await expect(page.locator('[data-upload-status]')).toHaveCount(0); await expect(composer).toHaveValue('Черновик первого канала')
    const other = await api(page, '/channels/'+fixture.b+'/messages?limit=20'); status(other, 200); assert.equal(other.body.messages.length, 0)
    assert.equal(sends, 2); await capture(page, input.directory, width+'-clipboard-cancelled')
    report.checks[width+'_pending_transport_abort_zero_reservations_and_scope_isolation'] = 'PASS'
  }
  report.status = 'PASS'
} catch (cause) {
  report.failed_phase = phase; report.failure_type = cause?.name || 'unknown'
  throw Error('Sanitized FE-54 acceptance failure at phase: '+phase)
} finally {
  writeFileSync(process.env.QA_RESULT, JSON.stringify(report, null, 2)+'\n')
  for (const context of contexts) await context.close()
  await browser.close()
}
