import test from 'node:test'
import assert from 'node:assert/strict'
import { writeFile } from 'node:fs/promises'
import path from 'node:path'
import { createHash } from 'node:crypto'
import { withAsset, json } from '../android/test_helpers.mjs'
import { publishContract } from './publisher.mjs'

const apiRoot='https://api.example.test'
const source='a'.repeat(40)
const context={repository:'Egkurilov/BOOHTACORD',source_revision:source,tag:'android-v1.0.15',execution:{run_id:'12',run_attempt:'1'}}

async function fixture(body) {
  return withAsset(Buffer.from('public synthetic release bytes'),async asset=>{
    const contract={schema_version:1,status:'PASS',...context,release_mode:'stable',tag_verified:true,source_ref:'refs/tags/'+context.tag,platform:'android',identity:{version:'1.0.15',native_build:'4'},
      signing:{status:'signed'},manifest_sha256:'b'.repeat(64),assets:{[asset.name]:{bytes:asset.size,sha256:asset.digest.slice(7)}}}
    for(const name of ['artifact-manifest.json','SHA256SUMS']) {
      const bytes=Buffer.from('synthetic '+name)
      await writeFile(path.join(path.dirname(asset.path),name),bytes)
      contract.assets[name]={bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}
    }
    contract.manifest_sha256=contract.assets['artifact-manifest.json'].sha256
    asset.rows=Object.entries(contract.assets).map(([name,v])=>({name,size:v.bytes,digest:'sha256:'+v.sha256}))
    return body(asset,contract)
  })
}

function server(asset,{lostCreate=false,lostUpload=false,lostPublish=false,foreign=false,moveTag=false}={}) {
  let release=null;let uploaded=[];let tagReads=0
  const calls=[]
  const fetchImpl=async(url,init={})=>{
    const p=new URL(url).pathname;const method=init.method??'GET';calls.push([method,p])
    if(p.includes('/git/ref/tags/'))return json({object:{type:'commit',sha:moveTag&&++tagReads>1?'c'.repeat(40):source}})
    if(p.includes('/releases/tags/'))return release&&!release.draft?json(release):json({},404)
    if(p.endsWith('/releases')&&method==='GET')return json(release?[release]:[])
    if(p.endsWith('/releases')&&method==='POST') {
      const data=JSON.parse(init.body)
      assert.equal(data.draft,true);assert.equal(data.target_commitish,source)
      release={id:73,...data,upload_url:apiRoot+'/repos/Egkurilov/BOOHTACORD/releases/73/assets{?name,label}'}
      if(foreign)uploaded=[{name:'foreign.exe',size:1,digest:'sha256:'+'f'.repeat(64)}]
      if(lostCreate){lostCreate=false;throw new TypeError('lost response')}
      return json(release,201)
    }
    if(p.endsWith('/73/assets')&&method==='GET')return json(uploaded)
    if(p.endsWith('/73/assets')&&method==='POST') {
      const name=new URL(url).searchParams.get('name')
      uploaded.push(asset.rows.find(row=>row.name===name))
      if(lostUpload){lostUpload=false;throw new TypeError('lost response')}
      return json(uploaded.at(-1),201)
    }
    if(p.endsWith('/releases/73')&&method==='PATCH') {
      assert.equal(uploaded.length,3);release={...release,...JSON.parse(init.body)}
      if(lostPublish){lostPublish=false;throw new TypeError('lost response')}
      return json(release)
    }
    if(p.endsWith('/releases/73'))return json(release)
    assert.fail('Unexpected request '+method+' '+p)
  }
  return {fetchImpl,calls}
}

test('draft uploads verify before publishing; identical retry is read-only',async()=>fixture(async(asset,contract)=>{
  const remote=server(asset)
  const args={contract,directory:new URL('.', 'file://'+asset.path).pathname,context,token:'fixture',apiRoot,...remote,sleep:async()=>{}}
  const result=await publishContract(args)
  assert.equal(result.release.draft,false)
  const previous=remote.calls.length
  await publishContract(args)
  assert.equal(remote.calls.slice(previous).some(([method])=>method!=='GET'),false)
}))

test('lost create/upload/publish responses resume without overwriting assets',async()=>{
  for(const kind of ['lostCreate','lostUpload','lostPublish'])await fixture(async(asset,contract)=>{
    const remote=server(asset,{[kind]:true})
    const result=await publishContract({contract,directory:new URL('.', 'file://'+asset.path).pathname,context,token:'fixture',apiRoot,...remote,sleep:async()=>{}})
    assert.equal(result.release.draft,false)
    assert.equal(remote.calls.filter(([m,p])=>m==='POST'&&p.endsWith('/73/assets')).length,3)
  })
})

test('foreign remote asset and moving tag cannot finalize a release',async()=>{
  for(const kind of ['foreign','moveTag'])await fixture(async(asset,contract)=>{
    const remote=server(asset,{[kind]:true})
    await assert.rejects(publishContract({contract,directory:new URL('.', 'file://'+asset.path).pathname,context,token:'fixture',apiRoot,...remote,sleep:async()=>{}}))
    assert.equal(remote.calls.some(([method])=>method==='PATCH'),false)
  })
})

test('candidate, retry mismatch and changed local bytes fail before any network write',async()=>{
  for(const kind of ['candidate','attempt','bytes'])await fixture(async(asset,contract)=>{
    const remote=server(asset)
    if(kind==='candidate')contract.release_mode='candidate'
    if(kind==='attempt')contract.execution={run_id:'12',run_attempt:'99'}
    if(kind==='bytes')await writeFile(asset.path,'changed')
    await assert.rejects(publishContract({contract,directory:path.dirname(asset.path),context,token:'fixture',apiRoot,...remote,sleep:async()=>{}}))
    assert.equal(remote.calls.length,0)
  })
})

test('the same transport contract publishes Android, Windows and macOS metadata',async()=>{
  for(const platform of ['android','windows','macos'])await fixture(async(asset,contract)=>{
    contract.platform=platform;contract.tag=platform+'-v1.0.15';contract.source_ref='refs/tags/'+contract.tag
    contract.signing={status:platform==='macos'?'adhoc':platform==='windows'?'unsigned':'signed'}
    const local={...context,tag:contract.tag};const remote=server(asset)
    const result=await publishContract({contract,directory:path.dirname(asset.path),context:local,token:'fixture',apiRoot,...remote,sleep:async()=>{}})
    assert.equal(result.release.tag_name,contract.tag)
    if(platform==='macos')assert.match(result.release.body,/not notarized/)
  })
})

test('annotated remote tag peels to the exact approved commit',async()=>fixture(async(asset,contract)=>{
  const remote=server(asset)
  const fetchImpl=async(url,init)=>String(url).includes('/git/ref/tags/')?json({object:{type:'tag',sha:'b'.repeat(40)}}):
    String(url).includes('/git/tags/')?json({object:{type:'commit',sha:source}}):remote.fetchImpl(url,init)
  const result=await publishContract({contract,directory:path.dirname(asset.path),context,token:'fixture',apiRoot,fetchImpl,sleep:async()=>{}})
  assert.equal(result.release.draft,false)
}))
