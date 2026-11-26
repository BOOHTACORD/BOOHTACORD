import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, login, api, status, expect } from '../client_lifecycle/request.mjs'
import { observeClipboard, clipboard, paste, capture, send, signal } from '../clipboard_paste/fixture.mjs'
import { setup, dialogs, openDM, selector } from './fixture.mjs'
import { verifyAccess } from './access.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
assert.equal(process.env.QA_ORIGIN, 'https://localhost:4810'); assert.ok(process.env.DISPLAY)
const browser = await chromium.launch({ headless: false }), contexts = []
const report = { task: 'FE-55', status: 'FAIL', checks: {}, browser: browser.version(), mocked_network: false,
  clipboard: 'trusted Ctrl+V on an owned Xvfb display', nonparticipant_roles: ['MEMBER','ADMINISTRATOR'] }
let phase = 'setup', activePage = null, shared = null
async function client(name, width = 1440) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width, height: 900 }, permissions: ['clipboard-read','clipboard-write'] })
  contexts.push(context); context.setDefaultTimeout(20000)
  const page = await context.newPage(); await login(page, name, input.password); return page
}
try {
  const admin = await client('qa_admin')
  for (const width of [1440,393]) {
    phase = width+' setup'
    const members = await setup(admin, input.password, width, shared); shared = { peer: members.peer, other: members.other }; phase = width+' owner login'
    const owner = await client(members.owner.login, width); activePage = owner; phase = width+' create dialogs'
    const fixture = await dialogs(owner, members); phase = width+' peer login'
    const peer = await client(fixture.peer.login); phase = width+' other login'
    const other = await client(fixture.other.login); phase = width+' select owner DM'
    await openDM(owner, fixture.peer.name); phase = width+' select peer DM'
    await openDM(peer, fixture.owner.name); await observeClipboard(owner)
    const prefix = '/direct-messages/'+fixture.a, composer = owner.locator(selector)
    let sends = 0
    owner.on('request', r => { if (r.method() === 'POST' && new URL(r.url()).pathname.endsWith('/messages')) sends++ })
    phase = width+' trusted plain and mixed clipboard'
    await clipboard(owner, 'обычный текст', false); await paste(owner, selector)
    await expect(composer).toHaveValue('обычный текст'); await expect(owner.locator('[data-upload-status]')).toHaveCount(0)
    await composer.fill('До OLD после'); await composer.evaluate(node => node.setSelectionRange(3,6))
    await clipboard(owner, 'подпись'); await owner.keyboard.press('Control+V')
    await expect(composer).toHaveValue('До подпись после'); await expect(owner.locator('[data-upload-status="done"]')).toHaveCount(1)
    assert.equal(sends, 0); await capture(owner, input.directory, width+'-dm-clipboard-ready', selector)
    const observation = await owner.evaluate(() => window.pastedImage), mixed = await send(owner, prefix, selector)
    assert.equal(mixed.body, 'До подпись после'); report.checks[width+'_trusted_paste_no_auto_send_original_bytes'] = 'PASS'
    phase = width+' participant-only original preview history search upload and cross-DM ACL'
    await verifyAccess(owner, peer, other, admin, fixture, mixed, observation.hash)
    report.checks[width+'_participant_bytes_preview_nonparticipant_member_admin_and_cross_scope_acl'] = 'PASS'
    phase = width+' actual storage507 and explicit same-file retry'
    await signal(input, 'arm-'+width, { channel: fixture.channel }); await clipboard(owner, ''); await paste(owner, selector)
    await expect(owner.locator('[data-upload-status="failed"]')).toHaveCount(1)
    await expect(owner.locator('.attachment-picker')).toContainText('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
    await expect(owner.getByRole('button', { name: 'Отправить сообщение', exact: true })).toBeDisabled()
    await capture(owner, input.directory, width+'-dm-clipboard-507', selector)
    await clipboard(owner, 'Буфер заменён после ошибки', false); await signal(input, 'release-'+width)
    const retried = owner.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname === '/api/v1'+prefix+'/attachments' && r.status() === 201)
    await owner.getByRole('button', { name: /^Повторить загрузку / }).click()
    await expect(owner.locator('[data-upload-status="done"]')).toHaveCount(1); assert.equal(sends, 2)
    const prepared = await (await retried).json()
    await openDM(owner, fixture.other.name); await expect(owner.locator('[data-upload-status]')).toHaveCount(0)
    await openDM(owner, fixture.peer.name); await expect(owner.locator('[data-upload-status="done"]')).toHaveCount(1)
    const restored = await send(owner, prefix, selector); assert.equal(restored.body, ''); assert.equal(restored.attachments[0].id, prepared.id)
    report.checks[width+'_actual507_release_retained_file_retry_attachment_only'] = 'PASS'
    phase = width+' real pending upload switch and scoped drafts'
    await composer.fill('Черновик первого диалога'); await clipboard(owner, '', true, true)
    const cdp = await owner.context().newCDPSession(owner); await cdp.send('Network.enable')
    await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 20, downloadThroughput: 10000000, uploadThroughput: 1024 })
    await paste(owner, selector); await expect(owner.locator('[data-upload-status="uploading"]')).toHaveCount(1)
    await signal(input, 'pending-'+width); await openDM(owner, fixture.other.name)
    await expect(owner.locator('[data-upload-status]')).toHaveCount(0); await expect(composer).toHaveValue('')
    await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }); await cdp.detach()
    await signal(input, 'cancelled-'+width); await composer.fill('Черновик второго диалога'); await openDM(owner, fixture.peer.name)
    await expect(owner.locator('[data-upload-status]')).toHaveCount(0); await expect(composer).toHaveValue('Черновик первого диалога')
    const history = await api(owner, '/direct-messages/'+fixture.b+'/messages?limit=20'); status(history, 200); assert.equal(history.body.messages.length, 0)
    await openDM(owner, fixture.other.name); await expect(composer).toHaveValue('Черновик второго диалога')
    await expect(owner.locator('[data-upload-status]')).toHaveCount(0)
    await openDM(owner, fixture.peer.name); await expect(composer).toHaveValue('Черновик первого диалога')
    assert.equal(sends, 3); await capture(owner, input.directory, width+'-dm-clipboard-cancelled', selector)
    report.checks[width+'_scope_abort_zero_reservations_independent_drafts_no_id_leak'] = 'PASS'
  }
  report.status = 'PASS'
} catch (cause) {
  report.failed_phase = phase; report.failure_type = cause?.name || 'unknown'
  if ([200,201,204].includes(cause?.expected) && Number.isInteger(cause?.actual) && cause.actual >= 100 && cause.actual <= 599) report.failed_http_status = cause.actual
  report.failed_source_line = /scenario.mjs:(\d+)/.exec(cause?.stack ?? '')?.[1]
  if (activePage) await activePage.screenshot({ path: input.directory+'/failed.png' }).catch(() => {})
  throw Error('Sanitized FE-55 acceptance failure at phase: '+phase)
}
finally { writeFileSync(process.env.QA_RESULT, JSON.stringify(report,null,2)+'\n'); for (const context of contexts) await context.close(); await browser.close() }
