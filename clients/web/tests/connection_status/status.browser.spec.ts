import { expect, test } from '@playwright/test'

declare global {
  interface Window {
    __connectionStatusFixture: {
      patch: (patch: Record<string, unknown>) => void
      events: string[]
    }
  }
}

test('recovery panel groups independent statuses and retry actions in a narrow sidebar', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 720 })
  await page.goto('/tests/connection_status/fixture.html')

  const panel = page.getByTestId('connection-status')
  await expect(panel).toBeVisible()
  await expect(panel.locator('.connection-status__item')).toHaveCount(3)
  await expect(panel).toContainText('Чат обновляется')
  await expect(panel).toContainText('Голос не подключён')
  await expect(panel).toContainText(/Состав недоступен · \d+ с\. назад/)
  await expect(panel.locator('.connection-status__indicator--reconnecting')).toHaveCount(1)
  await expect(panel.locator('.connection-status__indicator--inactive')).toHaveCount(1)
  await expect(panel.locator('.connection-status__indicator--unavailable')).toHaveCount(1)
  await expect(panel.locator('.connection-status__item').nth(2).locator('.connection-status__label')).not.toHaveAttribute('role', 'status')

  const retryChat = page.getByRole('button', { name: 'Повторить связь чата' })
  const retryRoster = page.getByRole('button', { name: 'Обновить состав' })
  await expect(retryChat).toHaveClass(/connection-status__action/)
  await expect(retryRoster).toHaveClass(/connection-status__action/)
  await page.keyboard.press('Tab')
  await expect(retryChat).toBeFocused()
  await expect(retryChat).toHaveCSS('outline-style', 'solid')
  await retryChat.click()
  await retryRoster.click()
  expect(await page.evaluate(() => window.__connectionStatusFixture.events)).toEqual(['chat', 'roster'])

  const geometry = await panel.evaluate((element) => {
    const rect = element.getBoundingClientRect()
    const style = getComputedStyle(element)
    return {
      panelLeft: rect.left,
      panelRight: rect.right,
      viewportWidth: innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      radius: Number.parseFloat(style.borderRadius),
      background: style.backgroundColor,
    }
  })
  expect(geometry.panelLeft).toBeGreaterThanOrEqual(0)
  expect(geometry.panelRight).toBeLessThanOrEqual(geometry.viewportWidth)
  expect(geometry.scrollWidth).toBeLessThanOrEqual(geometry.viewportWidth)
  expect(geometry.radius).toBeGreaterThan(0)
  expect(geometry.background).not.toBe('rgba(0, 0, 0, 0)')

  await page.screenshot({ path: testInfo.outputPath('connection-status-recovery-320.png'), fullPage: true })
})

test('recovery actions stay within a compact sidebar at 200 percent text size', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 })
  await page.goto('/tests/connection_status/fixture.html')
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })

  const panel = page.getByTestId('connection-status')
  const retryChat = page.getByRole('button', { name: 'Повторить связь чата' })
  await expect(retryChat).toBeVisible()
  const bounds = await panel.evaluate((element) => {
    const panelRect = element.getBoundingClientRect()
    const buttonRect = element.querySelector('button')!.getBoundingClientRect()
    return { panelRight: panelRect.right, buttonRight: buttonRect.right, viewportWidth: innerWidth, scrollWidth: document.documentElement.scrollWidth }
  })
  expect(bounds.buttonRight).toBeLessThanOrEqual(bounds.panelRight)
  expect(bounds.panelRight).toBeLessThanOrEqual(bounds.viewportWidth)
  expect(bounds.scrollWidth).toBeLessThanOrEqual(bounds.viewportWidth)
})

test('fully connected state hides the recovery panel', async ({ page }) => {
  await page.goto('/tests/connection_status/fixture.html')
  await page.evaluate(() => window.__connectionStatusFixture.patch({
    chat: 'CONNECTED',
    voice: 'CONNECTED',
    rosterAvailable: true,
    rosterRetained: true,
  }))
  await expect(page.getByTestId('connection-status')).toHaveCount(0)
})
