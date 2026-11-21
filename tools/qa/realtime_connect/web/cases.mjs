import assert from 'node:assert/strict'
import { expect, api } from '../../client_lifecycle/request.mjs'
import { control } from './observe.mjs'

export async function healthy(page) {
  await expect(page.getByTestId('app-shell')).toBeVisible()
  await expect.poll(() => page.evaluate(() => window.__r2.ready && window.__r2.socket.readyState === 1), { timeout: 30000 }).toBe(true)
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
  await expect(page.getByTestId('connection-status')).not.toBeVisible({timeout:15000})
  await expect(page.getByTestId('participant-card')).toHaveCount(1)
}

export async function faults(page, input) {
  const rows = []
  for (const mode of ['upgrade-error','upgrade-stall','ready-stall','split-budget','session-stall','session-late401']) {
    const original = (await page.context().cookies()).find(c => c.httpOnly)?.value
    assert.ok(original)
    const before = await page.evaluate(() => window.__r2.constructed)
    const identity = (await api(page,'/auth/session')).body.account_id
    await control(page,input.token,mode)
    const started = Date.now()
    await page.evaluate(() => window.__r2.socket.close())
    await expect.poll(async () => (await control(page,input.token)).seen, { timeout: 5000 }).toBe(1)
    if(mode==='ready-stall') {
      await expect.poll(()=>page.evaluate(()=>window.__r2.socket.readyState)).toBe(1)
      assert.equal(await page.evaluate(()=>window.__r2.ready),false)
      await expect(page.getByRole('button',{name:'Повторить связь чата',exact:true})).toBeVisible()
      await expect(page.getByText('Чат подключён',{exact:true})).not.toBeVisible()
    }
    if (['upgrade-stall','ready-stall','session-stall'].includes(mode)) {
      await page.screenshot({ path: input.directory+'/'+mode+'.png' })
    }
    await expect.poll(() => page.evaluate(() => window.__r2.constructed), { timeout: 30000 }).toBeGreaterThan(before)
    await healthy(page)
    const elapsed = Date.now()-started, session = mode.startsWith('session')
    if (mode !== 'upgrade-error') assert.ok(elapsed >= (session ? 9000 : 14000) && elapsed < (session ? 18000 : 23000), 'Recovery outside bounded tolerance')
    else assert.ok(elapsed < 10000)
    if (mode === 'session-late401') await page.waitForTimeout(3000)
    assert.ok((await page.context().cookies()).find(c => c.httpOnly)?.value === original, 'Transient fault changed session cookie')
    assert.ok((await api(page,'/auth/session')).body.account_id === identity, 'Transient fault changed identity')
    const sample = await control(page,input.token)
    if(mode==='session-late401') assert.equal(sample.response_status,401)
    console.log('R2_AUTH',mode,JSON.stringify(sample),elapsed)
    if (mode !== 'upgrade-error') assert.equal(sample.cancelled,true)
    rows.push({ ...sample, recovered_ms:elapsed, identity_cookie_media_preserved:true })
  }
  return rows
}
