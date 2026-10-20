import { browserRuntime } from '../browser_runtime/workers'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir:'.',testMatch:'*.browser.spec.ts',...browserRuntime(),timeout:30000,reporter:'list',
  outputDir:'../../../../.out/message-social-browser-results',
  use:{baseURL:'http://127.0.0.1:4827',headless:true,trace:'off',screenshot:'off',video:'off',launchOptions:{executablePath:process.env.CHROMIUM_EXECUTABLE_PATH}},
  webServer:{cwd:fileURLToPath(new URL('../../',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4827 --strictPort',url:'http://127.0.0.1:4827/tests/message_social/fixture.html',reuseExistingServer:false},
})
