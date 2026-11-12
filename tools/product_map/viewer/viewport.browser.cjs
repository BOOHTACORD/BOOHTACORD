const test = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')
const { pathToFileURL } = require('node:url')
const { createRequire } = require('node:module')

const webRequire = createRequire(path.resolve('clients/web/package.json'))
const { chromium } = webRequire('@playwright/test')
const viewer = pathToFileURL(path.resolve('docs/product-map/generated/index.html')).href

test('long component paths remain readable within mobile viewport', async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] })
  try {
    const page = await browser.newPage({ viewport: { width: 320, height: 852 } })
    for (const width of [320, 393]) {
      await page.setViewportSize({ width, height: 852 })
      await page.goto(viewer + '#feature/voice.roster_long_recovery')
      await page.locator('#detail a').first().waitFor()
      await page.locator('#platform').selectOption('all')
      const dimensions = await page.evaluate(() => ({
        viewport: window.innerWidth,
        document: document.documentElement.scrollWidth,
        wrapper: document.querySelector('.table-wrap').clientWidth,
        table: document.querySelector('.table-wrap').scrollWidth,
      }))
      assert.equal(dimensions.document, dimensions.viewport, `page overflows at ${width}px`)
      assert.ok(dimensions.table > dimensions.wrapper, 'the matrix retains its own horizontal scroll')
      assert.ok(await page.locator('#detail a[href*="clients/web/src/voice/"]').count())
      await page.locator('#platform').selectOption('android')
      const single = await page.locator('.table-wrap').evaluate(element => ({
        viewport: element.clientWidth, content: element.scrollWidth,
      }))
      assert.equal(single.content, single.viewport, `selected platform is outside the ${width}px viewport`)
      assert.match(await page.locator('#header').innerText(), /Android/)
      assert.match(await page.locator('#rows tr td').innerText(), /UNKNOWN/)
      const statusRects = await page.locator('#rows tr td').evaluate(element => {
        const text = element.firstChild, index = text.textContent.indexOf('UNKNOWN')
        const range = document.createRange()
        range.setStart(text, index); range.setEnd(text, index + 'UNKNOWN'.length)
        return range.getClientRects().length
      })
      assert.equal(statusRects, 1, 'the platform status is split across lines')
      const columnWidths = await page.locator('#header th').evaluateAll(cells =>
        cells.map(cell => cell.getBoundingClientRect().width))
      assert.ok(columnWidths[0] > columnWidths[1], 'scenario text needs more room than its status')
      const labelHeights = await page.locator('.filters fieldset label').evaluateAll(labels =>
        labels.map(label => label.getBoundingClientRect().height))
      assert.ok(labelHeights.every(height => height < 30), 'layer labels wrap across lines')
    }
  } finally {
    await browser.close()
  }
})
