import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, expect, login, api, status, channel, openNavigation, security } from '../client_lifecycle/request.mjs'
import { sql, owned } from '../next_client_acceptance/fixture.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const report = {issue:264,width:input.width,checks:{},roles:['MEMBER','MEMBER','ADMIN'],mocks:false,controlled_faults:['held actual HTTP responses','owned API stop/restart','owned SQL stale-access fixtures']}
const browser = await chromium.launch()
const contexts = []
const releases = []
let phase = 'fixture setup'
const canary = 'Synthetic private mention content'
async function client(name) {
  const context = await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:input.width,height:900}})
  context.setDefaultTimeout(20000); contexts.push(context)
  const page = await context.newPage(); await login(page,name,input.password);return page
}
async function inbox(page) {
  if (!await page.getByTestId('search-panel').isVisible()) {
    await openNavigation(page)
    await page.locator('.guild-search-button').click()
  }
  await page.getByTestId('search-panel').getByRole('button',{name:'Упоминания',exact:true}).click()
  const p=page.getByTestId('mention-inbox')
  await expect(p).toBeVisible();return p
}
async function closeSearch(page) {
  if (await page.getByTestId('search-panel').isVisible()) await page.getByRole('button',{name:'Закрыть поиск',exact:true}).click()
}
async function refresh(p) {
  await p.getByRole('button',{name:'Обновить',exact:true}).click()
  await expect(p.getByRole('button',{name:'Обновить',exact:true})).toBeEnabled()
}
async function allRows(p) {
  for(let page=0; page<4 && await p.getByRole('button',{name:'Показать ещё',exact:true}).count();page++) {
    await p.getByRole('button',{name:'Показать ещё',exact:true}).click()
    await expect(p.getByRole('button',{name:'Обновить',exact:true})).toBeEnabled()
  }
  return p.locator('.search-result')
}
async function capture(page,p,name) {
  await page.bringToFront()
  await page.evaluate(async()=>{await document.fonts.ready;await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))})
  await p.locator('.mention-inbox-toolbar').scrollIntoViewIfNeeded()
  const box=await p.boundingBox(), viewport=page.viewportSize()
  assert.ok(box && viewport)
  const x=Math.max(0,box.x), y=Math.max(0,box.y)
  await page.screenshot({path:input.directory+'/'+name+'.png',clip:{x,y,width:Math.min(box.width,viewport.width-x),height:Math.min(box.height,viewport.height-y)}})
}
async function send(page,path,target) {
  const result=await api(page,path+'/messages','POST',{client_message_id:randomUUID(),body:canary,mention_user_ids:[target]})
  status(result,201);return result.body
}
async function metadata(page) {
  const result=await api(page,'/mentions?limit=100');status(result,200)
  for(const item of result.body.mentions) assert.deepEqual(Object.keys(item).sort(),['author_id','conversation_id','created_at','kind','message_id'])
  assert.ok(!JSON.stringify(result.body).includes(canary))
  return result.body.mentions
}
function seed(channelId,author,recipient) {
  for(const id of [channelId,author,recipient]) assert.match(id,/^[a-f0-9-]{36}$/)
  const ids=Array.from({length:55},()=>randomUUID())
  const rows=ids.map((id,i)=>`('${id}','${channelId}','${author}','${randomUUID()}','Synthetic pagination message',ARRAY['${recipient}']::uuid[],TIMESTAMPTZ '2026-01-01' + INTERVAL '${i} seconds')`)
  sql(`INSERT INTO messages(id,channel_id,author_id,client_message_id,body,mention_user_ids,created_at) VALUES ${rows.join(',')}`)
  return ids
}
async function logout(page) {
  await closeSearch(page)
  await security(page)
  await page.getByRole('button',{name:'Выйти из аккаунта',exact:true}).click()
  await page.getByRole('dialog',{name:'Подтвердите выход из аккаунта'}).getByRole('button',{name:'Выйти',exact:true}).click()
  await expect(page.locator('.authentication-page')).toBeVisible()
}
async function signInSamePage(page,name) {
  await page.getByLabel('Логин',{exact:true}).fill(name)
  await page.getByLabel('Пароль',{exact:true}).fill(input.password)
  await page.getByRole('button',{name:'Войти',exact:true}).click()
  await expect(page.getByTestId('app-shell')).toBeVisible()
}
async function heldMentions(page) {
  let release, arrived
  const held=new Promise(resolve=>release=resolve), started=new Promise(resolve=>arrived=resolve)
  releases.push(release)
  const pattern='**/api/v1/mentions'
  const handler=async route=>{
    const response=await route.fetch()
    arrived();await held
    try {await route.fulfill({response})} catch (cause) {
      if (!/has been closed|already handled|Invalid InterceptionId/.test(String(cause.message))) throw cause
    }
  }
  await page.route(pattern,handler,{times:1})
  return {started,release,cleanup:()=>page.unroute(pattern,handler)}
}
try {
  const c=await client('qa_admin')
  const ar=await api(c,'/auth/register','POST',{login:'qa_mentions_a',password:input.password});status(ar,201)
  const br=await api(c,'/auth/register','POST',{login:'qa_mentions_b',password:input.password});status(br,201)
  const a=await client('qa_mentions_a'),b=await client('qa_mentions_b')
  const cId=(await api(c,'/auth/session')).body.account_id
  status(await api(a,'/me','PATCH',{display_name:'Получатель проверки'}),200)
  status(await api(b,'/me','PATCH',{display_name:'Автор проверки'}),200)
  const category=await api(c,'/admin/categories','POST',{name:'QaMentions'});status(category,201)
  const ch=await api(c,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaMentions',kind:'TEXT'});status(ch,201)
  const stale=await api(c,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaStale',kind:'TEXT'});status(stale,201)
  const dm=await api(a,'/direct-messages','POST',{participant_id:br.body.id});status(dm,201)
  const older=seed(ch.body.id,br.body.id,ar.body.id)
  const text=await send(b,'/channels/'+ch.body.id,ar.body.id)
  const direct=await send(b,'/direct-messages/'+dm.body.id,ar.body.id)
  await send(a,'/channels/'+ch.body.id,br.body.id)
  await send(b,'/channels/'+ch.body.id,cId)
  await a.reload();await b.reload();await c.reload()
  phase='recipient metadata and real cursor paging'
  let p=await inbox(a)
  await expect(p.locator('.search-result')).toHaveCount(50)
  const rows=await allRows(p);await expect(rows).toHaveCount(57)
  assert.ok(!(await p.innerText()).includes(canary))
  await expect(p.locator('.search-result-author strong').first()).toHaveText('Автор проверки')
  const records=await metadata(a)
  assert.equal(records.length,57);assert.equal(new Set(records.map(v=>v.kind+v.message_id)).size,57)
  assert.ok(records.some(v=>v.kind==='DIRECT_MESSAGE'&&v.message_id===direct.id))
  assert.ok(records.some(v=>v.kind==='CHANNEL'&&v.message_id===text.id))
  await capture(a,p,'recipient-metadata')
  report.checks.recipient_metadata_only_cursor_no_duplicates='PASS'
  phase='author and third administrator account isolation'
  for(const [page,expected] of [[b,br.body.id],[c,cId]]) {
    const q=await inbox(page);await expect(q.locator('.search-result')).toHaveCount(1)
    const items=await metadata(page);assert.equal(items.length,1);assert.ok(items.every(v=>v.kind==='CHANNEL'))
    assert.ok(!items.some(v=>v.conversation_id===dm.body.id))
    await closeSearch(page)
  }
  const denied=await api(c,'/direct-messages/'+dm.body.id+'/messages')
  status(denied,404);report.third_admin_history_status=denied.status
  report.checks.author_and_third_inbox_isolation='PASS'
  phase='TEXT keyboard focus activation and exact protected history'
  p=await inbox(a)
  const textRow=p.locator('.search-result').filter({has:a.locator('header').filter({hasText:'#QaMentions'})}).first()
  const textButton=textRow.getByRole('button')
  for(let i=0;i<12&&!await textButton.evaluate(el=>el===document.activeElement);i++) await a.keyboard.press('Tab')
  phase='TEXT result keyboard focus'
  await expect(textButton).toBeFocused()
  const history=a.waitForResponse(r=>new URL(r.url()).pathname==='/api/v1/channels/'+ch.body.id+'/messages'&&new URL(r.url()).searchParams.get('at')===text.id)
  phase='TEXT result Enter and history response'
  await a.keyboard.press('Enter');assert.equal((await history).status(),200)
  const context=a.getByTestId('search-message-context')
  phase='TEXT exact anchor'
  await expect(context.locator('[data-search-anchor]')).toHaveAttribute('data-message-id',text.id)
  await context.getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  p=await inbox(a)
  phase='DM exact protected history'
  const dmRow=p.locator('.search-result').filter({has:a.locator('header').filter({hasText:'Автор проверки'})}).first()
  const dmHistory=a.waitForResponse(r=>new URL(r.url()).pathname==='/api/v1/direct-messages/'+dm.body.id+'/messages'&&new URL(r.url()).searchParams.get('at')===direct.id)
  await dmRow.getByRole('button').click();assert.equal((await dmHistory).status(),200)
  await expect(context.locator('[data-search-anchor]')).toHaveAttribute('data-message-id',direct.id)
  await context.getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  report.checks.TEXT_DM_exact_origin_and_keyboard_activation='PASS'
  phase='rename edit remove delete and paginated recovery'
  p=await inbox(a)
  status(await api(b,'/me','PATCH',{display_name:'Автор обновлён'}),200)
  await expect(p.locator('.search-result-author strong').first()).toHaveText('Автор обновлён')
  status(await api(b,`/channels/${ch.body.id}/messages/${text.id}`,'PATCH',{body:canary,expected_revision:1,mention_user_ids:[]}),200)
  status(await api(b,`/direct-messages/${dm.body.id}/messages/${direct.id}`,'DELETE'),204)
  status(await api(b,`/channels/${ch.body.id}/messages/${older[0]}`,'DELETE'),204)
  await refresh(p);await allRows(p);await expect(p.locator('.search-result')).toHaveCount(54)
  const after=await metadata(a)
  assert.equal(after.length,54);assert.equal(new Set(after.map(v=>v.message_id)).size,54)
  assert.ok(!after.some(v=>[text.id,direct.id,older[0]].includes(v.message_id)))
  await capture(a,p,'renamed-clean-paged-metadata')
  report.checks.rename_remove_delete_refresh_cursor='PASS'
  phase='stale non-TEXT target fails closed'
  const staleMessage=await send(b,'/channels/'+stale.body.id,ar.body.id)
  await refresh(p)
  const staleRow=p.locator('.search-result').first()
  await expect(staleRow).toHaveCount(1)
  assert.equal((await metadata(a))[0].message_id,staleMessage.id)
  sql(`UPDATE channels SET kind='VOICE' WHERE id='${stale.body.id}'; UPDATE channel_topology_state SET revision=revision+1`)
  await staleRow.getByRole('button').click()
  await expect(a.getByRole('alert').filter({hasText:'Канал с упоминанием больше недоступен.'})).toBeVisible()
  assert.equal(await context.count(),0)
  const nonTextDenied=await api(a,`/channels/${stale.body.id}/messages?at=${staleMessage.id}&limit=20`)
  status(nonTextDenied,404);report.stale_non_TEXT_history_status=nonTextDenied.status
  report.checks.stale_non_TEXT_rejected='PASS'
  phase='stale archived target fails closed'
  sql(`UPDATE channels SET kind='TEXT' WHERE id='${stale.body.id}'; UPDATE channel_topology_state SET revision=revision+1`)
  await a.reload();p=await inbox(a)
  await expect(staleRow).toHaveCount(1)
  const topology=await api(c,'/channels');status(topology,200)
  status(await api(c,`/admin/channels/${stale.body.id}`,'DELETE',{expected_revision:topology.body.revision,confirm_archive:true}),200)
  await staleRow.getByRole('button').click()
  await expect(a.getByRole('alert').filter({hasText:'Канал с упоминанием больше недоступен.'})).toBeVisible()
  assert.equal(await context.count(),0)
  report.checks.stale_archived_rejected='PASS'
  phase='stale foreign DM target fails closed'
  const staleDM=await send(b,'/direct-messages/'+dm.body.id,ar.body.id)
  await refresh(p)
  const staleDMRow=p.locator('.search-result').first()
  await expect(staleDMRow).toHaveCount(1)
  assert.equal((await metadata(a))[0].message_id,staleDM.id)
  const pair=[br.body.id,cId].sort()
  sql(`UPDATE direct_messages SET participant_one_id='${pair[0]}',participant_two_id='${pair[1]}' WHERE id='${dm.body.id}'`)
  await staleDMRow.getByRole('button').click()
  await expect(a.getByRole('alert').filter({hasText:'Личный диалог больше недоступен.'})).toBeVisible()
  assert.equal(await context.count(),0)
  const foreignDenied=await api(a,`/direct-messages/${dm.body.id}/messages?at=${staleDM.id}&limit=20`)
  status(foreignDenied,404);report.stale_foreign_DM_history_status=foreignDenied.status
  report.checks.stale_foreign_DM_rejected='PASS'
  phase='loading empty error refresh UI'
  await closeSearch(a)
  const held=await heldMentions(a)
  p=await inbox(a);await held.started
  await expect(p.getByText('Загружаем упоминания…',{exact:true})).toHaveCSS('clip-path','none')
  await capture(a,p,'loading-metadata')
  held.release();await held.cleanup()
  await expect(p.locator('.search-result')).toHaveCount(50)
  owned('api','stop','$owned')
  try {await refresh(p);await expect(p.getByRole('alert')).toBeVisible();await capture(a,p,'error-metadata')}
  finally {owned('api','start','$owned')}
  await expect.poll(async()=>{try{return(await api(a,'/health')).status}catch{return 0}},{timeout:30000}).toBe(200)
  await refresh(p);await expect(p.locator('.search-result')).toHaveCount(50)
  report.checks.loading_error_refresh='PASS'
  phase='mention picker arrows Enter Escape and composition guards'
  await closeSearch(a);await channel(a,'QaMentions')
  const composer=a.locator('#message-body')
  await composer.fill('@')
  const options=a.getByRole('listbox',{name:'Подсказки упоминаний'})
  await expect(options).toBeVisible()
  await a.keyboard.press('ArrowDown');await a.keyboard.press('ArrowUp');await a.keyboard.press('Escape')
  await expect(options).toBeHidden();await expect(composer).toHaveValue('@')
  await composer.fill('@Авт')
  await expect(options.getByRole('option')).toHaveCount(1)
  await composer.dispatchEvent('compositionstart',{data:'Авт'})
  await expect(options).toBeHidden()
  let composingSends=0
  const onRequest=r=>{if(r.method()==='POST'&&new URL(r.url()).pathname.endsWith('/messages'))composingSends++}
  a.on('request',onRequest)
  await composer.dispatchEvent('keydown',{key:'Enter',code:'Enter',isComposing:true,bubbles:true})
  await expect(composer).toHaveValue('@Авт');assert.equal(composingSends,0)
  await composer.dispatchEvent('compositionend',{data:'Авт'})
  await expect(options).toBeVisible();await a.keyboard.press('Enter')
  await expect(composer).toHaveValue('@Автор обновлён ');assert.equal(composingSends,0)
  a.off('request',onRequest);await composer.fill('')
  report.checks.picker_arrows_Enter_Escape_controlled_composition='PASS'
  phase='same-page logout account switch ignores held previous-account data'
  p=await inbox(a)
  const old=await heldMentions(a)
  await p.getByRole('button',{name:'Обновить',exact:true}).click();await old.started
  await logout(a)
  await expect(a.getByTestId('mention-inbox')).toHaveCount(0)
  await signInSamePage(a,'qa_admin')
  old.release();await old.cleanup()
  p=await inbox(a);await expect(p.locator('.search-result')).toHaveCount(1)
  assert.equal((await metadata(a)).length,1)
  await capture(a,p,'switched-admin-metadata')
  await logout(a);await signInSamePage(a,'qa_mentions_b')
  p=await inbox(a);await expect(p.locator('.search-result')).toHaveCount(1)
  assert.equal((await metadata(a)).length,1)
  report.checks.same_page_logout_account_switch_no_old_data='PASS'
  phase='empty inbox state'
  const own=await api(a,'/mentions');status(own,200)
  const ownMessage=own.body.mentions[0]
  status(await api(await client('qa_mentions_a'),`/channels/${ownMessage.conversation_id}/messages/${ownMessage.message_id}`,'DELETE'),204)
  await refresh(p);await expect(p.getByText('Пока нет упоминаний.',{exact:true})).toHaveCSS('clip-path','none')
  await capture(a,p,'empty-metadata')
  report.checks.empty_inbox='PASS'
  report.status='PASS';report.browser=browser.version()
} catch (cause) {
  report.status='FAIL';report.failed_phase=phase;report.failure_type=cause?.name??'unknown'
  throw Error('Sanitized #264 acceptance failure at phase: '+phase)
} finally {
  for(const release of releases)release()
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')
  for(const context of contexts)await context.close()
  await browser.close()
}
