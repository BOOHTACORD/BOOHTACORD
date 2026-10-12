import {createRequire} from 'node:module'
import {fileURLToPath} from 'node:url'
const require=createRequire(new URL('../../../clients/web/package.json',import.meta.url))
const {defineConfig}=require('@playwright/test')
export default defineConfig({
 testDir:'../../../clients/web/tests/accessibility',testMatch:['topology_pending_focus.browser.spec.ts','admin_filter_readability.browser.spec.ts'],workers:1,timeout:30000,reporter:'list',
 outputDir:'../../../.out/qa295298-20261012/pending-component',
 use:{baseURL:'http://127.0.0.1:4957',headless:true},
 webServer:{cwd:fileURLToPath(new URL('../../../clients/web',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4957 --strictPort',url:'http://127.0.0.1:4957/',reuseExistingServer:false},
})
