import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, reporter: 'list',
  outputDir: '../../../../.out/dw02-dm-starter',
  use: { baseURL: 'http://127.0.0.1:4946', headless: true, trace: 'off', video: 'off',
    launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4946 --strictPort',
    url: 'http://127.0.0.1:4946/tests/dm_starter/fixture.html', reuseExistingServer: false },
})
