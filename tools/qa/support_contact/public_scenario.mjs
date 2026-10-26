// Real owned Go API and production Vue components; does not publish test issues.
import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {randomUUID} from 'node:crypto'
import {execFileSync} from 'node:child_process'
import {chromium,expect,origin,login,api} from '../client_lifecycle/request.mjs'
assert.equal(origin,'https://localhost:4810')
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const browser=await chromium.launch()
try{
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:960}})
 const page=await context.newPage();await login(page,'qa_support_a',input.password)
 const contact=(await api(page,'/direct-messages')).body.support_contact
 assert.equal(contact.mode,'product');assert.equal(contact.consent_required,true)
 await page.getByRole('button',{name:'Помощь и обратная связь',exact:true}).click()
 await expect(page.getByText('Согласен на публикацию',{exact:true})).toBeVisible()
 await expect(page.locator('.support-privacy')).toContainText('общедоступны')
 await expect(page.locator('#direct-message-body')).toHaveCount(0)
 const pair=(await api(page,'/direct-messages')).body.direct_messages.find(row=>row.other_participant_id===contact.account_id)
 assert.ok(pair)
 const postMessage=body=>page.evaluate(async({id,body})=>(await fetch(`/api/v1/direct-messages/${id}/messages`,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/json','X-Boohtacord-Support-Publication':'v1'},body:JSON.stringify(body)})).status,{id:pair.id,body})
 assert.equal(await postMessage({client_message_id:randomUUID(),body:'Synthetic denied public support request'}),404)
 await page.screenshot({path:input.directory+'/public-01-consent-desktop.png',fullPage:true})
 await page.setViewportSize({width:393,height:852})
 await page.screenshot({path:input.directory+'/public-02-consent-mobile.png',fullPage:true})
 const accepted=page.waitForResponse(r=>r.url().endsWith('/support/consent')&&r.request().method()==='POST')
 await page.getByRole('button',{name:'Согласен на публикацию',exact:true}).click()
 assert.equal((await accepted).status(),204)
 await expect(page.locator('#direct-message-body')).toBeVisible()
 await expect(page.locator('.support-privacy')).toContainText('общедоступны')
 assert.equal((await api(page,'/direct-messages')).body.support_contact.consent_required,false)
 assert.equal((await api(page,`/direct-messages/${pair.id}/messages`,'POST',{client_message_id:randomUUID(),body:'Synthetic denied legacy client request'})).status,409)
 await page.screenshot({path:input.directory+'/public-03-consented-mobile.png',fullPage:true})
 const report={status:'PASS',default_product:true,explicit_consent:true,server_denies_without_consent:true,legacy_client_cannot_publish_after_other_device_consent:true,notice_persists:true,github_publication:'NOT_RUN in repeatable local QA; separate controlled live proof required'}
 if(process.env.BOOHTACORD_SUPPORT_QA_OPERATOR){
  const marker='Synthetic BOOHTACORD public bridge QA '+randomUUID().replaceAll('-','').slice(0,16)
  const operator=phase=>JSON.parse(execFileSync('python3',['-m','tools.qa.support_contact.live_operator',marker,phase],{encoding:'utf8',timeout:120000}))
  const upload=page.waitForResponse(r=>r.url().includes('/attachments')&&r.request().method()==='POST')
  await page.locator('#dm-attachments').setInputFiles({name:'synthetic-public-support.txt',mimeType:'text/plain',buffer:Buffer.from('Synthetic public support QA file\n')})
  assert.equal((await upload).status(),201)
  await page.screenshot({path:input.directory+'/public-file-before-text.png',fullPage:true})
  const geometry=await page.locator('#direct-message-body').evaluate(e=>{const c=getComputedStyle(e),r=e.getBoundingClientRect();return {width:r.width,height:r.height,display:c.display,visibility:c.visibility,flex:c.flex,heightStyle:e.style.height,maxHeight:c.maxHeight,minHeight:c.minHeight}})
  writeFileSync(input.directory+'/public-file-geometry.json',JSON.stringify(geometry))
  assert.ok(geometry.width>100&&geometry.height>=40,'Attachment queue must keep the composer visible')
  await page.locator('#direct-message-body').fill(marker)
  const sending=page.waitForResponse(r=>r.url().endsWith('/messages')&&r.request().method()==='POST')
  await page.getByRole('button',{name:'Отправить сообщение',exact:true}).click();assert.equal((await sending).status(),201)
  const live=operator('reply')
  await expect(page.getByText('Synthetic BOOHTACORD public bridge operator reply',{exact:true})).toBeVisible({timeout:60000})
  await page.screenshot({path:input.directory+'/public-04-github-reply-mobile.png',fullPage:true})
  assert.equal(await postMessage({client_message_id:randomUUID(),body:marker+' follow-up'}),201)
  assert.equal(operator('followup').issue,live.issue)
  report.github_publication='PASS';report.live_issue=`https://github.com/Egkurilov/BOOHTACORD/issues/${live.issue}`
  report.public_file_verified=live.public_file_verified;report.issue_reply_visible=true;report.followup_same_issue=true
  assert.equal(operator('close').closed,true)
 }
 writeFileSync(input.directory+'/public-browser.json',JSON.stringify(report,null,2)+'\n')
}finally{await browser.close()}
