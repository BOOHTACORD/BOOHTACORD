import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { createHash } from 'node:crypto'
import { publishSdk } from './publish.mjs'

async function fixture(fn) {
  const directory=await mkdtemp(path.join(tmpdir(),'sdk-publish-'))
  try {
    const contract={status:'PASS',schema_version:1,repository:'BOOHTACORD/BOOHTACORD',builder_revision:'a'.repeat(40),run_id:'101',run_attempt:'1',
      version:'webrtc-m150-boohtacord-r3',recipe_sha256:'b'.repeat(64),physical_playback_smoke:'NOT_RUN',assets:{}}
    for(const name of ['SHA256SUMS','WebRTC-macos.xcframework.zip','sdk-manifest.json']) {
      const data=Buffer.from('synthetic fixture '+name);await writeFile(path.join(directory,name),data)
      contract.assets[name]={bytes:data.length,sha256:createHash('sha256').update(data).digest('hex')}
    }
    const context={sha:'a'.repeat(40),repo:{owner:'BOOHTACORD',repo:'BOOHTACORD'},eventName:'workflow_dispatch',ref:'refs/heads/master'}
    const calls=[];let release
    const github={rest:{repos:{
      getReleaseByTag:async()=>{calls.push('lookup');throw Object.assign(new Error('absent'),{status:404})},
      createRelease:async value=>{calls.push('create');release={...value,id:17};return {data:release}},
      uploadReleaseAsset:async()=>{calls.push('upload');return {data:{}}},
      listReleaseAssets:async()=>({data:Object.entries(contract.assets).map(([name,value])=>({name,size:value.bytes,digest:'sha256:'+value.sha256}))}),
      updateRelease:async value=>{calls.push('publish');release={...release,...value};return {data:release}}
    },git:{getRef:async()=>({data:{object:{type:'commit',sha:context.sha}}})}}}
    await fn({directory,contract,context,github,calls,execution:{run_id:'101',run_attempt:'1'},authorized:'true'})
  } finally {await rm(directory,{recursive:true,force:true})}
}

test('publish only complete immutable draft; SDK never becomes latest',async()=>fixture(async args=>{
  const result=await publishSdk(args);assert.equal(result.status,'PASS');assert.deepEqual(args.calls,['lookup','create','upload','upload','upload','publish'])
}))
test('untrusted or non-explicit publication never calls API',async()=>fixture(async args=>{
  for(const update of [{authorized:'false'},{context:{...args.context,ref:'refs/heads/other'}},{context:{...args.context,eventName:'pull_request'}}])
    await assert.rejects(publishSdk({...args,...update}))
  assert.deepEqual(args.calls,[])
}))
test('existing SDK version is not changed',async()=>fixture(async args=>{
  args.github.rest.repos.getReleaseByTag=async()=>({data:{id:1}})
  await assert.rejects(publishSdk(args));assert.deepEqual(args.calls,[])
}))
test('failed or unverified upload leaves draft unpublished',async()=>fixture(async args=>{
  args.github.rest.repos.listReleaseAssets=async()=>({data:[]})
  await assert.rejects(publishSdk(args));assert.ok(!args.calls.includes('publish'))
}))
