import { test } from 'node:test'
import assert from 'node:assert/strict'
import { androidChromeAdbArgs } from './issue785_android_chrome_device.mjs'

test('scopes Android Chrome ADB calls to the selected AVD', () => {
  assert.deepEqual(
    androidChromeAdbArgs('emulator-5554', 'shell', 'input', 'keyevent', '3'),
    ['-s', 'emulator-5554', 'shell', 'input', 'keyevent', '3'],
  )
})

test('rejects physical device serials for the Android Chrome AVD runner', () => {
  assert.throws(
    () => androidChromeAdbArgs('2B240DLH2000HP', 'shell', 'getprop'),
    /requires the selected AVD serial/,
  )
})
