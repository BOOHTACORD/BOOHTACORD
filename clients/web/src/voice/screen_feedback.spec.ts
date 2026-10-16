import { ScreenPublisherOperationError } from './screen_publisher/adapter'
import { describe, expect, it } from 'vitest'

import { screenFailureMessage } from './screen_feedback'

describe('screen feedback', () => {
  it.each([
    ['AbortError', 'Выбор источника отменён'],
    ['NotAllowedError', 'Браузер запретил захват экрана'],
    ['NotReadableError', 'Источник недоступен для захвата'],
  ])('keeps %s distinct', (name, message) => {
    expect(screenFailureMessage(Object.assign(new Error(), { name }))).toContain(message)
  })
})

// The real publisher wraps browser failures; preserve actionable feedback at that boundary.
describe('wrapped publisher permission feedback', () => {
  it('retains the browser denial instead of replacing it with an unknown failure', () => {
    const cause = new ScreenPublisherOperationError('failure', 'synthetic operation', undefined, Object.assign(new Error('synthetic private text'), { name: 'NotAllowedError' }))
    expect(screenFailureMessage(cause)).toContain('Браузер запретил захват экрана')
    expect(screenFailureMessage(cause)).not.toContain('synthetic private text')
  })
})
