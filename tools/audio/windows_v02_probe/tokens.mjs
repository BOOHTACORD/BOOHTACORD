// Tokens are consumed by the local runner through a private pipe, never logged.
import { createRequire } from 'node:module'
import { resolve } from 'node:path'

const web = process.argv[2]
const key = process.env.BOOHTA_PROBE_KEY, secret = process.env.BOOHTA_PROBE_SECRET
if (!web || !key || !secret) throw new Error('Local probe credentials are required')
const { AccessToken } = createRequire(resolve(web, 'package.json'))('livekit-server-sdk')
async function issue(identity, publish) {
  const token = new AccessToken(key, secret, { identity, ttl: '2m' })
  token.addGrant({ roomJoin: true, room: 'audio-local-probe', canPublish: publish, canSubscribe: !publish })
  return token.toJwt()
}
process.stdout.write(JSON.stringify({ sender: await issue('probe-sender', true), receiver: await issue('probe-receiver', false) }))
