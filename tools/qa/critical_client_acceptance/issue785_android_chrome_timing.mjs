export const ISSUE785_ANDROID_CHROME_BACKGROUND_SECONDS = 120
export const ISSUE785_ANDROID_CHROME_BACKGROUND_MS = ISSUE785_ANDROID_CHROME_BACKGROUND_SECONDS * 1000

export function backgroundElapsedSeconds(startedAtMs, resumedAtMs) {
  return Math.max(0, (resumedAtMs - startedAtMs) / 1000)
}

export function waitForIssue785AndroidChromeBackground(
  sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds)),
) {
  return sleep(ISSUE785_ANDROID_CHROME_BACKGROUND_MS)
}
