import { test,expect } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
const binding=process.env.TRACE_QA_SESSION,relay=process.env.TRACE_QA_RELAY_URL,tempo=process.env.TRACE_QA_TEMPO_URL
test.skip(!binding||!relay||!tempo,'requires Go QA relay and isolated Collector/Tempo')
test('actual sender/receiver render, independent visits, first frame and stale batch survive sanitization',async({page,browser,request})=>{
 let stored:any=null,posts=0
 const attach=async(p:any)=>{
  await p.route('**/api/v1/**',async(route:any)=>{
   const req=route.request(),url=req.url()
   if(url.endsWith('/telemetry/traces')){
    const response=await request.post(relay!,{headers:{'Content-Type':'application/x-protobuf','X-Client-Platform':'web','X-Telemetry-Session':binding!},data:req.postDataBuffer()!})
    expect(response.status(),'real relay rejected browser OTLP').toBe(202)
    await route.fulfill({status:response.status(),headers:response.headers(),body:await response.body()});return
   }
   if(url.includes('/members/')){await route.fulfill({json:{user_id:'00000000-0000-4000-8000-000000000001',login:'fixture',display_name:'Fixture',role:'MEMBER',presence:'online'}});return}
   if(url.includes('/message-reactions?')){await route.fulfill({json:{reactions:[],can_pin:false}});return}
   if(req.method()==='POST'){
    posts++;const body=req.postDataJSON();stored={id:'00000000-0000-4000-8000-000000000003',channel_id:'00000000-0000-4000-8000-000000000002',author_id:'00000000-0000-4000-8000-000000000001',client_message_id:body.client_message_id,body:body.body,revision:1,created_at:new Date().toISOString(),attachments:[],mention_user_ids:[]}
    await route.abort('connectionreset');return
   }
   if(url.includes('/message-delivery/')){await route.fulfill({json:{account_id:stored.author_id,message_id:stored.id}});return}
   await route.fulfill({json:{messages:stored?[stored]:[]}})
  })
  await p.goto('http://127.0.0.1:4807/tests/tracing_flow/fixture.html')
  await p.evaluate((b:string)=>(window as any).tracingQA.bind(b),binding!)
 }
 await attach(page);const peer=await browser.newContext(),receiver=await peer.newPage();await attach(receiver)
 await page.getByRole('button',{name:'Отправить',exact:true}).click()
 await expect(page.locator('.message-row')).toHaveCount(1)
 await receiver.evaluate(()=>(window as any).tracingQA.receive())
 await expect(receiver.locator('.message-row')).toHaveCount(1);expect(posts).toBe(1)
 await expect(page.locator('.reaction-palette button[aria-label="Реакция 👍"]')).toBeEnabled()
 await expect(receiver.locator('.reaction-palette button[aria-label="Реакция 👍"]')).toBeEnabled()
 if(process.env.TRACE_QA_CAPTURE_DIR){
  await mkdir(process.env.TRACE_QA_CAPTURE_DIR,{recursive:true})
  await page.screenshot({path:join(process.env.TRACE_QA_CAPTURE_DIR,'sender-rendered.png'),fullPage:true})
  await receiver.screenshot({path:join(process.env.TRACE_QA_CAPTURE_DIR,'receiver-rendered.png'),fullPage:true})
 }
 for(const p of [page,receiver]){const status=await p.evaluate(()=>(window as any).tracingQA.flush());expect(status.accepted,JSON.stringify(status)).toBeGreaterThan(0)}
 const viewID=await page.evaluate(()=>(window as any).tracingQA.select(false))
 await expect.poll(()=>page.evaluate(()=>(window as any).tracingQA.spans().filter((s:any)=>s.attrs['app.flow.outcome']==='timeout').length),{timeout:125000}).toBe(1)
 await page.evaluate(()=>(window as any).tracingQA.select(true))
 await expect.poll(()=>page.evaluate(()=>(window as any).tracingQA.spans().filter((s:any)=>s.attrs['app.flow.name']==='screen.view'&&s.attrs['app.flow.outcome']==='success').length)).toBe(1)
 if(process.env.TRACE_QA_CAPTURE_DIR){
  await page.screenshot({path:join(process.env.TRACE_QA_CAPTURE_DIR,'synthetic-first-frame.png'),fullPage:true})
 }
 for(const p of [page,receiver]){
  const status=await p.evaluate(()=>(window as any).tracingQA.flush());expect(status.rejected).toBe(0);expect(status.accepted).toBeGreaterThan(0)
 }
 const stale=await page.evaluate(()=>{const qa=(window as any).tracingQA,id=qa.pending();qa.reset();return id})
 await page.evaluate((b:string)=>(window as any).tracingQA.bind(b),binding!)
 expect((await page.evaluate(()=>(window as any).tracingQA.flush())).dropped).toBeGreaterThan(0)
 const spans=await page.evaluate(()=>(window as any).tracingQA.spans()),others=await receiver.evaluate(()=>(window as any).tracingQA.spans())
 const terminal=spans.filter((s:any)=>s.attrs['app.flow.record']==='terminal'),received=others.find((s:any)=>s.attrs['app.flow.name']==='realtime.process'&&s.attrs['app.flow.outcome']==='success')
 expect(received).toBeTruthy();expect(received.attrs['app.visit.id']).not.toBe(terminal[0].attrs['app.visit.id'])
 expect(terminal.filter((s:any)=>s.attrs['app.flow.id']===viewID).map((s:any)=>[s.attrs['app.flow.attempt'],s.attrs['app.flow.outcome']])).toEqual([[1,'timeout'],[2,'success']])
 console.log(JSON.stringify({profile:'synthetic-two-client-runtime',source:process.env.TRACE_QA_SOURCE_SHA??'working-tree',
  senderRecords:spans.length,receiverRecords:others.length,actions:terminal.filter((s:any)=>s.attrs['app.flow.id']!==stale).map((s:any)=>({
   name:s.attrs['app.flow.name'],attempt:s.attrs['app.flow.attempt'],outcome:s.attrs['app.flow.outcome'],
   records:spans.filter((record:any)=>record.attrs['app.flow.id']===s.attrs['app.flow.id']&&record.attrs['app.flow.attempt']===s.attrs['app.flow.attempt']).length,
  }))}))
 for(const span of [...terminal.filter((s:any)=>s.attrs['app.flow.id']!==stale),received]){
  await expect.poll(async()=>{const r=await request.get(tempo+'/api/traces/'+span.trace);return r.status()},{timeout:30000}).toBe(200)
  const saved=await (await request.get(tempo+'/api/traces/'+span.trace)).text()
  expect(saved).toContain(span.attrs['app.flow.id']);expect(saved).not.toContain('private-synthetic-message')
  expect(saved).not.toContain(stale)
 }
 await peer.close()
})
