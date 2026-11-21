import { defineConfig } from '@playwright/test'
import { fileURLToPath } from 'node:url'

export default defineConfig({
  testDir: '.', testMatch: 'fallback.browser.spec.ts', workers: 1, timeout: 30000, reporter: 'list',
  outputDir: '../../../../.out/issue790/firefox',
  use: { browserName: 'firefox', baseURL: 'http://127.0.0.1:4968', viewport: { width: 1440, height: 900 } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4968 --strictPort',
    url: 'http://127.0.0.1:4968/tests/system_activity_fallback/fallback.html', reuseExistingServer: false },
})
