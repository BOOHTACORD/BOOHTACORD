const SELECTOR = '[data-testid=stream-select]:visible'
const PANELS = {
  streams: { selector: SELECTOR, button: /^Трансляции · \d+$/ },
  participants: { selector: '[data-testid=viewer-participants]:visible', button: /^Участники · \d+/ },
}

export async function openViewerPanel(page, name) {
  const panel = PANELS[name]
  if (!panel) throw new Error('Unknown screen viewer panel')
  if (await page.locator(panel.selector).count() === 0) {
    await page.getByRole('button', { name: panel.button }).click()
  }
}

export async function selectVisibleStream(page, index = 0) {
  const participantPreviews = page.locator('[data-testid=participant-screen-preview]:visible')
  if (await participantPreviews.count() > index) {
    await participantPreviews.nth(index).click()
    return
  }
  await openViewerPanel(page, 'streams')
  await page.locator(SELECTOR).nth(index).click()
}
