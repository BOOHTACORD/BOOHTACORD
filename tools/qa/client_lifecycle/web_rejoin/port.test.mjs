import assert from 'node:assert/strict'
import { test } from 'node:test'
import { discoveryPort } from './port.mjs'
const owner = 'qa-client-0123456789abcdef'

test('rejects a foreign namespace before any Docker operation', async () => {
  let commands = 0
  await assert.rejects(discoveryPort('production', async () => { commands++ }), /Owned QA namespace/)
  assert.equal(commands, 0)
})

for (const foreign of ['redis', 'sfu']) test(`rejects a foreign ${foreign} before reading or mutating Redis`, async () => {
  const commands = []
  await assert.rejects(discoveryPort(owner, async args => {
    commands.push(args)
    return Buffer.from(args[1].endsWith('-'+foreign) ? 'other-owner' : owner)
  }), /Foreign discovery service/)
  assert.ok(commands.every(args => args[0] === 'inspect'))
})

test('uses binary reads and removes only the validated owned node entry', async () => {
  const commands = [], binary = Buffer.from([0, 255, 10, 42, 10])
  const port = await discoveryPort(owner, async args => {
    commands.push(args)
    if (args[0] === 'inspect') return Buffer.from(owner+'\n')
    if (args.includes('HKEYS')) return Buffer.from('ND_owned\n')
    if (args.includes('HGET')) return binary
    return Buffer.from('1\n')
  })
  assert.deepEqual(await port.keys(), ['ND_owned'])
  assert.deepEqual(await port.read('ND_owned'), binary)
  await port.remove('ND_owned')
  assert.deepEqual(commands.at(-1), ['exec', owner+'-redis', 'redis-cli', '--raw', 'HDEL', 'nodes', 'ND_owned'])
  const count = commands.length
  await assert.rejects(port.remove('bad key'), /Invalid SFU node key/)
  assert.equal(commands.length, count)
})
