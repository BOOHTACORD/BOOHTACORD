// Approved synthetic capture only: the production client still admits, publishes,
// subscribes and renders through its real API and LiveKit transports.
export function installSyntheticCapture() {
  window.__qaSource = { frames: 0, captures: 0 }
  navigator.mediaDevices.getDisplayMedia = async () => {
    window.__qaSource.captures++
    const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 360
    const c = canvas.getContext('2d'), sound = new AudioContext()
    const oscillator = sound.createOscillator(), gain = sound.createGain(), destination = sound.createMediaStreamDestination()
    oscillator.frequency.value = 440; gain.gain.value = .02
    oscillator.connect(gain).connect(destination); oscillator.start(); await sound.resume()
    const timer = setInterval(() => {
      const n = ++window.__qaSource.frames
      c.fillStyle = n % 2 ? '#163d62' : '#1d6144'; c.fillRect(0, 0, 640, 360)
      c.fillStyle = '#fff'; c.font = '32px sans-serif'; c.fillText('QA SCREEN / ' + n, 24, 70)
      c.fillRect(24 + n % 500, 140, 50, 50)
    }, 33)
    const stream = canvas.captureStream(30); destination.stream.getAudioTracks().forEach(t => stream.addTrack(t))
    stream.getVideoTracks()[0].addEventListener('ended', () => { clearInterval(timer); oscillator.stop(); sound.close() })
    window.__qaCapture = { stream, timer, sound, oscillator }
    return stream
  }
}
export function installPeerObservation() {
  window.__qaPeers = []
  const Native = window.RTCPeerConnection
  window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
    const peer = Reflect.construct(target, args); window.__qaPeers.push(peer); return peer
  } })
}
