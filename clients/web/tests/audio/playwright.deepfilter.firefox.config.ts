import { defineConfig } from '@playwright/test'
import base from './playwright.firefox.config'

export default defineConfig({ ...base, testMatch: '*.research.spec.ts' })
