import { expect, test } from '@playwright/test'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

test('scenario names stay readable and selecting 1440p chooses the supported text profile', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/tests/screen_profile/quality_dialog.fixture.html')

  const dialog = page.getByRole('dialog')
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('heading', { name: 'Демонстрация экрана' })).toBeVisible()
  const scenarios = page.locator('.screen-share-quality__scenario-option')
  await expect(scenarios).toHaveCount(2)
  await expect(page.getByRole('heading', { name: 'Качество изображения' })).toBeVisible()
  await expect(page.getByRole('radio', { name: '1440p' })).toBeVisible()
  await scenarios.first().scrollIntoViewIfNeeded()
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
  expect(fpsGroupBox?.width).toBeLessThan(resolutionGroupBox!.width)

  await page.getByRole('radio', { name: '1080p' }).focus()
  await page.keyboard.press('ArrowRight')
  await expect(page.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(resolution1440).toBeChecked()
  await expect(page.getByRole('radio', { name: '30 FPS', exact: true })).toBeVisible()
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
  for (const title of await scenarioCards.locator('.screen-share-quality__scenario-title').all()) {
    await expect(title).toBeVisible()
    expect(await title.evaluate(element => getComputedStyle(element).whiteSpace)).toBe('normal')
  }
  const labelsFit = await dialog.evaluate(element => [...element.querySelectorAll(
    '.screen-share-quality__scenario-title, .screen-share-quality__scenario-copy small, .screen-share-quality__option span',
  )].every(label => label.scrollWidth <= label.clientWidth && label.scrollHeight <= label.clientHeight))
  expect(labelsFit).toBe(true)

  await dialog.locator('.screen-share-quality__mode').scrollIntoViewIfNeeded()
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
  await page.screenshot({ path: testInfo.outputPath('screen-share-quality-1440p-390x640.png') })

  const resolutionSelector = dialog.locator('[aria-label="Верхний предел разрешения трансляции"]')
  const fixedFpsValue = dialog.locator('.screen-share-quality__single-value')
  await dialog.getByRole('radio', { name: /Плавность/ }).check()
  await expect(fixedFpsValue).toBeVisible()
  expect((await fixedFpsValue.boundingBox())!.width).toBeLessThan((await resolutionSelector.boundingBox())!.width)

  await dialog.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.evaluate(() => window.selectedScreenQuality)).toBe('P1080_60')
})
