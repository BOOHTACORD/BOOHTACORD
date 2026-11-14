import { defineConfig } from '@playwright/test'
import base from './playwright.config'
import { fileURLToPath } from 'node:url'
// Explicit local assets and a private SFU are required; never download models here.
const stamp = new Date().toISOString().replace(/[^0-9]/g, '')
export default defineConfig({ ...base, testMatch: 'auto_preflight.local.ts',
  reporter: [['list'], ['json', { outputFile: fileURLToPath(new URL(`../../../../.out/audio-research/auto-preflight-${stamp}.json`, import.meta.url)) }]],
})
