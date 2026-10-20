import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { expect, login, setup } from './fixture.mjs'
import { nativeBrowser } from './native_browser.mjs'
import { uploads } from './uploads.mjs'
import { unread } from './unread.mjs'
import { navigation } from './navigation.mjs'
import { captureFailure, failureSummary } from './failure.mjs'
import { freshBrowser } from './fresh_browser.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
assert.equal(process.env.QA_ORIGIN,'https://localhost:4810')
let owned = await nativeBrowser(), browser = owned.browser
try {
  const context = owned.context
  context.setDefaultTimeout(20000)
  let page = owned.page
  const report = { status:'PASS', capacity_limited:input.limited }
  await page.setViewportSize({ width:1440, height:900 })
  await page.goto(process.env.QA_ORIGIN)
  await expect.poll(async () => page.evaluate(async () => {
    try { return (await fetch('/api/v1/health', { cache:'no-store' })).status }
    catch { return 0 }
  }), { timeout:15000 }).toBe(200)
  console.log('stage=browser-api-ready')
  await login(page,'qa_admin',input.password)
  const fixture = await setup(page,input.password)
  await page.reload()
  await uploads(page,input,report,fixture, async () => {
    owned = await freshBrowser(owned, nativeBrowser)
    browser = owned.browser; page = owned.page
    owned.context.setDefaultTimeout(20000)
    await page.setViewportSize({ width:1440, height:900 })
    await page.goto(process.env.QA_ORIGIN)
    return page
  })
  console.log('stage=actual-managed-uploads-accepted')
  if (!input.limited) {
    await unread(page,browser,fixture,input,report)
    console.log('stage=actual-protected-unread-accepted')
    await navigation(page,fixture,input,report)
    console.log('stage=actual-protected-navigation-accepted')
  }
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n',{mode:0o600})
} catch (error) {
  await captureFailure(owned.page, input.directory).catch(() => console.error('FAIL: bounded fixture diagnostics unavailable'))
  console.error(failureSummary(error)); process.exitCode=1
} finally { await owned.close() }
