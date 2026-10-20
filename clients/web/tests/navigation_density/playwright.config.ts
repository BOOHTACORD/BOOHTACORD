import { browserRuntime } from '../browser_runtime/workers'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', ...browserRuntime(), timeout: 30000, reporter: 'list',
  outputDir: process.env.NAVIGATION_OUTPUT ?? '../../../../.out/issue344/browser',
  use: { baseURL: 'http://127.0.0.1:4956', headless: true },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4956 --strictPort', url: 'http://127.0.0.1:4956/tests/navigation_density/fixture.html', reuseExistingServer: false },
})
