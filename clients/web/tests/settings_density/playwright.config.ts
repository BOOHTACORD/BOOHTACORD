import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000, reporter: 'list',
  outputDir: '../../../../.out/issue351/browser',
  use: { baseURL: 'http://127.0.0.1:4962', headless: true },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4962 --strictPort',
    url: 'http://127.0.0.1:4962/tests/settings_density/fixture.html', reuseExistingServer: false },
})
