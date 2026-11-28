import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
const execute = promisify(execFile)
async function docker(args) {
  try { return (await execute('docker', args, { encoding: 'buffer', timeout: 5000 })).stdout }
  catch { throw Error('Owned SFU discovery command failed') }
}
export async function discoveryPort(owner = process.env.QA_DB_OWNER, command = docker) {
  assert.match(owner ?? '', /^qa-client-[0-9a-f]{16}$/, 'Owned QA namespace required')
  const format = '{{index .Config.Labels "boohtacord.qa.owner"}}'
  for (const role of ['redis', 'sfu']) {
    assert.equal(String(await command(['inspect', owner+'-'+role, '--format', format])).trim(), owner, 'Foreign discovery service')
  }
  const redis = (...args) => command(['exec', owner+'-redis', 'redis-cli', '--raw', ...args])
  const key = value => { assert.match(value, /^[A-Za-z0-9_-]{1,100}$/, 'Invalid SFU node key'); return value }
  return {
    keys: async () => String(await redis('HKEYS', 'nodes')).trim().split(/\s+/).filter(Boolean),
    read: value => redis('HGET', 'nodes', key(value)),
    remove: async value => assert.equal(String(await redis('HDEL', 'nodes', key(value))).trim(), '1', 'Discovery entry was not removed'),
  }
}
