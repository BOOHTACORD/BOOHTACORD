import { defineConfig } from '@playwright/test'
import base from './playwright.deepfilter.config'

export default defineConfig({ ...base, use: { ...base.use, launchOptions: {
  args: ['--autoplay-policy=no-user-gesture-required', '--use-fake-device-for-media-stream',
    '--use-fake-ui-for-media-stream', '--mute-audio'],
  executablePath: process.env.CHROMIUM_EXECUTABLE_PATH,
} } })
