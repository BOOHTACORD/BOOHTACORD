import { expect, test } from '@playwright/test'

test('Firefox falls back to app input without treating background as inactivity', async ({ page }) => {
  await page.goto('/tests/system_activity_fallback/fallback.html')
  await expect(page.getByRole('button', { name: /Учитывать активность всего компьютера/ })).toHaveCount(0)
  const state = () => page.evaluate(() => (window as any).fallbackFixture.observed as { reports: number; inactive: number })
  expect(await state()).toEqual({ reports: 0, inactive: 0 })
  await page.evaluate(() => {
    for (const name of ['blur', 'visibilitychange', 'pagehide', 'pageshow']) window.dispatchEvent(new Event(name))
  })
  expect(await state()).toEqual({ reports: 0, inactive: 0 })
  await page.keyboard.press('a')
  expect((await state()).reports).toBeGreaterThan(0)
  expect((await state()).inactive).toBe(0)
  const before = (await state()).reports
  await page.evaluate(() => (window as any).fallbackFixture.stop())
  await page.keyboard.press('b')
  expect((await state()).reports).toBe(before)
})
