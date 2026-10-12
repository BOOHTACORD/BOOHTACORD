import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, expect, login, api, status, channel, openNavigation } from '../client_lifecycle/request.mjs'

const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const report={issue:293,width:input.width,checks:{},mocks:false,physical_touch:false,roles:['MEMBER','MEMBER','ADMIN'],mutations:{}}
const browser=await chromium.launch(), contexts=[]
let phase='setup'
async function client(name){
  const c=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:input.width,height:900},hasTouch:input.width<600,isMobile:input.width<600})
  contexts.push(c);const p=await c.newPage();p.setDefaultTimeout(15000)
  p.on('request',r=>{if(r.method()!=='GET'&&new URL(r.url()).pathname.includes('/messages/')) report.mutations[r.method()]=(report.mutations[r.method()]??0)+1})
  await login(p,name,input.password);return p
}
async function touch(locator){if(input.width<600)await locator.tap();else await locator.click()}
async function openControls(row){
  if(input.width<600){await touch(row.getByRole('button',{name:'Действия с сообщением',exact:true}));await expect(row.locator('.message-actions')).toHaveClass(/is-open/)}
  else{await row.hover();await row.getByRole('button',{name:'Ответить',exact:true}).focus()}
}
async function direct(page,name){await openNavigation(page);await page.getByRole('button',{name:'Личные',exact:true}).click();await page.locator('.direct-message-navigation .channel-button').filter({hasText:name}).click()}
async function capture(locator,name){
  await locator.page().bringToFront();await locator.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))})
  await locator.page().waitForTimeout(300)
  await locator.screenshot({path:input.directory+'/'+name,animations:'disabled'})
}
async function send(page,prefix,body){const r=await api(page,prefix+'/messages','POST',{body,client_message_id:randomUUID()});status(r,201);return r.body}
async function ownActions(page,prefix,message,scope){
  const row=page.locator('.message-row').filter({has:page.getByText(message.body,{exact:true})}).first()
  phase=scope+' explicit disclosure and targets'
  await expect(row).toBeVisible()
  const trigger=row.locator('.message-actions-toggle')
  if(input.width<600){const box=await trigger.boundingBox();assert.ok(box&&box.width>=44&&box.height>=44);await expect(trigger).toHaveCSS('opacity','1')}
  await openControls(row)
  assert.deepEqual(await row.locator('.message-action-buttons button').allTextContents(),['Ответить','Изменить','Удалить'])
  const actionPanel=row.locator('.message-action-buttons')
  await expect(actionPanel).toBeVisible()
  const actionBounds=await actionPanel.boundingBox()
  assert.ok(actionBounds.x>=-0.5&&actionBounds.x+actionBounds.width<=input.width+0.5)
  await capture(actionPanel,scope+'-owned-toolbar.png')
  phase=scope+' reply and focus'
  await touch(row.getByRole('button',{name:'Ответить',exact:true}));await expect(row.locator('.message-actions')).not.toHaveClass(/is-open/)
  await expect(input.width<600?trigger:row).toBeFocused()
  const cancelReply=page.locator('.reply-target').getByRole('button')
  await expect(cancelReply).toBeVisible()
  await touch(cancelReply)
  report.checks[scope+'_reply_explicit_focus']='PASS'
  phase=scope+' edit actual HTTP'
  await openControls(row);await touch(row.getByRole('button',{name:'Изменить',exact:true}))
  const edited=message.body+' changed'
  await page.getByLabel('Изменённый текст сообщения').fill(edited)
  const patch=page.waitForResponse(r=>r.request().method()==='PATCH'&&new URL(r.url()).pathname.endsWith('/messages/'+message.id))
  await touch(page.getByRole('button',{name:'Сохранить',exact:true}));assert.equal((await patch).status(),200)
  const next=page.locator('.message-row').filter({has:page.getByText(edited,{exact:true})}).first()
  await expect(next).toBeVisible();report.checks[scope+'_edit_HTTP']='PASS'
  phase=scope+' real reaction targets and toggle'
  const reactions=next.getByRole('group',{name:'Реакции на сообщение'}).getByRole('button',{name:/^Реакция /})
  await expect(reactions).toHaveCount(6)
  if(input.width<600)for(const b of await reactions.all()){const v=await b.boundingBox();assert.ok(v.width>=44&&v.height>=44)}
  const first=reactions.first();await expect(first).toBeEnabled()
  await touch(first);await expect(first).toHaveAttribute('aria-pressed','true')
  await capture(next.getByRole('group',{name:'Реакции на сообщение'}),scope+'-reaction-tools.png')
  await touch(first);await expect(first).toHaveAttribute('aria-pressed','false')
  report.checks[scope+'_reaction_toggle_and_touch_targets']='PASS'
  phase=scope+' cancel deletion has no mutation'
  const deletes=report.mutations.DELETE??0
  await openControls(next)
  page.once('dialog',d=>d.dismiss())
  await touch(next.getByRole('button',{name:'Удалить',exact:true}))
  await page.waitForTimeout(100)
  assert.equal(report.mutations.DELETE??0,deletes)
  const history=await api(page,prefix+'/messages?at='+message.id+'&limit=20');status(history,200)
  assert.equal(history.body.messages.find(m=>m.id===message.id).deleted,false)
  report.checks[scope+'_cancel_delete_no_HTTP']='PASS'
  phase=scope+' confirm deletion actual HTTP'
  page.once('dialog',d=>d.accept())
  const deletion=page.waitForResponse(r=>r.request().method()==='DELETE'&&new URL(r.url()).pathname.endsWith('/messages/'+message.id))
  await touch(next.getByRole('button',{name:'Удалить',exact:true}));assert.equal((await deletion).status(),204)
  assert.equal(report.mutations.DELETE,deletes+1)
  await expect(next).toHaveCount(0)
  const deleted=await api(page,prefix+'/messages?at='+message.id+'&limit=20');status(deleted,200)
  assert.equal(deleted.body.messages.find(m=>m.id===message.id).deleted,true)
  report.checks[scope+'_confirm_delete_once']='PASS'
}
try{
  const admin=await client('qa_admin')
  const ar=await api(admin,'/auth/register','POST',{login:'qa_actions_a',password:input.password});status(ar,201)
  const br=await api(admin,'/auth/register','POST',{login:'qa_actions_b',password:input.password});status(br,201)
  const cat=await api(admin,'/admin/categories','POST',{name:'ActionsLab'});status(cat,201)
  const ch=await api(admin,'/admin/categories/'+cat.body.id+'/channels','POST',{name:'ActionsText',kind:'TEXT'});status(ch,201)
  const a=await client('qa_actions_a'),b=await client('qa_actions_b')
  const dm=await api(a,'/direct-messages','POST',{participant_id:br.body.id});status(dm,201)
  const textPrefix='/channels/'+ch.body.id,directPrefix='/direct-messages/'+dm.body.id
  const textOwn=await send(a,textPrefix,'Synthetic owned TEXT action fixture')
  const textForeign=await send(b,textPrefix,'Synthetic peer TEXT action fixture')
  await a.reload();await channel(a,'ActionsText')
  await ownActions(a,textPrefix,textOwn,'TEXT')
  phase='TEXT foreign ownership'
  const foreign=a.locator('.message-row').filter({has:a.getByText(textForeign.body,{exact:true})})
  await openControls(foreign)
  assert.deepEqual(await foreign.locator('.message-action-buttons button').allTextContents(),['Ответить'])
  await capture(foreign.locator('.message-action-buttons'),'TEXT-peer-toolbar.png')
  await a.keyboard.press('Escape');report.checks.TEXT_peer_ownership='PASS'
  phase='TEXT admin pin actual HTTP'
  await admin.reload();await channel(admin,'ActionsText')
  const pinRow=admin.locator('.message-row').filter({has:admin.getByText(textForeign.body,{exact:true})})
  const pin=pinRow.getByRole('button',{name:'Закрепить сообщение',exact:true})
  phase='TEXT admin pin visible and target'
  await expect(pin).toBeVisible()
  if(input.width<600){const v=await pin.boundingBox();assert.ok(v.width>=44&&v.height>=44)}
  phase='TEXT admin pin click and real server state'
  const pinResponse=admin.waitForResponse(r=>r.request().method()==='PUT'&&new URL(r.url()).pathname.endsWith('/pins/'+textForeign.id))
  await touch(pin);assert.equal((await pinResponse).status(),204)
  const pins=await api(admin,textPrefix+'/pins');status(pins,200)
  assert.ok(pins.body.pins.some(p=>p.message_id===textForeign.id))
  report.pin_observation={HTTP:204,server_list_contains_message:true,persistent_confirmation_notice:'Not required for this action criterion; transient during social refresh, not claimed PASS'}
  phase='TEXT admin pin capture'
  await capture(pinRow.getByRole('group',{name:'Реакции на сообщение'}),'TEXT-admin-pin-tools.png')
  report.checks.TEXT_admin_pin='PASS'
  phase='DM fixtures and own actions'
  const dmOwn=await send(a,directPrefix,'Synthetic owned DM action fixture')
  const dmPeer=await send(b,directPrefix,'Synthetic peer DM action fixture')
  await a.reload();await direct(a,'qa_actions_b')
  await ownActions(a,directPrefix,dmOwn,'DM')
  const peer=a.locator('.message-row').filter({has:a.getByText(dmPeer.body,{exact:true})})
  await openControls(peer)
  assert.deepEqual(await peer.locator('.message-action-buttons button').allTextContents(),['Ответить'])
  await expect(peer.getByRole('button',{name:'Закрепить сообщение',exact:true})).toHaveCount(0)
  await capture(peer.locator('.message-action-buttons'),'DM-peer-toolbar.png')
  report.checks.DM_peer_ownership_no_pin='PASS'
  phase='DM third administrator ACL'
  assert.equal((await api(admin,directPrefix+'/messages')).status,404)
  assert.equal((await api(admin,directPrefix+'/messages/'+dmPeer.id,'DELETE')).status,404)
  report.checks.DM_third_admin_history_delete_denied='PASS'
  report.status='PASS';report.browser=browser.version()
}catch(cause){report.status='FAIL';report.failed_phase=phase;report.failure_type=cause?.name??'unknown';report.failed_line=/scenario.mjs:(\d+)/.exec(cause?.stack??'')?.[1];throw Error('Sanitized message-actions failure: '+phase)}
finally{writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n');for(const c of contexts)await c.close();await browser.close()}
