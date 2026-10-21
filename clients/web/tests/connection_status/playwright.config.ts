import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: '*.browser.spec.ts',
  workers: 1,
  reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:4814', headless: true },
  webServer: {
    cwd: process.cwd(),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4814 --strictPort',
    url: 'http://127.0.0.1:4814/tests/connection_status/fixture.html',
  },
})
