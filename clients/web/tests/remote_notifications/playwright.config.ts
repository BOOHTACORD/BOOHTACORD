import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 60000, reporter: 'list',
  outputDir: '../../../../.out/notify554/browser', use: { baseURL: 'http://127.0.0.1:5178', headless: true },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5178 --strictPort', url: 'http://127.0.0.1:5178/tests/remote_notifications/fixture.html', reuseExistingServer: false },
})
