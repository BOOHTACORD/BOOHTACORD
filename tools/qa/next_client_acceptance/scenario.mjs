import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { expect, login, setup } from './fixture.mjs'
import { nativeBrowser } from './native_browser.mjs'
import { uploads } from './uploads.mjs'
import { unread } from './unread.mjs'
import { navigation } from './navigation.mjs'
import { captureFailure, failureSummary } from './failure.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
assert.equal(process.env.QA_ORIGIN,'https://localhost:4810')
let owned, stage = 'browser-launch'
try {
  owned = await nativeBrowser()
  const browser = owned.browser
  const context = owned.context
  context.setDefaultTimeout(20000)
  const page = owned.page, report = { status:'PASS', capacity_limited:input.limited }
  await page.setViewportSize({ width:1440, height:900 })
  await page.goto(process.env.QA_ORIGIN)
  stage = 'api-ready'
  await expect.poll(async () => page.evaluate(async () => {
    try { return (await fetch('/api/v1/health', { cache:'no-store' })).status }
    catch { return 0 }
  }), { timeout:15000 }).toBe(200)
  console.log('stage=browser-api-ready')
  stage = 'login'
  await login(page,'qa_admin',input.password)
  stage = 'fixture-setup'
  const fixture = await setup(page,input.password)
  stage = 'reload'
  await page.reload()
  stage = 'uploads'
  await uploads(page,input,report,fixture)
  console.log('stage=actual-managed-uploads-accepted')
  if (!input.limited) {
    stage = 'unread'
    await unread(page,browser,fixture,input,report)
    console.log('stage=actual-protected-unread-accepted')
    stage = 'navigation'
    await navigation(page,fixture,input,report)
    console.log('stage=actual-protected-navigation-accepted')
  }
  stage = 'receipt'
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n',{mode:0o600})
} catch (error) {
  await captureFailure(owned?.page, input.directory, error, stage).catch(() => console.error('FAIL: bounded fixture diagnostics unavailable'))
  console.error(failureSummary(error)); process.exitCode=1
} finally { await owned?.close() }
