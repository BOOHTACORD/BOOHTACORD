import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { describe, expect, it } from 'vitest'

describe('receiver audio meter', () => {
  it('reports timed silence when the connected source has no input channels', () => {
    const messages: any[] = []
    let Meter: any
    class Base { port = { postMessage: (value: unknown) => messages.push(value), onmessage: null } }
    runInNewContext(readFileSync(new URL('./meter.worklet.js', import.meta.url), 'utf8'), {
      AudioWorkletProcessor: Base, registerProcessor: (_: string, value: any) => { Meter = value },
    })
    const meter = new Meter()
    for (let i = 0; i < 38; i++) meter.process([[]], [[new Float32Array(128)]])
    expect(messages).toHaveLength(1)
    expect(messages[0]).toMatchObject({ samples: 4864, peak: 0, rms: 0, missingSamples: 4864 })
    for (let i = 0; i < 38; i++) meter.process([[new Float32Array(128).fill(0.25)]], [[new Float32Array(128)]])
    expect(messages[1]).toMatchObject({ samples: 4864, peak: 0.25, rms: 0.25, missingSamples: 0 })
  })
})
