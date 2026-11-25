export function uploadFailureMessage(cause: unknown): string {
  if (typeof cause === 'object' && cause !== null && 'status' in cause && cause.status === 507 &&
      'code' in cause && cause.code === 'INSUFFICIENT_STORAGE') {
    return 'Недостаточно места на сервере. Повторите загрузку, когда место освободится.'
  }
  return cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.'
}
