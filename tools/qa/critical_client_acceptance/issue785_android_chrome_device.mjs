const AVD_SERIAL = /^emulator-\d+$/

export function androidChromeAdbArgs(device, ...args) {
  if (!AVD_SERIAL.test(device ?? '')) {
    throw new Error('Issue 785 Android Chrome QA requires the selected AVD serial')
  }
  return ['-s', device, ...args]
}
