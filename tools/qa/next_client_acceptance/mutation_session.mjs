import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { createInterface } from 'node:readline'
import { revokedLeaseSql } from './revocation_sql.mjs'

// Pin a previously label-verified container and connect before warming the TTL.
export async function mutationSession(container, account, start = spawn) {
  assert.match(container, /^[a-f0-9]{64}$/)
  const revoke = revokedLeaseSql(account)
  const statements = { block: `UPDATE users SET blocked_at=now() WHERE id='${account}'`,
    unblock: `UPDATE users SET blocked_at=NULL WHERE id='${account}'`, revoke }
  const child = start('docker', ['exec','-i',container,'psql','-U','qa','-d','qa','-qAt','-v','ON_ERROR_STOP=1'],
    { stdio: ['pipe','pipe','ignore'] })
  let pending = null, exited = false, exitCode
  const failure = () => new Error('Owned mutation session failed')
  const reject = () => { if (pending) { const item=pending;pending=null;clearTimeout(item.timer);item.reject(failure()) } }
  const exit = new Promise(resolve => child.once('exit', code => { exited=true;exitCode=code;reject();resolve() }))
  child.on('error',reject);child.stdin.on('error',reject)
  const lines=createInterface({input:child.stdout})
  lines.on('line', line => {
    if (!pending || line!==pending.expected) { reject();if(!exited)child.kill();return }
    const item=pending;pending=null;clearTimeout(item.timer);item.resolve()
  })
  const request=(statement,expected)=>new Promise((resolve,rejectRequest)=>{
    if(pending||exited) { rejectRequest(failure());return }
    pending={expected,resolve,reject:rejectRequest,timer:setTimeout(reject,5000)}
    child.stdin.write(statement+';\n')
  })
  try { await request("SELECT 'ready'",'ready') }
  catch(error) { if(!exited)child.kill();lines.close();throw error }
  return {
    async mutate(action) {
      assert.ok(Object.hasOwn(statements,action))
      await request(statements[action]+"; SELECT 'done'",'done')
    },
    async close() {
      let timer
      try {
        if(!exited)child.stdin.end()
        await Promise.race([exit,new Promise((_,rejectClose)=>{timer=setTimeout(()=>{if(!exited)child.kill();rejectClose(failure())},5000)})])
        if(exitCode!==0)throw failure()
      } finally { clearTimeout(timer);lines.close() }
    },
  }
}
