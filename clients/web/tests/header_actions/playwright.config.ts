import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
 testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 45000, reporter: 'list',
 outputDir: '../../../../.out/issue352/browser',
 use: { baseURL: 'http://127.0.0.1:4966', viewport: { width:1440, height:900 }, trace:'off', screenshot:'off', video:'off' },
 webServer: { cwd:fileURLToPath(new URL('../../',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4966 --strictPort', url:'http://127.0.0.1:4966/tests/header_actions/fixture.html',reuseExistingServer:false },
})
