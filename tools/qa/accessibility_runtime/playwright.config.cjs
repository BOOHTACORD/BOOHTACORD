const {resolve} = require('node:path');
const web = resolve(__dirname, '../../../clients/web');
const {defineConfig} = require(resolve(web, 'node_modules/@playwright/test'));
module.exports = defineConfig({testDir:resolve(web, 'tests/accessibility'),testMatch:['history_log.browser.spec.ts','voice_participant_status.browser.spec.ts'],workers:1,timeout:30000,reporter:'list',outputDir:resolve(__dirname,'../../../.out/qa301-focused-browser'),use:{baseURL:'http://127.0.0.1:4937',headless:true,launchOptions:{executablePath:process.env.CHROMIUM_EXECUTABLE_PATH}},webServer:{cwd:web,command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4937 --strictPort',url:'http://127.0.0.1:4937',reuseExistingServer:false}});
