import { defineConfig } from '@playwright/test'
import base from './playwright.config'
// Explicit local assets and a private SFU are required; never download models here.
export default defineConfig({ ...base, testMatch: 'auto_preflight.local.ts' })
