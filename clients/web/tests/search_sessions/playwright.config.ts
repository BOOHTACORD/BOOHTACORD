import {fileURLToPath} from 'node:url'
import {defineConfig} from '@playwright/test'
export default defineConfig({
 testDir:'.',testMatch:'*.browser.spec.ts',workers:1,timeout:30000,reporter:'list',outputDir:'../../../../.out/qa294-search-session-browser',
 use:{baseURL:'http://127.0.0.1:4945',headless:true,trace:'off',screenshot:'off',video:'off',viewport:{width:393,height:852}},
 webServer:{cwd:fileURLToPath(new URL('../../',import.meta.url)),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4945 --strictPort',url:'http://127.0.0.1:4945/tests/search_sessions/fixture.html',reuseExistingServer:false},
})
