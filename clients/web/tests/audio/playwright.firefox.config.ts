import { defineConfig } from '@playwright/test'
import base from './playwright.config'

// Keep Chromium's device/autoplay flags out of Firefox's command line.
export default defineConfig({
  ...base,
  use: { ...base.use, browserName: 'firefox', launchOptions: { args: [],
    firefoxUserPrefs: { 'media.autoplay.default': 0, 'media.navigator.streams.fake': true, 'media.navigator.permission.disabled': true } } },
})
