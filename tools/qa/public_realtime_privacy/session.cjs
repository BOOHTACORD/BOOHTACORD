function delivered(sockets, before) {
  return sockets.reduce((sum, socket) => sum + socket.session, 0) > before
}

async function revokeOthers(caller, revoked, until) {
  const before = caller.sockets.reduce((sum, socket) => sum + socket.session, 0)
  const status = await caller.page.evaluate(async () => {
    const current = await fetch('/api/v1/me/sessions', { credentials: 'same-origin' })
    if (!current.ok) return current.status
    const data = await current.json()
    return (await fetch('/api/v1/me/sessions/revoke-others', { method: 'POST', credentials: 'same-origin',
      headers: { 'X-Account-ID': data.account_id } })).status
  })
  if (status !== 204) throw Error('synthetic session revocation failed')
  await until(() => delivered(caller.sockets, before), 'authorized session-state hint missing')
  await revoked.page.getByLabel('Логин', { exact: true }).waitFor({ timeout: 30000 })
  if (await revoked.page.locator('.voice-roster-member').count() !== 0) throw Error('revoked session retained roster')
}

module.exports = { delivered, revokeOthers }
