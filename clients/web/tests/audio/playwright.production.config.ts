import { defineConfig } from '@playwright/test'
import base from './playwright.config'

// No research asset directory or feature flags: this is the ordinary delivery.
export default defineConfig({ ...base,
  testMatch: ['rnnoise.browser.spec.ts', 'deepfilter_track.research.spec.ts', 'deepfilter_preflight.research.spec.ts'],
})
