import { expect, test } from '@playwright/test'

test('screen-share setup keeps full scenario labels and supports the 1440p profile', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { default: ScreenShareSetupDialog } = await import('/src/voice/ScreenShareSetupDialog.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(ScreenShareSetupDialog, {
      initialProfile: 'P1080_60', onCancel: () => {},
      onStart: (profile: string) => { document.body.dataset.startedProfile = profile },
    }) }).mount('#mount')
  })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  await expect(dialog).toBeVisible()
  for (const label of ['Плавность', 'Игры и видео · 60 FPS', 'Чёткость текста', 'Документы и код · 15–30 FPS']) {
    await expect(dialog.getByText(label, { exact: true })).toBeVisible()
  }

  const scenarioTitles = dialog.locator('.screen-share-quality__scenario-title')
  await expect(scenarioTitles).toHaveCount(2)
  for (const title of await scenarioTitles.all()) {
    const dimensions = await title.evaluate((element) => ({
      clientWidth: element.clientWidth,
      scrollWidth: element.scrollWidth,
      textOverflow: getComputedStyle(element).textOverflow,
    }))
    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth)
    expect(dimensions.textOverflow).not.toBe('ellipsis')
  }

  const resolutionOption = dialog.locator('.screen-share-quality__option').filter({ hasText: '1440p' })
  const labelBounds = await resolutionOption.boundingBox()
  const radioBounds = await resolutionOption.locator('input').boundingBox()
  expect(labelBounds).not.toBeNull()
  expect(radioBounds).not.toBeNull()
  expect(radioBounds!.width).toBeGreaterThanOrEqual(labelBounds!.width - 2)
  expect(radioBounds!.height).toBeGreaterThanOrEqual(labelBounds!.height - 2)

  await resolutionOption.click()
  await expect(dialog.getByRole('radio', { name: '1440p' })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: /Чёткость текста/ })).toBeChecked()
  await expect(dialog.getByRole('radio', { name: '30 FPS', exact: true })).toBeChecked()
  await expect(dialog.getByText('Текущий выбор: 1440p · 30 FPS', { exact: true })).toBeVisible()
  await page.screenshot({ path: testInfo.outputPath('screen-share-quality-1440p.png') })

  await dialog.getByRole('button', { name: 'Начать трансляцию' }).click()
  await expect.poll(() => page.locator('body').getAttribute('data-started-profile')).toBe('P1440_30')
})
