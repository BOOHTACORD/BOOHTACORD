import { ScreenPublisherOperationError } from './screen_publisher/types'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { screenCaptureUnavailableMessage } from './screen_capture_support'

export function screenFailureMessage(cause: unknown, userAgent?: string): string {
  for (let depth = 0; depth < 4 && cause instanceof ScreenPublisherOperationError && !cause.recovery; depth++) {
    cause = cause.operationCause
  }
  const name = cause instanceof Error ? cause.name : ''
  if (name === 'DeviceUnsupportedError') return screenCaptureUnavailableMessage(userAgent)
  if (name === 'AbortError') return 'Выбор источника отменён. Откройте демонстрацию снова и выберите окно, экран или вкладку.'
  if (name === 'NotAllowedError') return 'Браузер запретил захват экрана. Разрешите его в Chrome и повторите выбор источника.'
  if (name === 'NotReadableError') return 'Источник недоступен для захвата. Закройте конфликтующее приложение или выберите другой источник.'
  return 'Демонстрация не начата: браузер или сеть не вернули техническую причину. Повторите действие или выберите другой источник.'
}

export function screenDiagnosticMessage(diagnostics: ScreenDiagnostics): string | null {
  if (diagnostics.source === 'ENDED') return 'Источник демонстрации завершён. Выберите его снова, чтобы продолжить показ.'
  if (diagnostics.profileCheck?.status === 'failed') return 'Не удалось удержать выбранное качество демонстрации. Выберите качество заново или перезапустите показ.'
  if (diagnostics.audioTrack === 'ABSENT') return 'Демонстрация идёт без аудиодорожки. При необходимости выберите источник, для которого picker предлагает звук; голосовой канал остаётся активен.'
  if (diagnostics.adaptationReason === 'bandwidth' || diagnostics.connectionQuality === 'POOR' || diagnostics.connectionQuality === 'LOST') {
    return 'Сеть ограничивает демонстрацию. Голос имеет приоритет; проверьте соединение и обновите измерения.'
  }
  return null
}
