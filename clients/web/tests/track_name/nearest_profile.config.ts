import { defineConfig } from '@playwright/test'
import base from '../screen_profile/playwright.config'
export default defineConfig({ ...base, testDir:'../screen_profile', outputDir:'../../../../.out/qa327-profile-browser', use:{...base.use,baseURL:'http://127.0.0.1:5087'},webServer:{...(base.webServer as object),command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5087 --strictPort',url:'http://127.0.0.1:5087/tests/screen_profile/fixture.html'} })
