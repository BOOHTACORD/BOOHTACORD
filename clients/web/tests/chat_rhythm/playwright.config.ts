import { browserRuntime } from '../browser_runtime/workers'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({testDir:'.',testMatch:'*.browser.spec.ts',...browserRuntime(),timeout:30000,reporter:'list',outputDir:process.env.CHAT_RHYTHM_OUTPUT??'../../../../.out/issue345/browser',
  use:{baseURL:'http://127.0.0.1:4957',headless:true,timezoneId:'UTC'},
  webServer:{cwd:fileURLToPath(new URL('../../',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4957 --strictPort',url:'http://127.0.0.1:4957/tests/chat_rhythm/fixture.html',reuseExistingServer:false}})
