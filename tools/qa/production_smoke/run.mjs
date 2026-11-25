import { createRequire } from 'node:module'
import { runScenario } from './scenario.mjs'
import { createBrowserAdapter } from './browser.mjs'

const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const { chromium } = require('@playwright/test')
let stage = 'setup'
try {
  const adapter = await createBrowserAdapter(chromium, {
    login: process.env.SMOKE_LOGIN,
    password: process.env.SMOKE_PASSWORD,
    channel: 'QA Production Smoke',
  })
  await runScenario(adapter, process.env.EXPECTED_REVISION ?? '', value => { stage = value })
  console.log('PASS: source, login, WebRTC connection, synthetic audio publication, disconnect and logout')
} catch {
  console.error('FAIL: production smoke stage=' + stage)
  process.exitCode = 1
}
