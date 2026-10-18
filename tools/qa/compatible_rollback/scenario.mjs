import assert from 'node:assert/strict'
import { randomUUID, createHash } from 'node:crypto'
import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs'
import { chromium, expect, api, status, channel } from '../client_lifecycle/request.mjs'

const work=process.env.QA60_WORK, destination=process.env.QA60_OUTPUT
const input=JSON.parse(readFileSync(work+'/private/browser.json','utf8'))
const origin='https://qa60.localhost:5443'
const contexts=[], clients=[]
const report={status:'RUNNING',observations:[],source:'actual signed Web images and Go API; no routed/mocked responses'}
const browser=await chromium.launch({args:['--host-resolver-rules=MAP qa60.localhost 127.0.0.1']})
let phase='setup'
const save=()=>writeFileSync(destination+'/browser.json',JSON.stringify(report,null,2)+'\n')
const data=result=>result.body
async function client(name){
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1200,height:800}});contexts.push(context)
  const page=await context.newPage();page.setDefaultTimeout(10000)
  await page.goto(origin)
  await page.getByLabel('Логин',{exact:true}).fill(name)
  await page.getByLabel('Пароль',{exact:true}).fill(input.password)
  const response=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/v1/auth/login'&&r.request().method()==='POST')
  await page.getByRole('button',{name:'Войти',exact:true}).click()
  assert.equal((await response).status(),204)
  await expect(page.getByTestId('app-shell')).toBeVisible()
  return page
}
async function upload(page,prefix,name){
  const result=await page.evaluate(async({prefix,name})=>{
    const form=new FormData();form.append('file',new File(['Owned QA60 persistent attachment.'],name,{type:'text/plain'}))
    const response=await fetch('/api/v1'+prefix+'/attachments',{method:'POST',credentials:'same-origin',body:form})
    return {status:response.status,body:await response.json()}
  },{prefix,name});status(result,201);return result.body
}
async function checkFiles(page,files){
  for(const file of files){const result=await page.evaluate(async path=>{
    const response=await fetch('/api/v1'+path,{credentials:'same-origin'})
    const bytes=await response.arrayBuffer()
    return{status:response.status,bytes:bytes.byteLength,sha:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('')}
  },file.path);assert.equal(result.status,200);assert.equal(result.sha,file.sha)}
}
try{
  report.browser=browser.version();save()
  const admin=await client('qa_admin')
  const members=[]
  for(const name of ['qa_rollback_a','qa_rollback_b']){const r=await api(admin,'/auth/register','POST',{login:name,password:input.password});status(r,201);members.push(r.body)}
  const category=await api(admin,'/admin/categories','POST',{name:'QA60'});status(category,201)
  const channels={}
  for(const kind of ['TEXT','VOICE']){const r=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QA60 '+kind,kind});status(r,201);channels[kind]=r.body.id}
  for(const name of ['qa_rollback_a','qa_rollback_b'])clients.push(await client(name))
  const dm=await api(clients[0],'/direct-messages','POST',{participant_id:members[1].id});status(dm,201)
  const textPrefix='/channels/'+channels.TEXT, dmPrefix='/direct-messages/'+dm.body.id
  const files=[]
  for(const [prefix,name] of [[textPrefix,'qa60-text.txt'],[dmPrefix,'qa60-private.txt']]){
    const file=await upload(clients[0],prefix,name)
    const sent=await api(clients[0],prefix+'/messages','POST',{client_message_id:randomUUID(),body:'QA60 persistent fixture',attachment_ids:[file.id]});status(sent,201)
    files.push({path:prefix+'/attachments/'+file.id,sha:createHash('sha256').update('Owned QA60 persistent attachment.').digest('hex')})
  }
  for(const page of clients){await page.reload();await channel(page,'QA60 TEXT');await expect(page.locator('.message-content').filter({hasText:'QA60 persistent fixture'})).toBeVisible()}
  writeFileSync(work+'/browser-ready.json',JSON.stringify({status:'READY'}))
  const seen=new Set(), deadline=Date.now()+700000
  while(seen.size<5&&Date.now()<deadline){
    if(!existsSync(work+'/command.json')){await new Promise(r=>setTimeout(r,100));continue}
    const command=JSON.parse(readFileSync(work+'/command.json','utf8'));if(seen.has(command.phase)){await new Promise(r=>setTimeout(r,100));continue}
    phase=command.phase;const maintenance=phase.endsWith('_maintenance'),rows=[]
    for(let i=0;i<2;i++){
      const page=clients[i]
      if(!maintenance){
        await page.reload();await expect(page.getByTestId('app-shell')).toBeVisible();await channel(page,'QA60 TEXT')
        await expect(page.locator('.message-content').filter({hasText:'QA60 persistent fixture'})).toBeVisible()
        const history=await api(page,dmPrefix+'/messages');status(history,200);assert.ok(history.body.messages.some(m=>m.attachments?.length===1))
        await checkFiles(page,files)
      }
      const banner=page.locator('.maintenance-banner')
      if(maintenance)await expect(banner).toBeVisible({timeout:8000});else await expect(banner).toHaveCount(0)
      const session=await api(page,'/auth/session');status(session,200);assert.equal(session.body.account_id,members[i].id)
      const auth=await api(page,'/me/sessions');status(auth,200)
      const revision=await page.evaluate(async()=>{const r=await fetch('/release-receipt.json',{cache:'no-store'});return(await r.json()).source_revision})
      assert.equal(revision,command.revision)
      const admission=await api(page,`/voice/channels/${channels.VOICE}/leases`,'POST',{transfer:false})
      status(admission,maintenance?503:201)
      if(maintenance)assert.equal(admission.body.error.code,'MAINTENANCE')
      else status(await api(page,'/voice/leases/'+admission.body.id,'DELETE'),204)
      let loginStatus=phase==='baseline'?204:null
      if(maintenance){
        const attempt=await api(page,'/auth/login','POST',{login:['qa_rollback_a','qa_rollback_b'][i],password:input.password})
        status(attempt,503);assert.equal(attempt.body.error.code,'MAINTENANCE');loginStatus=attempt.status
        status(await api(page,'/me/sessions'),200)
      }else if(phase==='restored'){
        const probe=await client(['qa_rollback_a','qa_rollback_b'][i]);loginStatus=204
        await probe.context().close()
      }
      await page.screenshot({path:destination+'/'+phase+'-'+i+'.png'})
      rows.push({phase,browser:i,authenticated:true,banner:maintenance,admission:admission.status,login_status:loginStatus,revision})
    }
    report.observations.push(...rows);save()
    writeFileSync(work+'/ack-'+phase+'.pending',JSON.stringify(rows))
    renameSync(work+'/ack-'+phase+'.pending',work+'/ack-'+phase+'.json');seen.add(phase)
    console.log('QA60_BROWSER_PASS '+phase)
  }
  assert.equal(seen.size,5)
  report.status='PASS';save()
}catch(error){
  report.status='FAIL';report.phase=phase;report.error_type=error?.name||'Error'
  if(typeof error?.actual==='number')report.actual=error.actual
  if(typeof error?.expected==='number')report.expected=error.expected
  save();writeFileSync(work+'/browser-failure.json',JSON.stringify({status:'FAIL',phase,error_type:report.error_type}))
  for(let i=0;i<clients.length;i++)await clients[i].screenshot({path:destination+'/failure-'+i+'.png'}).catch(()=>{})
  process.exitCode=1
}finally{for(const context of contexts)await context.close().catch(()=>{});await browser.close()}
