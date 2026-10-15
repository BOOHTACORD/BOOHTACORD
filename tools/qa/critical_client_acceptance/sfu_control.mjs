import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

const executeFile = promisify(execFile)
// Fault injection must not block Playwright's WebSocket proxy or request routes
// while Docker waits for the SFU's graceful shutdown deadline.
export async function controlOwnedSfu(action, { owner = process.env.QA_DB_OWNER, execute = executeFile } = {}) {
  assert.match(owner, /^qa-client-[a-f0-9]{16}$/)
  assert.ok(['stop', 'start'].includes(action))
  const name = owner+'-sfu'
  const { stdout } = await execute('docker', ['inspect', name, '--format', '{{index .Config.Labels "boohtacord.qa.owner"}}'])
  assert.equal(stdout.trim(), owner, 'Foreign fixture service')
  return execute('docker', [action, name])
}
