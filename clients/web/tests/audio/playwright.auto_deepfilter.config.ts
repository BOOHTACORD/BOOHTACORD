import { defineConfig } from '@playwright/test'
import base from './playwright.config'

// Local research only; requires separately verified DeepFilter assets.
export default defineConfig({ ...base, testMatch: 'auto_deepfilter.local.ts' })
