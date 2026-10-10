import { expect, test } from '@playwright/test'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

test('scenario names stay readable and selecting 1440p chooses the supported text profile', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/tests/screen_profile/quality_dialog.fixture.html')

  const dialog = page.getByRole('dialog')
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('heading', { name: 'Демонстрация экрана' })).toBeVisible()
  for (const actionName of ['Закрыть', 'Отмена', 'Начать трансляцию']) {
    await expect(dialog.getByRole('button', { name: actionName, exact: true })).toBeVisible()
  }
  await expect(dialog.getByRole('button', { name: 'Закрыть', exact: true })).toHaveAttribute('aria-label', 'Закрыть')
  const scenarios = page.locator('.screen-share-quality__scenario-option')
  await expect(scenarios).toHaveCount(2)
  await expect(page.getByRole('heading', { name: 'Качество изображения' })).toBeVisible()
  await expect(page.getByRole('radio', { name: '1440p' })).toBeVisible()
  await expect(page.locator('.screen-share-quality__single-value')).toBeInViewport({ ratio: 0.99 })
  await expect(scenarios.first()).toBeInViewport({ ratio: 0.99 })
  await expect(scenarios.nth(1)).toBeInViewport({ ratio: 0.99 })
  await expect(page.getByRole('radio', { name: '1080p' })).toBeInViewport({ ratio: 0.99 })
  await expect(page.getByRole('radio', { name: '1440p' })).toBeInViewport({ ratio: 0.99 })
  const scenarioLegend = dialog.locator('.screen-share-quality__mode legend')
  const scenarioOptions = dialog.locator('.screen-share-quality__scenarios')
  const scenarioLegendBox = await scenarioLegend.boundingBox()
  const scenarioOptionsBox = await scenarioOptions.boundingBox()
  const bodyBox = await dialog.locator('.screen-share-setup__body').boundingBox()
  expect(scenarioOptionsBox!.y).toBeGreaterThanOrEqual(scenarioLegendBox!.y + scenarioLegendBox!.height)
  expect(scenarioOptionsBox!.width).toBeGreaterThan(bodyBox!.width * 0.9)
  await expect(scenarios.nth(0)).toContainText('Плавность')
  await expect(scenarios.nth(0)).toContainText('Игры и видео · 60 FPS')
  await expect(scenarios.nth(1)).toContainText('Чёткость текста')
  await expect(scenarios.nth(1)).toContainText('Документы и код · 15–30 FPS')

  for (const option of await scenarios.all()) {
    const label = option.locator('.screen-share-quality__scenario-title')
    const textStyle = await label.evaluate(element => getComputedStyle(element).whiteSpace)
    expect(textStyle).toBe('normal')
  }

  const resolution1440 = page.getByRole('radio', { name: '1440p' })
  await expect(resolution1440).toBeEnabled()
  await expect(page.locator('.screen-share-quality__single-value')).toHaveText('60 FPS')
  const fpsGroup = page.locator('.screen-share-quality__single-value')
  const fpsGroupBox = await fpsGroup.boundingBox()
  const resolutionGroupBox = await page.locator('[aria-label="Верхний предел разрешения трансляции"]').boundingBox()
  expect(fpsGroupBox?.width).toBeCloseTo(resolutionGroupBox!.width, 1)

  await page.keyboard.press('Tab')
  const keyboardFocusedScenario = dialog.locator('.screen-share-quality__scenario-option:has(input:focus-visible)')
  await expect(keyboardFocusedScenario).toHaveCount(1)
  expect(await keyboardFocusedScenario.evaluate(element => getComputedStyle(element).outlineStyle)).toBe('solid')
  await page.keyboard.press('Tab')
  const keyboardFocusedQuality = dialog.locator('.screen-share-quality__option:has(input:focus-visible)')
  await expect(keyboardFocusedQuality).toHaveCount(1)
  await expect(page.getByRole('radio', { name: '1080p' })).toBeFocused()
  await page.keyboard.press('ArrowRight')
  await expect(page.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(resolution1440).toBeChecked()
  await expect(keyboardFocusedQuality).toHaveCount(1)
  expect(await keyboardFocusedQuality.evaluate(element => getComputedStyle(element).outlineStyle)).toBe('solid')
  const textFrameRate = page.getByRole('radio', { name: '30 FPS', exact: true })
  await expect(textFrameRate).toBeVisible()
  await expect(dialog.locator('.screen-share-quality__mode')).toBeInViewport({ ratio: 0.99 })
  for (const card of await scenarios.all()) {
    await expect(card).toBeInViewport({ ratio: 0.99 })
    await expect(card.locator('.screen-share-quality__scenario-title')).toBeInViewport({ ratio: 0.99 })
    await expect(card.locator('.screen-share-quality__scenario-copy small')).toBeInViewport({ ratio: 0.99 })
  }
  await expect(resolution1440).toBeInViewport({ ratio: 0.99 })
  await expect(textFrameRate).toBeInViewport({ ratio: 0.99 })
  await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') })
  const violations = await page.evaluate(async () => {
    const result = await (window as any).axe.run(document.querySelector('dialog'), {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] },
    })
    return result.violations.map(({ id, impact, nodes }: { id: string; impact: string; nodes: { target: string[] }[] }) => ({
      id, impact, targets: nodes.flatMap(node => node.target),
    }))
  })
  expect(violations).toEqual([])
  await page.screenshot({ path: testInfo.outputPath('screen-share-quality-637x584.png') })

  await page.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => window.selectedScreenQuality)).toBe('P1440_30')
})

test('shows quality choices without hiding them and lets the user click 1440p directly', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 640 })
  await page.goto('/tests/screen_profile/quality_dialog.fixture.html')

  const dialog = page.getByRole('dialog')
  const settings = dialog.locator('.screen-share-quality__settings')
  await expect(settings).toBeVisible()
  await expect(dialog.getByRole('radio', { name: '1440p' })).toBeVisible()

  const scenarioCards = dialog.locator('.screen-share-quality__scenario-option')
  await expect(scenarioCards).toHaveCount(2)
  const scenarioLegend = dialog.locator('.screen-share-quality__mode legend')
  const scenarioOptions = dialog.locator('.screen-share-quality__scenarios')
  const scenarioLegendBox = await scenarioLegend.boundingBox()
  const scenarioOptionsBox = await scenarioOptions.boundingBox()
  const bodyBox = await dialog.locator('.screen-share-setup__body').boundingBox()
  expect(scenarioOptionsBox!.y).toBeGreaterThanOrEqual(scenarioLegendBox!.y + scenarioLegendBox!.height)
  expect(scenarioOptionsBox!.width).toBeGreaterThan(bodyBox!.width * 0.9)
  for (const title of await scenarioCards.locator('.screen-share-quality__scenario-title').all()) {
    await expect(title).toBeVisible()
    expect(await title.evaluate(element => getComputedStyle(element).whiteSpace)).toBe('normal')
  }
  const labelsFit = await dialog.evaluate(element => [...element.querySelectorAll(
    '.screen-share-quality__scenario-title, .screen-share-quality__scenario-copy small, .screen-share-quality__option span',
  )].every(label => label.scrollWidth <= label.clientWidth && label.scrollHeight <= label.clientHeight))
  expect(labelsFit).toBe(true)

  for (const card of await scenarioCards.all()) {
    await expect(card).toBeInViewport({ ratio: 0.99 })
    await expect(card.locator('.screen-share-quality__scenario-title')).toBeInViewport({ ratio: 0.99 })
    await expect(card.locator('.screen-share-quality__scenario-copy small')).toBeInViewport({ ratio: 0.99 })
  }
  await page.screenshot({ path: testInfo.outputPath('screen-share-scenarios-390x640.png') })

  const resolution = dialog.getByRole('radio', { name: '1440p' })
  await resolution.click()
  await expect(resolution).toBeChecked()
  await expect(dialog.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeChecked()
  await expect(dialog.getByText('Текущий выбор: 1440p · 30 FPS', { exact: true })).toBeVisible()
  const checkedQualityOptions = dialog.locator('.screen-share-quality__option:has(input:checked)')
  for (const option of await checkedQualityOptions.all()) {
    expect(await option.evaluate(element => getComputedStyle(element).outlineStyle)).toBe('none')
  }
  await expect(scenarioCards.first()).toBeInViewport({ ratio: 0.99 })
  await expect(resolution).toBeInViewport({ ratio: 0.99 })
  await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeInViewport({ ratio: 0.99 })
  await page.screenshot({ path: testInfo.outputPath('screen-share-quality-1440p-390x640.png') })

  const resolutionSelector = dialog.locator('[aria-label="Верхний предел разрешения трансляции"]')
  const fixedFpsValue = dialog.locator('.screen-share-quality__single-value')
  await dialog.getByRole('radio', { name: /Плавность/ }).check()
  await expect(fixedFpsValue).toBeVisible()
  expect((await fixedFpsValue.boundingBox())!.width).toBeCloseTo((await resolutionSelector.boundingBox())!.width, 1)

  const body = dialog.locator('.screen-share-setup__body')
  await body.evaluate(element => { element.scrollTop = element.scrollHeight })
  await resolution.scrollIntoViewIfNeeded()
  await resolution.click()
  await expect(resolution).toBeChecked()
  await expect(resolution).toBeInViewport()
  expect(await body.evaluate(element => element.scrollTop)).toBeGreaterThan(0)

  await dialog.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => window.selectedScreenQuality)).toBe('P1440_30')
})

test('normalizes a saved 1440p60 profile to a startable 1440p30 selection', async ({ page }) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/tests/screen_profile/quality_dialog.fixture.html?profile=P1440_60')

  const dialog = page.getByRole('dialog')
  await expect(dialog.getByRole('radio', { name: '1440p' })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeChecked()
  await expect(dialog.getByText('Текущий выбор: 1440p · 30 FPS', { exact: true })).toBeVisible()
  await expect(dialog.getByRole('button', { name: 'Начать трансляцию' })).toBeEnabled()
  await dialog.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => window.selectedScreenQuality)).toBe('P1440_30')
})

test.describe('source-sized mobile chooser captures', () => {
  test.use({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 2 })

  test('captures the current actions and direct 1440p selection at 2x', async ({ page }, testInfo) => {
    await page.goto('/tests/screen_profile/quality_dialog.fixture.html')

    const dialog = page.getByRole('dialog')
    await expect(dialog).toBeVisible()
    await expect(dialog.getByRole('button', { name: 'Отмена', exact: true })).toBeVisible()
    await expect(dialog.getByRole('button', { name: 'Начать трансляцию', exact: true })).toBeVisible()
    await expect(dialog.locator('.screen-share-quality__scenario-option')).toHaveCount(2)
    await expect(dialog.getByRole('radio', { name: '720p' })).toBeVisible()
    await expect(dialog.getByRole('radio', { name: '1080p' })).toBeVisible()
    await expect(dialog.getByRole('radio', { name: '1440p' })).toBeVisible()
    await expect(dialog.locator('.screen-share-quality__single-value')).toHaveText('60 FPS')
    await page.screenshot({ path: testInfo.outputPath('mobile-stream-launch-actions-current.png') })

    await dialog.getByRole('radio', { name: '1440p' }).click()
    await expect(dialog.getByRole('radio', { name: '1440p' })).toBeChecked()
    await expect(dialog.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
    await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeChecked()
    await expect(dialog.getByText('Текущий выбор: 1440p · 30 FPS', { exact: true })).toBeVisible()
    await dialog.locator('.screen-share-setup__body').evaluate(element => { element.scrollTop = 0 })
    for (const card of await dialog.locator('.screen-share-quality__scenario-option').all()) {
      await expect(card).toBeInViewport({ ratio: 0.99 })
      await expect(card.locator('.screen-share-quality__scenario-title')).toBeInViewport({ ratio: 0.99 })
      await expect(card.locator('.screen-share-quality__scenario-copy small')).toBeInViewport({ ratio: 0.99 })
    }
    await expect(dialog.getByRole('radio', { name: '1440p' })).toBeInViewport({ ratio: 0.99 })
    await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeInViewport({ ratio: 0.99 })
    await page.screenshot({ path: testInfo.outputPath('mobile-stream-launch-settings-1440p-current.png') })
  })
})
