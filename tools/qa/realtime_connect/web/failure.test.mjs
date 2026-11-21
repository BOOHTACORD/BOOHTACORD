import {test} from 'node:test'
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,unlinkSync,rmdirSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import {writeFailure} from './failure.mjs'

test('failure output retains finite stage/type without private error text',()=>{
  const directory=mkdtempSync(join(tmpdir(),'r2-failure-'))
  try{
    const result=writeFailure(directory,'faults',new Error('synthetic-cookie-password-private-body'))
    assert.deepEqual(result,{status:'FAIL',stage:'faults',errorType:'Error'})
    const output=readFileSync(join(directory,'failure.json'),'utf8')
    assert.equal(output.includes('synthetic-cookie'),false)
  }finally{unlinkSync(join(directory,'failure.json'));rmdirSync(directory)}
})
