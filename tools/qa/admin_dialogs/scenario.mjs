import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {execFileSync} from 'node:child_process'
import {chromium,expect,login,api,status,channel,openNavigation,guildPanel} from '../client_lifecycle/request.mjs'
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const report={issues:[295,298],width:input.width,status:'RUNNING',mocks:false,physical_touch:false,checks:{},controlled_faults:['held actual HTTP201 create response','owned API container stop/start']}
const browser=await chromium.launch(),contexts=[]
let page;
let phase='setup',apiStopped=false,creates=0,admissions=0
const owner=process.env.QA_DB_OWNER
assert.ok(/^qa295298-[a-f0-9]{16}$/.test(owner))
function ownedAPI(action){
 const label=execFileSync('docker',['inspect',owner+'-api','--format','{{index .Config.Labels "boohtacord.qa.owner"}}'],{encoding:'utf8'}).trim()
 assert.equal(label,owner)
 execFileSync('docker',[action,owner+'-api'],{stdio:'ignore',timeout:30000});apiStopped=action==='stop'
}
async function client(name){const c=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:input.width,height:900},isMobile:input.width<600,hasTouch:input.width<600});contexts.push(c);const p=await c.newPage();p.setDefaultTimeout(15000);await login(p,name,input.password);return p}
async function capture(page,name){await page.bringToFront();await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))});await page.screenshot({path:input.directory+'/'+name+'.png',animations:'disabled'})}
async function categoryFooter(dialog,phase){
 const metrics=await dialog.locator('.topology-dialog-actions button').evaluateAll(items=>items.map(element=>{const r=element.getBoundingClientRect(),d=element.closest('[role=dialog]').getBoundingClientRect();return {bottom:r.bottom,viewport:innerHeight,dialog_bottom:d.bottom,hit:element.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))}}));
 for(const m of metrics){assert.ok(m.bottom<=m.viewport+1);assert.ok(m.bottom<=m.dialog_bottom+1);assert.equal(m.hit,true)}
 (report.category_footer_checks??=[]).push({phase,metrics})
}
async function confirmationFooter(dialog,phase){
 const message=await dialog.locator('p').evaluate(e=>({scroll_width:e.scrollWidth,client_width:e.clientWidth}));
 (report.confirmation_target_checks??=[]).push({phase,...message});assert.ok(message.scroll_width<=message.client_width);
 const metrics=await dialog.locator('.admin-confirm-actions button').evaluateAll(items=>items.map(element=>{const r=element.getBoundingClientRect(),d=element.closest('dialog').getBoundingClientRect(),range=document.createRange();range.selectNodeContents(element);const t=range.getBoundingClientRect();return{left:r.left,right:r.right,bottom:r.bottom,dialog_left:d.left,dialog_right:d.right,dialog_bottom:d.bottom,viewport_width:innerWidth,viewport_height:innerHeight,text_right:t.right,hit:element.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))}}));
 (report.confirmation_footer_checks??=[]).push({phase,metrics})
 if(input.width===320) await capture(page,'confirmation-geometry-'+phase)
 for(const m of metrics){assert.ok(m.left>=m.dialog_left-1);assert.ok(m.right<=m.dialog_right+1);assert.ok(m.right<=m.viewport_width+1);assert.ok(m.bottom<=m.dialog_bottom+1);assert.ok(m.bottom<=m.viewport_height+1);assert.ok(m.text_right<=m.right+1);assert.equal(m.hit,true)}
}
async function retained(page){await expect(page.locator('.voice-status')).toHaveText('Голос подключён');assert.equal(admissions,admissionBaseline)}
let admissionBaseline=0
try{
 page=await client('qa_admin')
 status(await api(page,'/auth/register','POST',{login:'qa_dialog_peer',password:input.password}),201)
 const category=await api(page,'/admin/categories','POST',{name:'QaAdminDialogs'});status(category,201)
 for(const [name,kind] of [['QaText','TEXT'],['QaVoice','VOICE'],['QaInactiveVoice','VOICE']])status(await api(page,'/admin/categories/'+category.body.id+'/channels','POST',{name,kind}),201)
 const peer=await client('qa_dialog_peer')
 page.on('request',r=>{const path=new URL(r.url()).pathname;if(r.method()!=='GET'&&/\/voice\/(channels\/[^/]+\/leases|leases\/[^/]+(?:\/credential)?)$/.test(path))admissions++;if(r.method()==='POST'&&path.endsWith('/categories'))creates++})
 phase='real two participant SFU listener room'
 await channel(peer,'QaVoice');await peer.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click();await expect(peer.locator('.voice-status')).toHaveText('Голос подключён')
 await channel(page,'QaVoice');await page.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click();await expect(page.locator('.voice-status')).toHaveText('Голос подключён');admissionBaseline=admissions
 await channel(page,'QaText');await page.locator('#message-body').fill('QA_LOCAL_UNSENT')
 report.checks['295_real_SFU_two_listener_connection']='PASS'
 phase='admin seven sections and layout'
 await guildPanel(page)
 const nav=page.getByRole('navigation',{name:'Разделы администрирования'})
 await expect(nav.getByRole('button')).toHaveCount(7)
 for(const [key,label,heading] of [['guild','Гильдия','Настройки гильдии'],['members','Участники','Участники'],['roles','Роли','Роли и разрешения'],['channels','Каналы','Управление каналами'],['audit','Аудит','Журнал действий'],['media','Медиа','Медиа'],['readiness','Готовность','Готовность']]){
  phase='admin section '+key
  const tab=nav.getByRole('button',{name:label,exact:true});await tab.scrollIntoViewIfNeeded();await tab.click();await expect(tab).toHaveAttribute('aria-current','page')
  await page.waitForTimeout(400);await retained(page)
  await expect(page.getByTestId('admin-panel')).toBeVisible()
  const bounds=await page.getByTestId('admin-panel').boundingBox();assert.ok(bounds.x>=-.5&&bounds.x+bounds.width<=input.width+.5)
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true)
  if(key==='members')report.member_filter_readability=await page.locator('.admin-member-filters select').evaluateAll(items=>items.map(select=>{const css=getComputedStyle(select),canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');ctx.font=`${css.fontStyle} ${css.fontWeight} ${css.fontSize} ${css.fontFamily}`;return {selected_label:select.selectedOptions[0]?.textContent,client_width:select.clientWidth,padding_left:parseFloat(css.paddingLeft),padding_right:parseFloat(css.paddingRight),text_width:ctx.measureText(select.selectedOptions[0]?.textContent??'').width,computed_font:ctx.font}}));
  await capture(page,'admin-'+key)
  report.checks['295_actual_'+key+'_layout_context_voice']='PASS'
 }
 await page.getByRole('button',{name:'Закрыть администрирование',exact:true}).click()
 await expect(page.locator('#message-body')).toHaveValue('QA_LOCAL_UNSENT');await retained(page)
 await openNavigation(page);await page.locator('.guild-header').click();await expect(nav.getByRole('button',{name:'Готовность',exact:true})).toHaveAttribute('aria-current','page');await page.getByRole('button',{name:'Закрыть администрирование',exact:true}).click();report.checks['295_admin_reopen_remembers_previous_section']='PASS'
 report.checks['295_admin_return_selected_text_draft_voice']='PASS'
 phase='real MEMBER server admin ACL'
 for(const path of ['/admin/roles','/admin/accounts'])status(await api(peer,path),403)
 await openNavigation(peer);await expect(peer.locator('.guild-header')).toBeVisible()
 await peer.locator('.guild-header').click();await expect(peer.getByTestId('admin-panel')).toHaveCount(0)
 report.checks['295_MEMBER_admin_API403_no_panel_entry']='PASS'
 phase='create dialog initial focus validation Escape restore'
 await openNavigation(page)
 const trigger=page.getByRole('button',{name:'Создать раздел или канал',exact:true})
 await trigger.click()
 const dialog=page.getByRole('dialog',{name:'Создать раздел',exact:true}),name=dialog.getByLabel('Название раздела')
 await expect(name).toBeFocused();await name.fill(' ');await dialog.getByRole('button',{name:'Создать раздел',exact:true}).click()
 await expect(dialog.getByRole('alert')).toHaveText('Введите имя до 80 символов.');await categoryFooter(dialog,'create-invalid');await capture(page,'create-invalid')
 await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);await expect(trigger).toBeFocused();assert.equal(creates,0)
 report.checks['298_create_invalid_Escape_focusrestore_no_mutation']='PASS'
 phase='create pending single real HTTP201 submission';await page.bringToFront()
 await trigger.click();await name.fill('QaWebCreated');const drawerBeforePending=await page.locator('.sidebar').evaluate(e=>e.classList.contains('is-open'))
 let release;const hold=new Promise(r=>release=r),actualResponse=[]
 await page.route('**/api/v1/categories',async route=>{const response=await route.fetch();actualResponse.push(response.status());await hold;await route.fulfill({response})})
 await dialog.getByRole('button',{name:'Создать раздел',exact:true}).click()
 await expect(dialog.getByRole('button',{name:'Создаём…',exact:true})).toBeDisabled();await expect(dialog.getByRole('button',{name:'Отмена',exact:true})).toBeDisabled()
 await page.keyboard.press('Enter');await page.keyboard.press('Escape');await expect(dialog).toBeVisible();await categoryFooter(dialog,'create-pending');await capture(page,'create-pending')
 report.pending_focus_inside_dialog=await dialog.evaluate(d=>d.contains(document.activeElement));assert.equal(report.pending_focus_inside_dialog,true);assert.equal(await page.locator('.sidebar').evaluate(e=>e.classList.contains('is-open')),drawerBeforePending);assert.equal(creates,1);release();await expect(dialog).toHaveCount(0);assert.deepEqual(actualResponse,[201]);await page.unroute('**/api/v1/categories')
 await openNavigation(page);await expect(page.getByRole('button',{name:'Действия с разделом QaWebCreated',exact:true})).toBeVisible()
 report.checks['298_pending_blocks_double_submit_close_real_success']='PASS'
 phase='destructive category target Cancel-first trap focusrestore'
 const remove=page.getByRole('button',{name:'Действия с разделом QaWebCreated',exact:true});await remove.click()
 const confirm=page.getByRole('dialog',{name:'Подтвердите действие',exact:true})
 await expect(confirm.getByRole('button',{name:'Отмена',exact:true})).toBeFocused()
 await expect(confirm).toContainText('QaWebCreated');await expect(confirm).toContainText('Пустой раздел будет удалён')
 for(let i=0;i<8;i++){await page.keyboard.press('Tab');assert.equal(await confirm.evaluate(d=>d.contains(document.activeElement)),true)}
 await confirmationFooter(confirm,'delete-category');await capture(page,'danger-confirmation');await page.keyboard.press('Escape');await expect(confirm).toBeHidden();await expect(remove).toBeFocused()
 report.checks['298_destructive_exacttarget_Cancel_focus_trap_Escape_restore']='PASS'
 phase='destructive actual server delete'
 await remove.click();const deletion=page.waitForResponse(r=>r.request().method()==='DELETE'&&new URL(r.url()).pathname.includes('/categories/'))
 await confirm.getByRole('button',{name:'Удалить',exact:true}).click();assert.ok([200,204].includes((await deletion).status()));await expect(remove).toHaveCount(0)
 report.checks['298_destructive_real_API_delete_success']='PASS'
 phase='create real service interruption retains field and retry'
 await page.waitForTimeout(2500);await openNavigation(page);await trigger.click();await name.fill('QaErrorRetry');await expect(dialog).toBeVisible();await page.waitForTimeout(1500);await expect(dialog).toBeVisible();report.error_retry_pre_stop={dialog_present:await dialog.count(),focus_inside:await dialog.evaluate(d=>d.contains(document.activeElement))};ownedAPI('stop');report.error_retry_post_stop={dialog_present:await dialog.count(),topology_loading_visible:await page.getByText('Загружаем каналы…',{exact:true}).isVisible().catch(()=>false)}
 await dialog.getByRole('button',{name:'Создать раздел',exact:true}).click();await expect(dialog.getByRole('alert')).toBeVisible({timeout:20000});await expect(name).toHaveValue('QaErrorRetry');await categoryFooter(dialog,'create-network-error');await capture(page,'create-network-error')
 ownedAPI('start');await page.waitForTimeout(1500)
 await dialog.getByRole('button',{name:'Создать раздел',exact:true}).click();await expect(dialog).toHaveCount(0)
 report.checks['298_real_API_unavailable_error_fields_retry_success']='PASS'
 phase='create channel actual API'
 await page.getByRole('button',{name:'Создать канал в разделе QaErrorRetry',exact:true}).click()
 const channelDialog=page.getByRole('dialog',{name:'Создать канал',exact:true});await channelDialog.getByLabel('Название канала').fill('QaCreatedText')
 await channelDialog.getByRole('button',{name:'Создать канал',exact:true}).click();await expect(channelDialog).toHaveCount(0)
 await capture(page,'created-channel-success');report.checks['298_channel_create_real_API']='PASS'
 phase='role grants destructive system confirmation Cancel and actual save'
 await guildPanel(page);await nav.getByRole('button',{name:'Роли',exact:true}).click()
 const roles=page.locator('.role-permissions'),check=roles.getByLabel('Удалять текстовые каналы'),save=roles.getByRole('button',{name:'Сохранить',exact:true})
 await check.check();page.once('dialog',d=>d.dismiss());await save.click();await expect(check).toBeChecked()
 page.once('dialog',d=>d.accept());await save.click();await expect(roles.getByRole('status').filter({hasText:'Разрешения участников сохранены.'})).toBeVisible();const savedStatus=roles.getByRole('status').filter({hasText:'Разрешения участников сохранены.'});await savedStatus.evaluate(el=>el.scrollIntoView({block:'center'}));report.role_save_feedback_pointer_visible=await savedStatus.evaluate(el=>{const r=el.getBoundingClientRect();return el.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))});assert.equal(report.role_save_feedback_pointer_visible,true);await capture(page,'role-save-success')
 report.checks['298_role_delete_grant_systemconfirm_Cancel_then_real_save']='PASS'
 phase='role real revision conflict retains draft'
 await check.uncheck();const policy=await api(page,'/admin/roles');status(policy,200)
 const member=policy.body.roles.find(r=>r.role==='MEMBER');const changed={...member.permissions,'category.create':!member.permissions['category.create']}
 status(await api(page,'/admin/roles/MEMBER/permissions','PUT',{expected_revision:policy.body.revision,permissions:changed,confirm_delete_grants:false}),200)
 await save.click();await expect(roles.getByRole('alert')).toContainText('Настройки уже изменены');await expect(check).not.toBeChecked();await roles.getByRole('alert').scrollIntoViewIfNeeded();await capture(page,'role-revision-conflict')
 report.checks['298_real_revision409_preserves_role_draft']='PASS'
 phase='archive and close exact target confirmations'
 await page.getByRole('button',{name:'Закрыть администрирование',exact:true}).click();await openNavigation(page)
 for(const [target,label,method,path] of [['QaCreatedText','Архивировать','DELETE','/channels/'],['QaInactiveVoice','Закрыть','POST','/close-admission']]){
  const action=page.getByRole('button',{name:'Действия с каналом '+target,exact:true});await expect(action).toBeVisible();await action.click()
  await expect(confirm).toContainText(target);await expect(confirm.getByRole('button',{name:'Отмена',exact:true})).toBeFocused()
  await confirmationFooter(confirm,target==='QaCreatedText'?'archive':'close');
  if(input.width===320){await page.evaluate(()=>document.documentElement.style.fontSize='32px');await confirmationFooter(confirm,target==='QaCreatedText'?'archive-text2':'close-text2');await capture(page,target==='QaCreatedText'?'archive-confirmation-text2':'close-voice-confirmation-text2');await page.evaluate(()=>document.documentElement.style.fontSize='')}
  await capture(page,target==='QaCreatedText'?'archive-confirmation':'close-voice-confirmation')
  await confirm.getByRole('button',{name:'Отмена',exact:true}).click();await expect(confirm).toBeHidden();await expect(action).toBeFocused()
  await action.click();const response=page.waitForResponse(r=>r.request().method()===method&&new URL(r.url()).pathname.includes(path))
  await confirm.getByRole('button',{name:label,exact:true}).click();assert.equal((await response).status(),target==='QaInactiveVoice'?202:200);await expect(confirm).toBeHidden();await retained(page)
  report.checks['298_'+(target==='QaCreatedText'?'archive_text':'close_inactive_voice')+'_exacttarget_Cancel_and_real_accepted_command']='PASS'
 }
 phase='real topology revision invalidates destructive confirmation'
 const stale=await api(page,'/admin/categories','POST',{name:'QaStaleEmpty'});status(stale,201)
 const staleAction=page.getByRole('button',{name:'Действия с разделом QaStaleEmpty',exact:true});await expect(staleAction).toBeVisible();await page.waitForTimeout(700);await staleAction.click();await expect(confirm).toBeVisible()
 let staleDeletes=0;page.on('request',r=>{if(r.method()==='DELETE')staleDeletes++})
 status(await api(page,'/admin/categories','POST',{name:'QaRevisionAdvance'}),201)
 await expect(confirm).toBeHidden();await expect(page.getByRole('alert').filter({hasText:'Структура изменилась'})).toBeVisible();assert.equal(staleDeletes,0);await retained(page);await capture(page,'stale-confirmation-cancelled')
 report.checks['298_real_topology_revision_cancels_stale_confirmation_without_delete']='PASS'
 report.status='PASS';report.browser=browser.version()
}catch(error){report.status='FAIL';report.failed_phase=phase;report.failure_type=error?.name;report.failed_line=/scenario.mjs:(\d+)/.exec(error?.stack??'')?.[1];if(page)await capture(page,'failed-phase').catch(()=>{});throw Error('Sanitized admin/dialogs scenario failure: '+phase)}
finally{if(apiStopped)ownedAPI('start');writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n');for(const c of contexts)await c.close();await browser.close()}
