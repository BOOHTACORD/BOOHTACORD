/* Actual browser WebRTC endpoints. Capture is synthetic; transport is not. */
LivekitClient.setLogLevel('silent')
window.media = { disconnected: false, removed: 0, refreshed: null }
window.connectMedia = async (url, token) => {
  const room = new LivekitClient.Room({ adaptiveStream: false, dynacast: false })
  window.media.room = room
  room.engine.on('tokenRefreshed', fresh => {
    if (fresh !== token) window.media.refreshed = fresh
  })
  room.on(LivekitClient.RoomEvent.Disconnected, () => {
    window.media.disconnected = true
    document.querySelector('#state').textContent = 'disconnected'
  })
  room.on(LivekitClient.RoomEvent.TrackSubscribed, track => {
    if (track.kind === 'video') {
      window.media.video = track
      track.attach(document.querySelector('#video'))
    } else {
      window.media.audio = track
      const element = track.attach(); element.volume = 0.02
      document.body.append(element)
    }
  })
  room.on(LivekitClient.RoomEvent.TrackUnsubscribed, track => {
    window.media.removed++
    track.detach().forEach(element => { if (element.tagName === 'VIDEO') element.srcObject=null; else element.remove() })
  })
  await room.connect(url, token, { autoSubscribe: true })
  document.querySelector('#state').textContent = 'connected'
}
window.publishSynthetic = async () => {
  const canvas = document.createElement('canvas'); canvas.width=640; canvas.height=360
  const context=canvas.getContext('2d'); let frame=0
  window.media.timer=setInterval(() => {
    context.fillStyle=frame%60<30?'#123c60':'#17643f'; context.fillRect(0,0,640,360)
    context.fillStyle='white'; context.font='24px sans-serif'; context.fillText('POC-03 / synthetic media',20,40)
    context.fillRect((frame++*7)%600,160,40,40)
  }, 33)
  const video = new LivekitClient.LocalVideoTrack(canvas.captureStream(30).getVideoTracks()[0])
  const audioContext=new AudioContext(); await audioContext.resume()
  const oscillator=audioContext.createOscillator(), gain=audioContext.createGain(), destination=audioContext.createMediaStreamDestination()
  oscillator.frequency.value=440; gain.gain.value=0.03; oscillator.connect(gain).connect(destination); oscillator.start()
  window.media.audioContext=audioContext
  await window.media.room.localParticipant.publishTrack(video, { source: LivekitClient.Track.Source.ScreenShare })
  await window.media.room.localParticipant.publishTrack(new LivekitClient.LocalAudioTrack(destination.stream.getAudioTracks()[0]), { source: LivekitClient.Track.Source.ScreenShareAudio })
}
window.mediaObservation = async () => {
  const video=document.querySelector('#video')
  const audio=window.media.audio
  const stats=audio?.receiver ? [...(await audio.receiver.getStats()).values()] : []
  return {
    decoded_frames:video.getVideoPlaybackQuality().totalVideoFrames,
    audio_packets:stats.filter(s=>s.type==='inbound-rtp').reduce((n,s)=>n+(s.packetsReceived||0),0),
    presenter_disconnected:window.media.disconnected,
    removed:window.media.removed,
    observer_connected:window.media.room.state==='connected',
  }
}
window.disposeMedia = async () => {
  clearInterval(window.media.timer)
  await window.media.room?.disconnect()
  await window.media.audioContext?.close()
}
