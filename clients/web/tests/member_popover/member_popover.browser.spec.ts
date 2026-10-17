import { expect, test, type Page } from '@playwright/test'

async function openProfile(page: Page, name = 'owner') {
  await page.getByRole('button', { name: new RegExp(`^Профиль: ${name} ·`) }).click()
  await expect(page.getByRole('dialog', { name: 'Профиль участника' })).toBeVisible()
  await expect(page.getByRole('heading', { name, exact: true })).toBeVisible()
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 3440, height: 1235 })
  await page.route('**/members/qa-*', async (route) => {
    const name = route.request().url().split('/qa-')[1]
    await route.fulfill({ json: { user_id: `qa-${name}`, login: name, display_name: name, role: 'MEMBER', presence: 'online' } })
  })
  await page.goto('/tests/member_popover/fixture.html')
})

test('clicks throughout the workspace dismiss the profile, even when propagation is stopped', async ({ page }) => {
  for (const target of ['voice-stage', 'header-control', 'sidebar-control']) {
    await openProfile(page)
    await page.getByTestId(target).click()
    await expect(page.getByTestId('member-popover')).toHaveCount(0)
    if (target !== 'voice-stage') await expect(page.getByTestId(target)).toBeFocused()
  }
  await openProfile(page)
  await page.getByTestId('members-panel').click({ position: { x: 15, y: 500 } })
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
})

test('close button is visible without hovering and restores focus to the participant', async ({ page }, testInfo) => {
  await openProfile(page)
  await page.mouse.move(400, 700)
  await expect(page.getByTestId('member-popover').locator('header')).toHaveCSS('opacity', '1')
  await page.screenshot({ path: testInfo.outputPath('desktop-profile.png') })
  await page.getByRole('button', { name: 'Закрыть профиль' }).click()
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  await expect(page.getByRole('button', { name: /^Профиль: owner ·/ })).toBeFocused()
})

test('Escape dismisses the profile and preserves the roster', async ({ page }) => {
  await openProfile(page)
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  await expect(page.getByTestId('members-panel')).toBeVisible()
  await expect(page.getByRole('button', { name: /^Профиль: owner ·/ })).toBeFocused()
})

test('profile interactions and pointer drag on volume keep the profile open', async ({ page }) => {
  await openProfile(page)
  await page.getByRole('heading', { name: 'owner', exact: true }).click()
  const slider = page.getByTestId('member-popover').getByRole('slider')
  const bounds = await slider.boundingBox()
  if (!bounds) throw new Error('Volume slider is missing')
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
  await page.mouse.down()
  await page.mouse.move(bounds.x + bounds.width * 0.75, bounds.y + bounds.height / 2)
  await page.mouse.up()
  await expect(slider).not.toHaveValue('100')
  await expect(page.getByTestId('member-popover')).toBeVisible()
  await expect(page.getByTestId('member-popover').locator('output')).toHaveText(`${await slider.inputValue()}%`)
})

test('another participant can be opened directly after dismissing the previous profile', async ({ page }) => {
  await openProfile(page)
  await openProfile(page, 'member')
  await expect(page.getByRole('heading', { name: 'owner', exact: true })).toHaveCount(0)
  await page.keyboard.press('Escape')
  await openProfile(page)
})

test('profile can be dismissed while loading or after a failed profile request', async ({ page }) => {
  let release!: () => void
  const pending = new Promise<void>((resolve) => { release = resolve })
  await page.route('**/members/qa-owner', async (route) => {
    await pending
    await route.fulfill({ status: 503, json: { error: { message: 'Профиль временно недоступен.' } } })
  })
  await page.getByRole('button', { name: /^Профиль: owner ·/ }).click()
  await expect(page.getByText('Загружаем профиль…')).toBeVisible()
  await page.getByTestId('voice-stage').click()
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  release()
  await page.getByRole('button', { name: /^Профиль: owner ·/ }).click()
  await expect(page.getByRole('alert')).toHaveText('Профиль временно недоступен. Повторить')
  await expect(page.getByRole('button', { name: 'Повторить', exact: true })).toBeEnabled()
  await page.getByTestId('voice-stage').click()
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
})

test('mobile sheet preserves volume controls and closes with backdrop, Escape and its button', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.reload()
  await openProfile(page)
  await page.screenshot({ path: testInfo.outputPath('mobile-profile.png') })
  await page.getByTestId('member-popover').getByRole('slider').focus()
  await page.keyboard.press('ArrowLeft')
  await expect(page.getByTestId('member-popover')).toBeVisible()
  await page.locator('.member-sheet-scrim').click({ position: { x: 20, y: 20 } })
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  await openProfile(page)
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  await expect(page.getByRole('button', { name: /^Профиль: owner ·/ })).toBeFocused()
  await openProfile(page)
  await page.getByRole('button', { name: 'Закрыть профиль' }).click()
  await expect(page.getByTestId('member-popover')).toHaveCount(0)
  await expect(page.getByTestId('members-panel')).toBeVisible()
})
