import { browserRuntime } from '../browser_runtime/workers'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', ...browserRuntime(), timeout: 30000, reporter: 'list',
  outputDir: '../../../../.out/issue343/browser',
  use: { baseURL: 'http://127.0.0.1:4954', headless: true },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4954 --strictPort',
    url: 'http://127.0.0.1:4954/tests/microcopy/fixture.html', reuseExistingServer: false },
})
