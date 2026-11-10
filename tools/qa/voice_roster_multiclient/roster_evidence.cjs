function matches(prejoin, sidebar, expected) {
  const canonical = values => [...values].sort().join('\u0000')
  if (new Set(expected).size !== expected.length) return false
  return prejoin.length === expected.length && sidebar.length === expected.length &&
    canonical(prejoin) === canonical(expected) && canonical(sidebar) === canonical(expected)
}

async function roster(page, expected, channel = 'QA voice') {
  const deadline = Date.now() + 40000
  while (Date.now() < deadline) {
    const prejoin = await page.locator('.voice-prejoin .voice-member-name').allTextContents()
    const row = page.locator('.sidebar .channel-row').filter({ has: page.getByText(channel, { exact: true }) })
    const sidebar = await row.locator('xpath=following-sibling::*[1]').locator('.voice-member-name').allTextContents()
    if (matches(prejoin, sidebar, expected)) return
    await new Promise(resolve => setTimeout(resolve, 200))
  }
  throw Error('roster participants differ between views')
}

module.exports = { matches, roster }
