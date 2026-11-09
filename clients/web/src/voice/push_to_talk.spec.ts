import { describe, expect, it } from 'vitest'

import { PushToTalk, type KeyboardInput, type KeyboardEventLike } from './push_to_talk'

class EventHub implements KeyboardInput {
  private readonly listeners = new Map<string, Array<(event: KeyboardEventLike) => void>>()

  addEventListener(type: string, listener: (event: KeyboardEventLike) => void): void {
    this.listeners.set(type, [...(this.listeners.get(type) ?? []), listener])
  }

  removeEventListener(type: string, listener: (event: KeyboardEventLike) => void): void {
    this.listeners.set(type, (this.listeners.get(type) ?? []).filter((value) => value !== listener))
  }

  emit(type: string, event: Partial<KeyboardEventLike> = {}): void {
    const complete = { code: 'KeyV', preventDefault: () => undefined, target: null, ...event }
    for (const listener of this.listeners.get(type) ?? []) listener(complete)
  }
}

describe('push to talk', () => {
  it('releases on key-up, blur and page visibility loss', () => {
    const source = new EventHub()
    const states: boolean[] = []
    const ptt = new PushToTalk(source, 'KeyV', (pressed) => states.push(pressed))
    ptt.start()

    source.emit('keydown')
    source.emit('keyup')
    source.emit('keydown')
    source.emit('blur')
    source.emit('keydown')
    source.emit('visibilitychange')

    expect(states).toEqual([true, false, true, false, true, false])
  })

  it('does not capture the configured key inside a field or modal', () => {
    const source = new EventHub()
    const states: boolean[] = []
    const ptt = new PushToTalk(source, 'KeyV', (pressed) => states.push(pressed))
    ptt.start()

    source.emit('keydown', { target: { closest: () => ({}) } })
    source.emit('keydown', { target: { closest: (selector) => selector.includes('button') ? {} : null } })
    source.emit('keydown', { target: { closest: (selector) => selector.includes('select') ? {} : null } })

    expect(states).toEqual([])
  })
})
