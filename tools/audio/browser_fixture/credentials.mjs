export function fixtureCredentials(env) {
  const key = env.RNNOISE_LIVEKIT_API_KEY, secret = env.RNNOISE_LIVEKIT_API_SECRET
  if ((key && !secret) || (!key && secret)) throw new Error('Both fixture credentials are required')
  return key && secret ? { key, secret } : { key: 'devkey', secret: 'secret' }
}
