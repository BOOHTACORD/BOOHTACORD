import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium } from '../client_lifecycle/request.mjs'
import { api, status, expect, login, setup, select, upload, fileStatuses, view } from './fixture.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
assert.equal(process.env.QA_ORIGIN, 'https://localhost:4810')
const browser = await chromium.launch({ headless: true, executablePath: process.env.QA_BROWSER_EXECUTABLE })
const contexts = [], report = { task: 'FE-53', checks: {}, mocks: false, browser: browser.version() }
let phase = 'setup'
async function client(name, width = 1440) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width, height: 900 } })
  contexts.push(context); context.setDefaultTimeout(20000)
  const page = await context.newPage(); await login(page, name, input.password); return page
}
try {
  const admin = await client('qa_admin')
  const suffix = process.env.QA_RUN_SUFFIX || 'linux'
  const fixture = await setup(admin, input.password, suffix)
  const a = await client(fixture.names[0]), b = await client(fixture.names[1])
  const created = await api(a, '/direct-messages', 'POST', { participant_id: fixture.accounts[1] }); status(created, 201)
  const other = await api(admin, '/direct-messages', 'POST', { participant_id: fixture.accounts[0] }); status(other, 201)
  fixture.dm = created.body.id
  for (const page of [a, b]) await page.reload()
  const anonymousContext = await browser.newContext({ ignoreHTTPSErrors: true }); contexts.push(anonymousContext)
  const anonymous = await anonymousContext.newPage(); await anonymous.goto(process.env.QA_ORIGIN)
  for (const kind of ['TEXT', 'DM']) {
    phase = kind+' upload and normalization'
    const prefix = kind === 'TEXT' ? '/channels/'+fixture.channel : '/direct-messages/'+fixture.dm
    const name = kind+'-защищённое-изображение.png'
    await select(b, kind, fixture, fixture.names[0])
    const message = await upload(b, prefix, name), attachment = message.attachments[0].id
    await select(a, kind, fixture)
    assert.deepEqual(await fileStatuses(a, prefix, attachment), [200, 200])
    assert.deepEqual(await fileStatuses(b, prefix, attachment), [200, 200])
    assert.deepEqual(await fileStatuses(anonymous, prefix, attachment), [401, 401])
    if (kind === 'DM') {
      assert.deepEqual(await fileStatuses(admin, prefix, attachment), [404, 404])
      assert.deepEqual(await fileStatuses(a, '/direct-messages/'+other.body.id, attachment), [404, 404])
    } else {
      assert.deepEqual(await fileStatuses(a, '/direct-messages/'+fixture.dm, attachment), [404, 404])
    }
    report.checks[kind+'_current_access_original_preview_and_denials'] = 'PASS'
    for (const width of [1440, 393, 320]) {
      phase = kind+' viewer '+width
      await a.setViewportSize({ width, height: 900 })
      await view(a, name, prefix, attachment, input.directory, kind+'-'+width)
      report.checks[kind+'_'+width+'_normalization_focus_bounds_and_original_bytes'] = 'PASS'
    }
    phase = kind+' peer deletion revokes an open preview'
    await a.setViewportSize({ width: 1440, height: 900 })
    await a.getByRole('button', { name: 'Открыть изображение '+name, exact: true }).click()
    await expect(a.getByRole('dialog').locator('img')).toBeVisible()
    status(await api(b, prefix+'/messages/'+message.id, 'DELETE'), 204)
    await expect(a.getByRole('dialog')).not.toBeVisible()
    assert.deepEqual(await fileStatuses(a, prefix, attachment), [404, 404])
    report.checks[kind+'_live_deletion_closes_viewer_and_denies_bytes'] = 'PASS'
  }
  report.status = 'PASS'
} catch (cause) {
  report.status = 'FAIL'; report.failed_phase = phase; report.failure_type = cause?.name || 'unknown'
  throw Error('Sanitized FE-53 acceptance failure at phase: '+phase)
} finally {
  writeFileSync(process.env.QA_RESULT, JSON.stringify(report, null, 2)+'\n')
  for (const context of contexts) await context.close()
  await browser.close()
}
