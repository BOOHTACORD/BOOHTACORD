import { defineConfig } from '@playwright/test'
import base from './playwright.config'

// Explicit local research entrypoint; it requires separately verified weights.
export default defineConfig({ ...base, testMatch: 'auto_v02.local.ts' })
