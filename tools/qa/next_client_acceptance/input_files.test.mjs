import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, rmSync, statSync } from 'node:fs'
import { resolve, join } from 'node:path'
import { fixtureFile } from './input_files.mjs'

function owned(t) {
  const root=resolve('.out');mkdirSync(root,{recursive:true})
  const work=mkdtempSync(join(root,'qa-next-client-test-'))
  t.after(()=>rmSync(work,{recursive:true,force:true}))
  return join(work,'files')
}

test('native file selection uses a real zero-filled file in the private owned work directory',t=>{
 const directory=owned(t),path=fixtureFile(directory,'upload.bin',1024)
 assert.equal(typeof path,'string');assert.equal(path,join(directory,'upload.bin'))
 assert.equal(statSync(path).size,1024);assert.deepEqual(readFileSync(path),Buffer.alloc(1024))
 assert.throws(()=>fixtureFile(directory,'upload.bin',1),/EEXIST/)
})

test('fixture paths and sizes cannot write outside the owned selection directory',t=>{
 const directory=owned(t)
 for(const name of ['../outside','/tmp/outside','nested/file','.env'])
  assert.throws(()=>fixtureFile(directory,name,1))
 for(const size of [-1,0,25_000_001,1.5,NaN])
  assert.throws(()=>fixtureFile(directory,'invalid.bin',size))
 assert.throws(()=>fixtureFile('/tmp/foreign/files','upload.bin',1))
})
