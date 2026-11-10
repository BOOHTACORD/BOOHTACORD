function statusMatches(prejoin, sidebar, muted) {
  const allowed = muted ? ['Микрофон выключен'] : ['В голосовом канале', 'Говорит']
  return allowed.includes(prejoin) && allowed.includes(sidebar)
}

async function exercise(sender, observer, until, capture) {
  const dock = sender.getByTestId('voice-dock')
  const status = scope => observer.locator(`${scope} .voice-roster-member`)
    .filter({ has: observer.getByText('qa_admin', { exact: true }) }).locator('.voice-person-state')
  const matches = async muted => statusMatches(await status('.voice-prejoin').getAttribute('aria-label'),
    await status('.sidebar').getAttribute('aria-label'), muted)
  await until(() => sender.evaluate(() => window.__qaPeers.some(peer => peer.getSenders().some(sender =>
    sender.track?.kind === 'audio' && sender.track.readyState === 'live'))), 'synthetic microphone track missing')
  const enable = dock.getByRole('button', { name: 'Включить микрофон', exact: true })
  if (await enable.isVisible()) await enable.click()
  await until(() => matches(false), 'unmuted roster status missing')
  await dock.getByRole('button', { name: 'Выключить микрофон', exact: true }).click()
  await until(() => matches(true), 'muted roster status missing')
  await capture('microphone-muted')
  await dock.getByRole('button', { name: 'Включить микрофон', exact: true }).click()
  await until(() => matches(false), 'unmuted roster status did not recover')
  await capture('microphone-unmuted')
}

module.exports = { statusMatches, exercise }
