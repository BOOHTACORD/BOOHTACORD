import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { readFileSync, writeFileSync } from 'node:fs'
import { chromium, expect, login, api, status, channel, openNavigation } from '../client_lifecycle/request.mjs'
import { sql } from '../next_client_acceptance/fixture.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const report = {issue:254,width:input.width,checks:{},roles:['MEMBER','MEMBER','ADMIN'],mocks:false,fixture:'Actual uploads/messages; 50 synthetic body-only SQL messages per scope to exercise older history pages; no attachment row/file seeding'}
let phase = 'setup'
const browser = await chromium.launch()
const contexts = []
const observed = new WeakMap()
async function client(name) {
  const context = await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:input.width,height:900}})
  contexts.push(context); context.setDefaultTimeout(20000)
  const page = await context.newPage()
  const counts = {deleted:0,ready:0,resync:0}; observed.set(page, counts)
  page.on('websocket', socket => socket.on('framereceived', frame => {
    try {
      const kind = JSON.parse(String(frame.payload)).kind
      if (kind === 'message.deleted' || kind === 'direct_message.message_deleted') counts.deleted++
      if (kind === 'connection.ready') counts.ready++
      if (kind === 'connection.resync_required') counts.resync++
    } catch { /* discard payload; keep only counts */ }
  }))
  await login(page,name,input.password); return page
}
async function dm(page, peer) {
  await openNavigation(page)
  await page.getByRole('button',{name:'Личные',exact:true}).click()
  await page.locator('.direct-message-navigation .channel-button').filter({hasText:peer}).click()
}
async function text(page, name) {
  await openNavigation(page)
  await page.getByRole('button',{name:'Каналы',exact:true}).click()
  await channel(page,name)
}
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNoaGj4DwAFhAKAjM1mJgAAAABJRU5ErkJggg==','base64')
async function sendFiles(page, prefix, files) {
  const selector = prefix.startsWith('/channels/') ? '#message-attachments' : '#dm-attachments'
  phase = prefix.startsWith('/channels/') ? 'text file input' : 'dm file input'
  await page.locator(selector).setInputFiles(files.map(name=>({name,mimeType:'image/png',buffer:png})))
  phase = 'wait uploaded file queue'
  await expect(page.locator('.attachment-picker [data-upload-status="done"]')).toHaveCount(files.length)
  const response = page.waitForResponse(r=>r.request().method()==='POST' && new URL(r.url()).pathname==='/api/v1'+prefix+'/messages')
  phase = 'actual attachment message send click'
  await page.getByRole('button',{name:'Отправить сообщение',exact:true}).click()
  const result = await response; assert.equal(result.status(),201)
  phase = 'queue cleared after server ACK'
  await expect(page.locator('.attachment-picker [data-upload-status]')).toHaveCount(0)
  const sent = await result.json()
  const history = await api(page,prefix+'/messages?at='+sent.id+'&limit=20')
  status(history,200)
  const confirmed = history.body.messages.find(message=>message.id===sent.id)
  assert.ok(confirmed)
  return confirmed
}
function fillers(kind,id,author) {
  const table=kind==='TEXT'?'messages':'direct_message_messages', scope=kind==='TEXT'?'channel_id':'direct_message_id'
  for (const value of [id,author]) assert.match(value,/^[a-f0-9-]{36}$/)
  const rows=Array.from({length:50},()=>`('${randomUUID()}','${id}','${author}','${randomUUID()}','Synthetic pagination filler')`)
  sql(`INSERT INTO ${table}(id,${scope},author_id,client_message_id,body) VALUES ${rows.join(',')}`)
}
async function pageDelay(page,ms) { await page.waitForTimeout(ms) }
async function panel(page) {
  phase = 'open conversation overflow and files panel'
  await page.getByRole('button',{name:'Другие действия',exact:true}).click()
  await page.getByRole('menuitem',{name:'Файлы беседы',exact:true}).click()
  const p=page.locator('.conversation-files')
  phase = 'files panel keyboard focus'
  await expect(p.getByRole('heading',{name:'Файлы беседы'})).toBeFocused()
  return p
}
async function loaded(page) {
  const p=await panel(page)
  phase = 'files initial latest page'
  await expect(p.locator('tbody tr')).toHaveCount(1)
  phase = 'load older file cursor'
  await p.getByRole('button',{name:'Показать более старые файлы',exact:true}).click()
  await expect(p.locator('tbody tr')).toHaveCount(3)
  return p
}
async function metadata(p,names) {
  await p.evaluate(async () => {
    await document.fonts.load('500 14px Inter')
    await document.fonts.ready
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
  })
  const fits = await p.locator('th').evaluateAll(headers => headers.every(header => {
    const range = document.createRange(); range.selectNodeContents(header)
    const ink = range.getBoundingClientRect(), cell = header.getBoundingClientRect()
    const style = getComputedStyle(header)
    return ink.left >= cell.left + parseFloat(style.paddingLeft) - 0.5 && ink.right <= cell.right - parseFloat(style.paddingRight) + 0.5
  }))
  assert.ok(fits, 'File table headings must fit their own padded cells')
  for (const name of names) {
    const row=p.locator('tbody tr').filter({hasText:name})
    await expect(row).toHaveCount(1)
    await expect(row.locator('td').nth(0)).toHaveText('PNG')
    await expect(row.locator('td').nth(2)).toHaveText(png.length+' Б')
    await expect(row.locator('time')).toHaveAttribute('datetime',/\d{4}-\d{2}-\d{2}T/)
  }
}
async function fileStatuses(page,prefix,id) {
  return page.evaluate(async ({prefix,id})=>{
    const result=[]
    for (const suffix of ['', '/preview']) {
      const r=await fetch('/api/v1'+prefix+'/attachments/'+id+suffix,{credentials:'same-origin'})
      result.push(r.status); await r.arrayBuffer()
    }
    return result
  },{prefix,id})
}
try {
  const admin = await client('qa_admin')
  const aReg=await api(admin,'/auth/register','POST',{login:'qa_files_a',password:input.password});status(aReg,201)
  const bReg=await api(admin,'/auth/register','POST',{login:'qa_files_b',password:input.password});status(bReg,201)
  const category=await api(admin,'/admin/categories','POST',{name:'QaFiles'});status(category,201)
  const first=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaFilesA',kind:'TEXT'});status(first,201)
  status(await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaFilesB',kind:'TEXT'}),201)
  const a=await client('qa_files_a'), b=await client('qa_files_b')
  const primary=await api(a,'/direct-messages','POST',{participant_id:bReg.body.id});status(primary,201)
  const second=await api(a,'/direct-messages','POST',{participant_id:(await api(admin,'/auth/session')).body.account_id});status(second,201)
  for(const page of [a,b]) await page.reload()
  phase='text upload and pagination'
  phase='select TEXT as member B'
  await text(b,'QaFilesA')
  const textOld=await sendFiles(b,'/channels/'+first.body.id,['text-old-one.png','text-old-two.png'])
  fillers('TEXT',first.body.id,bReg.body.id)
  phase='select TEXT as member A'
  await text(a,'QaFilesA')
  const textNew=await sendFiles(a,'/channels/'+first.body.id,['text-new.png'])
  await a.reload()
  let p=await loaded(a)
  await metadata(p,['text-new.png','text-old-one.png','text-old-two.png'])
  await p.screenshot({path:input.directory+'/text-files-paginated.png'})
  await p.getByRole('button',{name:'Перейти к сообщению с файлом text-old-one.png',exact:true}).click()
  await expect(a.getByTestId('search-message-context').locator('[data-search-anchor]')).toBeVisible()
  await a.getByTestId('search-message-context').getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  p=await loaded(a)
  report.checks.text_metadata_cursor_and_origin_navigation='PASS'
  report.text_participant_file_statuses=await fileStatuses(a,'/channels/'+first.body.id,textNew.attachments[0].id)
  assert.deepEqual(report.text_participant_file_statuses,[200,200])
  phase='text peer deletion while older page open'
  const textDeleted = await api(b,`/channels/${first.body.id}/messages/${textOld.id}`,'DELETE')
  report.text_delete_http_status = textDeleted.status
  status(textDeleted,204)
  await pageDelay(a,600)
  report.text_delete_observation = {ws_counts:{...observed.get(a)}, rows:await p.locator('tbody tr').count(), visibility:await a.evaluate(()=>document.visibilityState)}
  const oldHistory = await api(a,`/channels/${first.body.id}/messages?at=${textOld.id}&limit=20`)
  report.text_delete_observation.server_deleted = oldHistory.status===200 && oldHistory.body.messages.some(m=>m.id===textOld.id && m.deleted && m.attachments.length===0)
  await expect(p.locator('tbody tr')).toHaveCount(1)
  report.text_deleted_file_statuses=await fileStatuses(a,'/channels/'+first.body.id,textOld.attachments[0].id)
  assert.deepEqual(report.text_deleted_file_statuses,[404,404])
  report.checks.text_previous_page_peer_delete_live='PASS'
  phase='dm upload and pagination'
  await dm(b,'qa_files_a')
  const dmOld=await sendFiles(b,'/direct-messages/'+primary.body.id,['dm-old-one.png','dm-old-two.png'])
  fillers('DM',primary.body.id,bReg.body.id)
  await dm(a,'qa_files_b')
  const dmNew=await sendFiles(a,'/direct-messages/'+primary.body.id,['dm-new.png'])
  await a.reload(); await dm(a,'qa_files_b')
  p=await loaded(a)
  await metadata(p,['dm-new.png','dm-old-one.png','dm-old-two.png'])
  await p.screenshot({path:input.directory+'/dm-files-paginated.png'})
  await b.reload(); await dm(b,'qa_files_a')
  const bp=await loaded(b); await metadata(bp,['dm-new.png','dm-old-one.png','dm-old-two.png'])
  report.checks.dm_both_participants_metadata_cursor='PASS'
  phase='ACL actual protected requests'
  report.acl_participant_a = await fileStatuses(a,'/direct-messages/'+primary.body.id,dmNew.attachments[0].id)
  assert.deepEqual(report.acl_participant_a,[200,200])
  report.acl_participant_b = await fileStatuses(b,'/direct-messages/'+primary.body.id,dmNew.attachments[0].id)
  assert.deepEqual(report.acl_participant_b,[200,200])
  report.acl_third_history_status = (await api(admin,'/direct-messages/'+primary.body.id+'/messages')).status
  assert.equal(report.acl_third_history_status,404)
  report.acl_third_files = await fileStatuses(admin,'/direct-messages/'+primary.body.id,dmNew.attachments[0].id)
  assert.deepEqual(report.acl_third_files,[404,404])
  const anon=await browser.newContext({ignoreHTTPSErrors:true});contexts.push(anon)
  const outsider=await anon.newPage();await outsider.goto(process.env.QA_ORIGIN)
  const denied=await fileStatuses(outsider,'/direct-messages/'+primary.body.id,dmNew.attachments[0].id)
  assert.ok(denied.every(code=>code===401||code===404))
  report.text_anonymous_file_statuses=await fileStatuses(outsider,'/channels/'+first.body.id,textNew.attachments[0].id)
  assert.ok(report.text_anonymous_file_statuses.every(code=>code===401||code===404))
  report.checks.acl={status:'PASS',participants_download_preview:[200,200],third_admin_history_download_preview:[404,404,404],anonymous_download_preview:denied}
  phase='DM navigation to origin'
  await p.getByRole('button',{name:'Перейти к сообщению с файлом dm-old-one.png',exact:true}).click()
  await expect(a.getByTestId('search-message-context').locator('[data-search-anchor]')).toBeVisible()
  await a.getByTestId('search-message-context').getByRole('button',{name:'Вернуться к исходной позиции',exact:true}).click()
  p=await loaded(a)
  phase='DM peer deletion while older page open'
  const dmDeleted = await api(b,`/direct-messages/${primary.body.id}/messages/${dmOld.id}`,'DELETE')
  report.dm_delete_http_status = dmDeleted.status
  status(dmDeleted,204)
  await expect(p.locator('tbody tr')).toHaveCount(1)
  assert.deepEqual(await fileStatuses(a,'/direct-messages/'+primary.body.id,dmOld.attachments[0].id),[404,404])
  report.checks.dm_previous_page_peer_delete_live_and_deleted_object_denied='PASS'
  phase='scope changes and close reopen refresh'
  await text(a,'QaFilesB'); p=await panel(a)
  await expect(p.getByText('В этой беседе пока нет файлов.',{exact:true})).toBeVisible()
  await text(a,'QaFilesA'); p=await panel(a)
  await expect(p.locator('tbody tr')).toHaveCount(1)
  await expect(p.locator('tbody tr')).toContainText('text-new.png')
  await dm(a,'qa_admin');p=await panel(a)
  await expect(p.getByText('В этой беседе пока нет файлов.',{exact:true})).toBeVisible()
  await dm(a,'qa_files_b');p=await panel(a)
  await expect(p.locator('tbody tr')).toHaveCount(1)
  await p.getByRole('button',{name:'Закрыть',exact:true}).click()
  p=await panel(a);await expect(p.locator('tbody tr')).toHaveCount(1)
  await a.reload();await dm(a,'qa_files_b');p=await panel(a)
  await p.getByRole('button',{name:'Показать более старые файлы',exact:true}).click()
  await expect(p.locator('tbody tr')).toHaveCount(1)
  await expect(p.locator('tbody tr')).toContainText('dm-new.png')
  await p.screenshot({path:input.directory+'/dm-files-after-delete-refresh.png'})
  report.checks.scope_changes_no_rows_or_tombstones_leak='PASS'
  report.checks.close_reopen_refresh_cursor_recovery='PASS'
  report.checks.dm_origin_navigation='PASS'
  report.status='PASS';report.browser=browser.version()
} catch (cause) {
  report.failure_type=cause?.name ?? 'unknown'
  report.status='FAIL';report.failed_phase=phase
  throw Error('Sanitized #254 acceptance failure at phase: '+phase)
} finally {
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')
  for(const context of contexts) await context.close()
  await browser.close()
}
