function received(before, sample) {
  return Number.isFinite(before) && Number.isFinite(sample?.packets) &&
    sample.packets > before && sample.elements === 1
}

async function sample(page) {
  return page.evaluate(async () => {
    let packets = 0
    for (const peer of window.__qaPeers) {
      const stats = await peer.getStats()
      stats.forEach(row => {
        if (row.type === 'inbound-rtp' && row.kind === 'audio' && !row.isRemote) packets += row.packetsReceived || 0
      })
    }
    const elements = [...document.querySelectorAll('audio')].filter(element =>
      element.srcObject?.getAudioTracks().some(track => track.readyState === 'live')).length
    return { packets, elements }
  })
}

async function exercise(receiver, until, capture) {
  const before = await sample(receiver)
  await until(async () => received(before.packets, await sample(receiver)), 'audio packets or playback element missing')
  await capture('audio-received')
}

module.exports = { received, exercise }
