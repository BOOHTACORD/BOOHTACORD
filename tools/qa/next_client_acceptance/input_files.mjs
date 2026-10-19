import assert from 'node:assert/strict'
import { mkdirSync, realpathSync, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'

// Keep fixture bytes on the browser host instead of base64-serializing up to
// 35 MB through CDP and decoding them on the page's UI thread.
export function fixtureFile(directory,name,size) {
  const target=resolve(directory),work=dirname(target)
  assert.equal(basename(target),'files')
  assert.equal(dirname(work),resolve('.out'))
  assert.match(basename(work),/^qa-next-client-[a-zA-Z0-9_-]+$/)
  assert.equal(realpathSync(work),work)
  assert.match(name,/^[a-zA-Z0-9][a-zA-Z0-9.-]*$/)
  assert.ok(Number.isSafeInteger(size) && size>0 && size<=25_000_000)
  mkdirSync(target,{recursive:true})
  assert.equal(realpathSync(target),target)
  const path=join(target,name)
  writeFileSync(path,Buffer.alloc(size),{flag:'wx'})
  return path
}
