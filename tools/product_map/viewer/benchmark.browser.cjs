const { createRequire } = require('node:module')
const { execFileSync } = require('node:child_process')
const { mkdtempSync, unlinkSync, rmdirSync } = require('node:fs')
const { tmpdir } = require('node:os')
const path = require('node:path')
const { pathToFileURL } = require('node:url')
const { chromium } = createRequire(path.resolve('clients/web/package.json'))('@playwright/test')

;(async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'product-map-benchmark-'))
  const file = path.join(dir, 'synthetic.html')
  let browser
  try {
    const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3')
    execFileSync(python, ['-m', 'tools.product_map.viewer.synthetic', '--output', file])
    browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] })
    const results = []
    for (let attempt = 0; attempt < 3; attempt++) {
      const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
      let start = performance.now()
      await page.goto(pathToFileURL(file).href)
      await page.locator('#rows tr').last().waitFor()
      const initial = performance.now() - start
      if (await page.locator('#rows tr').count() !== 1001) throw Error('incorrect initial row count')
      start = performance.now()
      await page.locator('#search').fill('synthetic.feature_01000')
      if (await page.locator('#rows tr').count() !== 1) throw Error('incorrect filtered row count')
      results.push({ initial_ms: Math.round(initial), search_ms: Math.round(performance.now() - start) })
      await page.close()
    }
    console.log(JSON.stringify({ browser: browser.version(), rows: 1001, results }))
  } finally {
    if (browser) await browser.close()
    try { unlinkSync(file) } catch (error) { if (error.code !== 'ENOENT') throw error }
    rmdirSync(dir)
  }
})().catch(error => { console.error(error); process.exit(1) })
