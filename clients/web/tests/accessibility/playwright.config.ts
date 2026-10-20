import { browserRuntime } from '../browser_runtime/workers'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: '*.browser.spec.ts',
  ...browserRuntime(),
  timeout: 30000,
  reporter: 'list',
  outputDir: '../../../../.out/accessibility-browser-results',
  use: {
    baseURL: 'http://127.0.0.1:5175',
    headless: true,
    launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH },
  },
  webServer: {
    cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5175 --strictPort',
    url: 'http://127.0.0.1:5175/',
    reuseExistingServer: false,
  },
})
