import { expect } from '../client_lifecycle/request.mjs'

export async function connected(page) {
  try {
    await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 22000 })
    await expect.poll(() => page.evaluate(() => window.__qaPeers.some(peer => peer.connectionState === 'connected')), { timeout: 22000 }).toBe(true)
  } catch (error) {
    // Keep only native transport state enums and counts; never SDP, tokens, identities or URLs.
    console.error('media-connect-states='+JSON.stringify(await page.evaluate(() => window.__qaPeers?.map(peer => ({
      connection: peer.connectionState, ice: peer.iceConnectionState, gathering: peer.iceGatheringState,
      signaling: peer.signalingState, local_description: Boolean(peer.localDescription),
      remote_description: Boolean(peer.remoteDescription),
    })) ?? [])))
    throw error
  }
}
