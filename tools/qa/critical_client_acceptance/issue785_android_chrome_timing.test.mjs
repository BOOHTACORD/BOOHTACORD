import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  ISSUE785_ANDROID_CHROME_BACKGROUND_MS,
  ISSUE785_ANDROID_CHROME_BACKGROUND_SECONDS,
  backgroundElapsedSeconds,
  waitForIssue785AndroidChromeBackground,
} from './issue785_android_chrome_timing.mjs'

test('uses a two-minute Android Chrome issue 785 reproduction window', async () => {
  assert.equal(ISSUE785_ANDROID_CHROME_BACKGROUND_MS, 120_000)
  assert.equal(ISSUE785_ANDROID_CHROME_BACKGROUND_SECONDS, 120)

  const waits = []
  await waitForIssue785AndroidChromeBackground(async milliseconds => { waits.push(milliseconds) })

  assert.deepEqual(waits, [120_000])
})

test('reports observed background time from the runner monotonic clock', () => {
  assert.equal(backgroundElapsedSeconds(10_000, 130_000), 120)
})
