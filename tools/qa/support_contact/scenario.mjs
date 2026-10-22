// Only synthetic messages on the owned loopback stack; never accepts a deployment URL.
import assert from 'node:assert/strict'
import {randomUUID} from 'node:crypto'
import {createRequire} from 'node:module'
const require=createRequire(new URL('../../../clients/web/package.json',import.meta.url))
const axePath=require.resolve('axe-core/axe.min.js')
import {readFileSync,writeFileSync} from 'node:fs'
import {execFileSync} from 'node:child_process'
import {chromium,expect,origin,login,api} from '../client_lifecycle/request.mjs'
assert.equal(origin,'https://localhost:4810')
const owner=process.env.QA_DB_OWNER
assert.match(owner??'',/^qa-client-[0-9a-f]{16}$/)
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const configure=id=>execFileSync('docker',['exec',owner+'-api','/support-contact',...(id?['set','--account-id',id]:['clear'])],{stdio:'pipe'})
const browser=await chromium.launch({args:['--allow-loopback-in-peer-connection','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']})
const report={}
// Preserve an already-open drawer. The generic journey helper intentionally
// closes/reopens it, which is unsuitable while text scaling changes its bounds.
async function openNavigation(page){
 if(page.viewportSize().width>=1024)return
 if(await page.locator('.sidebar').evaluate(element=>element.classList.contains('is-open')))return
 await page.getByRole('button',{name:'Открыть навигацию',exact:true}).click()
 await expect(page.locator('.guild-header')).toBeVisible()
}
try {
 const pages=[];const egress=[]
 for(const user of ['a','b','s','admin']){
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:960}})
  await context.addInitScript(()=>{const Native=window.RTCPeerConnection;window.__qaPeers=[];window.RTCPeerConnection=new Proxy(Native,{construct(target,args){const pc=Reflect.construct(target,args);window.__qaPeers.push(pc);return pc}})})
  context.on('request',request=>{if(!request.url().startsWith(origin)&&!request.url().startsWith('wss://localhost:4810/')) egress.push(new URL(request.url()).hostname)})
  const page=await context.newPage();await login(page,user==='admin'?'qa_admin':'qa_support_'+user,input.password)
  pages.push(page)
 }
 const [a,b,s,admin]=pages
 const identity=async p=>(await api(p,'/auth/session')).body.account_id
 const [aid,bid,sid]=await Promise.all([identity(a),identity(b),identity(s)])
 assert.ok(aid&&bid&&sid)
 const help=async p=>{
  await openNavigation(p)
  const button=p.getByRole('button',{name:'Помощь и обратная связь',exact:true})
  await button.click();await expect(p.locator('.user-footer-help')).toBeEnabled()
  if(await p.locator('.support-row').count()){
   if(p.viewportSize().width<1024)await expect(p.locator('.sidebar')).not.toHaveClass(/is-open/)
   await expect(p.locator('.support-privacy')).toBeVisible()
  }
 }
 const nav=async p=>{await openNavigation(p);await p.getByRole('button',{name:'Личные',exact:true}).click()}
 await a.screenshot({path:input.directory+'/01-unassigned-desktop.png',fullPage:true})
 await help(a);await expect(a.getByText('Поддержка этого сервера пока не назначена.',{exact:true})).toBeVisible()
 report.unassigned_no_dead_contact=true
 configure(sid)
 const other=await api(a,'/direct-messages','POST',{participant_id:bid});assert.equal(other.status,201)
 await a.reload();await expect(a.getByTestId('app-shell')).toBeVisible();await nav(a)
 await a.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_b'}).click()
 await a.locator('#direct-message-body').fill('Synthetic unsent other DM')
 const category=await api(admin,'/admin/categories','POST',{name:'Support Voice'});assert.equal(category.status,201)
 const voice=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'Support Voice',kind:'VOICE'});assert.equal(voice.status,201)
 await openNavigation(a);await a.getByRole('button',{name:'Каналы',exact:true}).click()
 await a.locator('.channel-button').filter({hasText:'Support Voice'}).click()
 await a.getByRole('button',{name:'Без микрофона',exact:true}).click()
 await expect(a.locator('.voice-status')).toHaveText('Голос подключён',{timeout:20000})
 const connectedBefore=await a.evaluate(()=>window.__qaPeers.filter(p=>p.connectionState==='connected').length)
 assert.ok(connectedBefore>0)
 await help(a)
 await expect(a.locator('.voice-status')).toHaveText('Голос подключён')
 assert.equal(await a.evaluate(()=>window.__qaPeers.filter(p=>p.connectionState==='connected').length),connectedBefore)
 report.voice_transport_retained_on_support=true
 await expect(a.getByRole('heading',{name:'Поддержка',exact:true})).toBeVisible()
 await expect(a.getByText('Опишите проблему или предложение. Можно прикрепить скриншот',{exact:true})).toBeVisible()
 await expect(a.getByText('Сообщения видит назначенная поддержка этого сервера.',{exact:false})).toBeVisible()
 const navData=async p=>(await api(p,'/direct-messages')).body
 const as=(await navData(a)).direct_messages.find(x=>x.other_participant_id===sid)?.id
 assert.ok(as)
 await a.addScriptTag({path:axePath})
 const accessibility=await a.evaluate(async()=>window.axe.run({include:[['.user-footer-help'],['.support-row'],['.support-privacy']]}))
 assert.deepEqual(accessibility.violations.map(value=>value.id),[]);report.support_accessibility=true
 await a.screenshot({path:input.directory+'/02-support-empty-desktop.png',fullPage:true})
 const send=async(p,text,file)=>{
  if(file){const upload=p.waitForResponse(r=>r.url().includes('/attachments')&&r.request().method()==='POST');await p.locator('#dm-attachments').setInputFiles({name:file,mimeType:'text/plain',buffer:Buffer.from('synthetic attachment')});assert.equal((await upload).status(),201)}
  await p.locator('#direct-message-body').fill(text)
  const pending=p.waitForResponse(r=>r.url().endsWith('/messages')&&r.request().method()==='POST')
  await p.getByRole('button',{name:'Отправить сообщение',exact:true}).click()
  assert.equal((await pending).status(),201)
  await expect(p.getByText(text,{exact:true})).toBeVisible()
 }
 await send(a,'Synthetic request A','support-a.txt')
 await help(b);const bs=(await navData(b)).direct_messages.find(x=>x.other_participant_id===sid)?.id;assert.ok(bs);assert.notEqual(as,bs)
 await send(b,'Synthetic request B','support-b.txt')
 await nav(s)
 await expect(s.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_a'})).toBeVisible()
 await expect(s.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_b'})).toBeVisible()
 await s.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_a'}).click()
 await expect(s.getByText('Synthetic request A',{exact:true})).toBeVisible()
 await expect(s.getByText('Synthetic request B',{exact:true})).toHaveCount(0)
 const requestRow=s.locator('li[data-message-id]').filter({hasText:'Synthetic request A'})
 await requestRow.hover();await requestRow.getByRole('button',{name:'Ответить',exact:true}).click()
 await send(s,'Synthetic operator reply A')
 await expect(a.getByRole('button',{name:'Открыть контекст ответа'})).toBeVisible()
 await expect(a.getByText('Synthetic operator reply A',{exact:true})).toBeVisible()
 await nav(s);await s.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_b'}).click();await send(s,'Synthetic operator reply B')
 await expect(b.getByText('Synthetic operator reply B',{exact:true})).toBeVisible()
 report.ordinary_pair_messages_files_realtime=true
 for(const stranger of [b,admin]) assert.equal((await api(stranger,`/direct-messages/${as}/messages`)).status,404)
 const history=(await api(a,`/direct-messages/${as}/messages`)).body
 const attachment=history.messages.find(x=>x.body==='Synthetic request A').attachments[0].id
 const fileStatus=async p=>p.evaluate(async path=>(await fetch(path,{credentials:'same-origin'})).status,`/api/v1/direct-messages/${as}/attachments/${attachment}`)
 assert.equal(await fileStatus(s),200);assert.equal(await fileStatus(b),404);assert.equal(await fileStatus(admin),404)
 report.pair_only_history_and_file_acl=true
 await nav(a);await a.locator('.direct-message-navigation .channel-button').filter({hasText:'qa_support_b'}).click();await expect(a.locator('#direct-message-body')).toHaveValue('Synthetic unsent other DM')
 await help(a);assert.equal((await navData(a)).direct_messages.find(x=>x.other_participant_id===sid)?.id,as)
 await a.context().setOffline(true);await a.context().setOffline(false);await a.reload();await help(a);await expect(a.getByText('Synthetic operator reply A',{exact:true})).toBeVisible()
 report.draft_reuse_history_reload=true
 await help(s);await expect(s.getByText('Вы назначены поддержкой этого сервера.',{exact:false})).toBeVisible()
 report.operator_self_no_dm=true
 for(const width of [393,320]){
  await a.setViewportSize({width,height:800});await openNavigation(a)
  const target=await a.getByRole('button',{name:'Помощь и обратная связь',exact:true}).boundingBox();assert.ok(target.width>=44&&target.height>=44)
  await expect(a.locator('.support-row')).toBeVisible()
  await a.screenshot({path:`${input.directory}/03-drawer-${width}.png`,fullPage:true})
  await help(a);await a.locator('#direct-message-body').focus()
  assert.equal(await a.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true)
  await a.screenshot({path:`${input.directory}/04-conversation-${width}.png`,fullPage:true})
 }
 await a.evaluate(()=>document.documentElement.style.fontSize='200%');await openNavigation(a)
 await a.screenshot({path:input.directory+'/05-large-text-drawer.png',fullPage:true});await help(a)
 const composerBox=await a.locator('#direct-message-body').boundingBox();assert.ok(composerBox.y>=0 && composerBox.y+composerBox.height<=800)
 await a.screenshot({path:input.directory+'/06-large-text-conversation.png',fullPage:true})
 report.mobile_footer_target_and_layout=true
 await a.evaluate(()=>document.documentElement.style.fontSize='');await a.setViewportSize({width:1440,height:960})
 configure(bid);await help(a)
 await expect(a.getByRole('heading',{name:'Поддержка',exact:true})).toBeVisible()
 assert.equal((await navData(a)).direct_messages.find(x=>x.other_participant_id===bid)?.id,other.body.id)
 assert.equal((await api(b,`/direct-messages/${as}/messages`)).status,404)
 await nav(a);await expect(a.locator('.direct-message-navigation').getByText('Оператор поддержки изменился. Старые диалоги сохраняют прежних участников и историю.',{exact:true})).toBeVisible()
 await expect(a.locator('.support-privacy')).toContainText('Оператор поддержки изменился.')
 await a.screenshot({path:input.directory+'/07-operator-replaced.png',fullPage:true})
 report.replacement_keeps_old_pair_private=true
 const blocked=await api(admin,`/admin/accounts/${bid}`,'PATCH',{role:'MEMBER',blocked:true});assert.equal(blocked.status,200)
 await a.setViewportSize({width:320,height:800});await help(a)
 await expect(a.getByText('Поддержка этого сервера сейчас недоступна. Повторите позже.',{exact:true})).toBeVisible()
 await expect(a.locator('.support-row')).toHaveCount(0)
 assert.equal((await api(a,`/direct-messages/${other.body.id}/messages`,'POST',{client_message_id:randomUUID(),body:'Synthetic blocked send'})).status,404)
 report.blocked_contact_and_mobile_quiet_status=true
 assert.deepEqual(egress,[]);report.external_requests=0
 report.physical_screen_runtime='NOT_RUN';report.physical_acceptance='NOT_RUN'
 writeFileSync(input.directory+'/browser.json',JSON.stringify(report,null,2)+'\n')
 console.log('Support DM: real API/browser scenarios passed; synthetic captures saved.')
} catch(error) {
 for(const [index,context] of browser.contexts().entries()) for(const page of context.pages()) await page.screenshot({path:input.directory+`/failure-${index}.png`,fullPage:true}).catch(()=>{})
 throw error
} finally {await browser.close()}
