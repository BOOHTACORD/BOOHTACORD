const SELECTOR = '[data-testid=stream-select]:visible'

export async function selectVisibleStream(page, index = 0) {
  if (await page.locator(SELECTOR).count() === 0) {
    await page.getByRole('button', { name: /^Трансляции · \d+$/ }).click()
  }
  await page.locator(SELECTOR).nth(index).click()
}
