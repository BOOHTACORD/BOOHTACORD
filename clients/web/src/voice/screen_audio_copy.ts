interface ScreenAudioState {
  isLocal: boolean
  hasAudio: boolean
  adjustable: boolean
}

export function screenAudioMessage({ isLocal, hasAudio, adjustable }: ScreenAudioState): string {
  if (isLocal) return 'Предпросмотр собственного экрана без звука.'
  if (!hasAudio) return 'У демонстрации нет аудиодорожки.'
  if (!adjustable) return 'Аудиодорожка есть; личная настройка громкости недоступна.'
  return ''
}

export function participantAudioMessage(deafened: boolean): string {
  return deafened ? 'Удалённый звук выключен.' : 'Звук участников управляется отдельно от демонстрации.'
}
