import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: '*.browser.spec.ts',
  workers: 1,
  timeout: 30000,
  reporter: 'list',
  outputDir: '../../build/password-reset-visibility-results',
  projects: [
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'desktop', use: { viewport: { width: 1440, height: 900 } } },
  ],
  use: {
    baseURL: 'http://127.0.0.1:4803',
    headless: true,
    trace: 'off',
    screenshot: 'off',
    video: 'off',
    launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH },
  },
  webServer: {
    cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4803 --strictPort',
    url: 'http://127.0.0.1:4803/tests/password_reset_visibility/fixture.html',
    reuseExistingServer: false,
  },
})
