import { defineConfig } from '@playwright/test'
import { fileURLToPath } from 'node:url'
export default defineConfig({ testDir: '.', testMatch: 'boundary.browser.spec.ts', workers:1, reporter:'list', outputDir:'../../../../.out/qa327-browser', use:{baseURL:'http://127.0.0.1:5087',headless:true,trace:'off',screenshot:'off',video:'off'}, webServer:{cwd:fileURLToPath(new URL('../../',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5087 --strictPort',url:'http://127.0.0.1:5087/tests/track_name/fixture.html',reuseExistingServer:false} })
