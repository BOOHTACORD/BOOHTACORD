import { defineConfig } from '@playwright/test'
import base from './playwright.config'

// This experimental test requires separately prepared, local research assets.
export default defineConfig({ ...base, testMatch: '*.research.spec.ts' })
