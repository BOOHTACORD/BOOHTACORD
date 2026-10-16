import assert from 'node:assert/strict'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

const executeFile = promisify(execFile)
// Freeze the real SFU without removing its Docker interface: on Linux that
// removal makes Chromium abort unrelated streams with ERR_NETWORK_CHANGED.
// Fault control must also leave Playwright's event loop responsive.
export async function controlOwnedSfu(action, { owner = process.env.QA_DB_OWNER, execute = executeFile } = {}) {
  assert.match(owner, /^qa-client-[a-f0-9]{16}$/)
  assert.ok(['pause', 'unpause'].includes(action))
  const name = owner+'-sfu'
  const { stdout } = await execute('docker', ['inspect', name, '--format', '{{index .Config.Labels "boohtacord.qa.owner"}}'])
  assert.equal(stdout.trim(), owner, 'Foreign fixture service')
  return execute('docker', [action, name])
}
