/** Two deterministic local input devices. Only synthetic tones enter getUserMedia. */
export function installSyntheticInputs() {
  const available = new Set(['mic-1', 'mic-2'])
  const captures: { deviceId: string; track: MediaStreamTrack }[] = []
  const originalCapture = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices)
  const originalDevices = navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices)
  navigator.mediaDevices.enumerateDevices = async () => [...available].map(deviceId => ({
    deviceId, kind: 'audioinput', label: deviceId === 'mic-1' ? 'Первый микрофон' : 'Второй микрофон', groupId: 'synthetic',
    toJSON() { return this },
  }) as MediaDeviceInfo)
  navigator.mediaDevices.getUserMedia = async (constraints) => {
    const audio = constraints?.audio
    const requested = audio && typeof audio === 'object' ? audio.deviceId : undefined
    const deviceId = typeof requested === 'string' ? requested : Array.isArray(requested) ? requested[0] : requested && typeof requested === 'object' ? String(requested.exact ?? requested.ideal ?? 'default') : 'default'
    const selected = deviceId === 'default' ? [...available][0] : deviceId
    if (!available.has(selected)) throw new DOMException('Synthetic input unavailable', 'NotFoundError')
    const context = new AudioContext({ sampleRate: 48000 })
    await context.resume()
    const source = context.createOscillator(), gain = context.createGain(), destination = context.createMediaStreamDestination()
    source.frequency.value = selected === 'mic-1' ? 440 : 880
    gain.gain.value = 0.15
    source.connect(gain); gain.connect(destination); source.start()
    const track = destination.stream.getAudioTracks()[0]
    const settings = track.getSettings.bind(track), stop = track.stop.bind(track)
    // Model the capture API's reported settings; the oscillator has no real NS.
    let suppression = !!(audio && typeof audio === 'object' && audio.noiseSuppression === true)
    track.applyConstraints = async value => { if (typeof value?.noiseSuppression === 'boolean') suppression = value.noiseSuppression }
    track.getSettings = () => ({ ...settings(), deviceId: selected, noiseSuppression: suppression, echoCancellation: false, autoGainControl: false })
    track.stop = () => { if (track.readyState === 'ended') return; stop(); source.stop(); void context.close() }
    captures.push({ deviceId: selected, track })
    return destination.stream
  }
  return {
    captures,
    unplug(deviceId: string) {
      available.delete(deviceId)
      for (const capture of captures) if (capture.deviceId === deviceId && capture.track.readyState === 'live') {
        capture.track.stop(); capture.track.dispatchEvent(new Event('ended'))
      }
      navigator.mediaDevices.dispatchEvent(new Event('devicechange'))
    },
    removeAll() { for (const deviceId of [...available]) this.unplug(deviceId) },
    dispose() {
      navigator.mediaDevices.getUserMedia = originalCapture
      navigator.mediaDevices.enumerateDevices = originalDevices
      for (const capture of captures) if (capture.track.readyState !== 'ended') capture.track.stop()
    },
  }
}
