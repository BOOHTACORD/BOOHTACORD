import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: '*.browser.spec.ts',
  workers: 1,
  timeout: 30000,
  reporter: 'list',
  outputDir: '../../../../.out/auth-session-retention-browser',
  use: {
    baseURL: 'http://localhost:4968',
    headless: true,
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
  webServer: {
    cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4968 --strictPort',
    url: 'http://localhost:4968/tests/auth_session_retention/fixture.html',
    reuseExistingServer: false,
  },
})
