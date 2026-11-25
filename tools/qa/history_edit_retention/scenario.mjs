import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, login, origin } from '../client_lifecycle/request.mjs'
import { historyAcceptance } from './acceptance.mjs'
import { historyState } from './dom.mjs'

const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
assert.equal(origin, 'https://localhost:4810')
const browser = await chromium.launch({ headless: true })
const report = { status: 'FAIL', mocks: false, physical_acceptance: 'NOT_RUN' }
const redactions = [input.password]
let primary
try {
  const contexts = await Promise.all([0, 1].map(() => browser.newContext({
    ignoreHTTPSErrors: true, viewport: { width: input.viewport.width, height: 900 },
  })))
  await contexts[0].addInitScript(() => {
    window.historyResizeErrors = []
    window.addEventListener('error', event => {
      if (event.message.includes('ResizeObserver loop')) window.historyResizeErrors.push(event.message)
    })
  })
  const [a, b] = await Promise.all(contexts.map(context => context.newPage()))
  primary = a
  for (const page of [a, b]) { page.setDefaultTimeout(15000); await login(page, 'qa_admin', input.password) }
  const errors = []
  a.on('pageerror', error => errors.push(error.message))
  await historyAcceptance(a, b, input, report)
  assert.deepEqual(await a.evaluate(() => window.historyResizeErrors), [])
  assert.deepEqual(errors, [])
  report.status = 'PASS'
} catch (error) {
  for (const context of browser.contexts()) redactions.push(...(await context.cookies()).map(cookie => cookie.value))
  let message = String(error)
  for (const value of redactions.filter(Boolean)) message = message.split(value).join('[redacted]')
  console.error('Owned history acceptance failed: '+message.slice(0, 1800))
  if (primary && await primary.getByTestId('app-shell').isVisible()) {
    await primary.screenshot({ path: input.directory+'/failure.png' })
    const state = await historyState(primary)
    report.failure_state = { cached: state.count, loaded: state.loaded, older: state.older, newer: state.newer }
  }
  process.exitCode = 1
} finally {
  writeFileSync(input.directory+'/browser.json', JSON.stringify(report, null, 2)+'\n')
  await browser.close()
}
