import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: 'metadata_diagnostics.browser.spec.ts', workers: 1,
  timeout: 30000, reporter: 'list', outputDir: '../../../../.out/qa328-reader-browser-results',
  use: { baseURL: 'http://127.0.0.1:5097', headless: true, trace: 'off', video: 'off', screenshot: 'off', launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5097 --strictPort', url: 'http://127.0.0.1:5097/tests/screen_profile/metadata_diagnostics.fixture.html', reuseExistingServer: false },
})
