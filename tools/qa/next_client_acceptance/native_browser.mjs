import { spawn } from 'node:child_process'
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs'
import { resolve, sep } from 'node:path'
import { chromium } from './fixture.mjs'
import { browserState } from './failure.mjs'

// A disposable owned profile avoids Playwright's forced focus/visibility override.
export async function nativeBrowser() {
  const root = resolve('.out/next-client-native-browser')
  mkdirSync(root, { recursive: true })
  const profile = mkdtempSync(root + sep + 'headed-')
  if (!profile.startsWith(root + sep)) throw Error('Foreign browser profile')
  const child = spawn(chromium.executablePath(), ['--remote-debugging-port=0',
    '--remote-debugging-address=127.0.0.1', '--no-sandbox', '--no-first-run',
    '--no-default-browser-check', '--disable-background-networking', '--ignore-certificate-errors',
    '--allow-loopback-in-peer-connection', '--user-data-dir=' + profile, 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] })
  const exited = new Promise(done => { child.once('exit', done); child.once('error', done) })
  let browser
  async function close() {
    try {
      if (browser?.isConnected()) {
        const control = await browser.newBrowserCDPSession()
        await control.send('Browser.close').catch(() => {})
      }
    } finally {
      if (child.pid && child.exitCode === null) {
        const timer = setTimeout(() => child.kill(), 5000)
        await exited; clearTimeout(timer)
      }
      await browser?.close().catch(() => {})
      // profile was created above within the resolved owned output directory.
      rmSync(profile, { recursive: true, force: true })
    }
  }
  try {
    const endpoint = await new Promise((accept, reject) => {
      const timer = setTimeout(() => reject(Error('Owned Chromium startup timed out')), 15000)
      let output = ''
      child.on('error', () => { clearTimeout(timer); reject(Error('Owned Chromium failed to start')) })
      child.on('exit', () => { clearTimeout(timer); reject(Error('Owned Chromium exited before readiness')) })
      child.stderr.on('data', chunk => {
        output = (output + chunk).slice(-8192)
        const found = output.match(/DevTools listening on (ws:\/\/127\.0\.0\.1:\d+\/devtools\/browser\/[^\s]+)/)
        if (found) { clearTimeout(timer); accept(found[1]) }
      })
    })
    browser = await chromium.connectOverCDP(endpoint, { noDefaults: true, isLocal: true })
    const context = browser.contexts()[0]
    const page = context.pages()[0] ?? await context.newPage()
    return { browser, context, page, close, diagnostics: () => browserState(child, browser, page) }
  } catch (error) { await close(); throw error }
}
