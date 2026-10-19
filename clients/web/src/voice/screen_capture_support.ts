export function screenCaptureSupported(
  userAgent: string = typeof navigator === 'undefined' ? '' : navigator.userAgent,
  mediaDevices: { getDisplayMedia?: unknown } | undefined = typeof navigator === 'undefined' ? undefined : navigator.mediaDevices,
): boolean {
  if (/Android/i.test(userAgent) && /Chrome\//i.test(userAgent)) return false
  return typeof mediaDevices?.getDisplayMedia === 'function'
}

export function screenCaptureUnavailableMessage(
  userAgent: string = typeof navigator === 'undefined' ? '' : navigator.userAgent,
): string {
  if (/Android/i.test(userAgent)) return 'В браузере Android нельзя начать трансляцию экрана. Откройте приложение BOOHTACORD.'
  return 'Этот браузер не поддерживает показ экрана. Используйте браузер на ПК с доступным захватом экрана.'
}
