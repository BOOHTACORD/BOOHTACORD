import { expect, test } from '@playwright/test'

test('component fixtures use the application Pinia module', async ({ page }) => {
  await page.goto('/')
  const sameModule = await page.evaluate(async () => {
    const source = await (await fetch('/src/authorization/permission_store.ts')).text()
    const appImport = source.match(/\/node_modules\/\.vite\/deps\/pinia\.js\?v=[\w]+/)?.[0]
    if (!appImport) throw new Error('Could not identify the application Pinia import')
    const fixture = await import('/tests/browser_runtime/fixture_dependencies.ts')
    const app = await import(/* @vite-ignore */ appImport)
    return fixture.createPinia === app.createPinia
  })
  expect(sameModule).toBe(true)
})
