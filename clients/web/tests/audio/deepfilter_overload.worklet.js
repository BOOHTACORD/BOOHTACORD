// Fault injection only: model preflight stays real; this graph reports overload.
class OverloadProbe extends AudioWorkletProcessor {
  constructor() {
    super(); this.enabled = false; this.failed = false; this.frames = 0; this.alive = true
    this.port.onmessage = ({ data }) => {
      if (data.type === 'unmute') { this.enabled = true; this.port.postMessage({ type: 'unmuted', intent: data.intent }) }
      if (data.type === 'mute') this.enabled = false
      if (data.type === 'destroy') { this.alive = false; this.port.postMessage({ type: 'destroyed' }) }
    }
    this.port.postMessage({ type: 'ready', frameSize: 480 })
  }
  process(_inputs, outputs) {
    outputs[0]?.[0]?.fill(0)
    if (this.enabled && !this.failed && ++this.frames === 80) {
      this.failed = true; this.port.postMessage({ type: 'error', reason: 'overload' })
    }
    return this.alive
  }
}
registerProcessor('boohtacord-deepfilter-research', OverloadProbe)
