import { defineConfig } from '@playwright/test'
import { fileURLToPath } from 'node:url'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000, reporter: 'list',
  outputDir: '../../../../.out/issue350/browser',
  use: { baseURL: 'http://127.0.0.1:4964', viewport: { width: 1440, height: 900 }, trace: 'off', screenshot: 'off', video: 'off' },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4964 --strictPort', url: 'http://127.0.0.1:4964/tests/member_roster/fixture.html', reuseExistingServer: false },
})
