import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000, reporter: 'list',
  outputDir: '../../../../.out/issue351/browser',
  use: { baseURL: 'http://127.0.0.1:4965', headless: true, launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: {
    cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4965 --strictPort',
    url: 'http://127.0.0.1:4965/tests/settings_hierarchy/fixture.html', reuseExistingServer: false,
  },
})
