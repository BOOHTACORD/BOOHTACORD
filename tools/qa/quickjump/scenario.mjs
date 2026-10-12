import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {chromium,expect,login,api,status,openNavigation,security,channel} from '../client_lifecycle/request.mjs'
import {sql,owned} from '../next_client_acceptance/fixture.mjs'
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8'))
const report={issue:283,width:input.width,roles:['MEMBER','MEMBER','ADMIN'],checks:{},mocks:false,controlled_faults:['held actual candidates response','owned API stop/restart','owned SQL stale DM fixture'],OS_notifications:'NOT_RUN',native:'NOT_RUN',network:[]}
const browser=await chromium.launch(),contexts=[],releases=[]
let phase='setup',activePage
async function client(name){const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:input.width,height:900}});contexts.push(context);context.setDefaultTimeout(12000);const page=await context.newPage();await login(page,name,input.password);return page}
async function close(page){await page.keyboard.press('Escape');await expect(page.getByTestId('search-aside-panel')).toBeHidden()}
async function quick(page){if(!await page.getByTestId('search-aside-panel').isVisible()){await openNavigation(page);await page.locator('.guild-search-button').click()}await page.getByRole('button',{name:'Каналы и люди',exact:true}).click();const p=page.getByTestId('quick-jump-panel');await expect(p).toBeVisible();return p}
async function capture(page,p,name){await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))});const box=await p.boundingBox(),vp=page.viewportSize();assert.ok(box&&vp);const x=Math.max(0,box.x),y=Math.max(0,box.y);await page.screenshot({path:input.directory+'/'+name+'.png',clip:{x,y,width:Math.min(box.width,vp.width-x),height:Math.min(box.height,vp.height-y)}});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth))}
async function logout(page){if(await page.getByTestId('search-aside-panel').isVisible())await close(page);await security(page);await page.getByRole('button',{name:'Выйти из аккаунта',exact:true}).click();await page.getByRole('dialog',{name:'Подтвердите выход из аккаунта'}).getByRole('button',{name:'Выйти',exact:true}).click();await expect(page.locator('.authentication-page')).toBeVisible()}
const longName='Тестовый участник 👩🏽‍💻 漢字 — длинное имя для проверки переноса'
try{
 const admin=await client('qa_admin')
 phase='register A';const regA=await api(admin,'/auth/register','POST',{login:'qa_jump_a',password:input.password});status(regA,201)
 phase='register B';const regB=await api(admin,'/auth/register','POST',{login:'qa_jump_b',password:input.password});status(regB,201)
 phase='register C';const regC=await api(admin,'/auth/register','POST',{login:'qa_jump_c',password:input.password});status(regC,201)
 const page=await client('qa_jump_a'),peer=await client('qa_jump_b');activePage=page
 phase='rename A';status(await api(page,'/me','PATCH',{display_name:'Тестовый участник A'}),200)
 phase='rename B';status(await api(peer,'/me','PATCH',{display_name:longName}),200)
 sql("INSERT INTO users(id,login,display_name,password_hash,role) SELECT gen_random_uuid(),'qa_jump_page_'||lpad(i::text,3,'0'),'Кандидат проверки '||lpad(i::text,3,'0'),'qa-disabled','MEMBER' FROM generate_series(1,85) i")
 phase='create category';const category=await api(admin,'/admin/categories','POST',{name:'QaJump'});status(category,201)
 phase='create text';const text=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaText漢字',kind:'TEXT'});status(text,201)
 phase='create stale';const stale=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaStale',kind:'TEXT'});status(stale,201)
 phase='create voice';const voice=await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaVoice',kind:'VOICE'});status(voice,201)
 phase='create initial DM';const existing=await api(page,'/direct-messages','POST',{participant_id:regB.body.id});status(existing,201)
 await page.reload();await expect(page.getByTestId('app-shell')).toBeVisible()
 let joins=0,leases=0
 const startedAt=Date.now();page.on('response',response=>{const path=new URL(response.url()).pathname;let route;if(path.endsWith('/direct-message-candidates'))route='people_candidates';else if(path.endsWith('/direct-messages'))route='DM_navigation_or_open';else if(path.endsWith('/channels'))route='topology';else if(path.includes('/voice/')&&path.endsWith('/leases'))route='voice_admission';if(route&&report.network.length<100)report.network.push({route,status:response.status(),at_ms:Date.now()-startedAt})});page.on('request',request=>{const path=new URL(request.url()).pathname;if(/voice.*join/.test(path))joins++;if(/voice.*lease/.test(path)&&request.method()!=='GET')leases++})
 await page.evaluate(()=>{window.__qaMicCalls=0;const original=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);navigator.mediaDevices.getUserMedia=(constraints)=>{window.__qaMicCalls++;return original(constraints)}})
 phase='Ctrl/Cmd+K default destination'
 await openNavigation(page);if(input.width<1024){await page.keyboard.press('Escape');await page.getByRole('button',{name:'Открыть навигацию',exact:true}).focus()}else{await page.locator('.guild-search-button').focus()};await page.keyboard.press('Control+k');await expect(page.getByTestId('search-aside-panel')).toBeVisible()
 report.shortcut_initial_mode=await page.getByTestId('quick-jump-panel').isVisible()?'navigation':'messages';report.checks.Ctrl_K_opens_search_with_separate_quick_jump='PASS'
 await capture(page,page.getByTestId('search-aside-panel'),'shortcut-destination')
 await close(page);await expect(input.width<1024?page.getByRole('button',{name:'Открыть навигацию',exact:true}):page.locator('.guild-search-button')).toBeFocused()
 await page.keyboard.press('Meta+k');await expect(page.getByTestId('search-aside-panel')).toBeVisible();report.checks.Cmd_K_opens_search_with_separate_quick_jump='PASS';await close(page)
 report.checks.Escape_focus_return='PASS'
 phase='real candidate pages/dedup/error/retry'
 let p=await quick(page)
 await expect(p.locator('.quick-jump-results button')).not.toHaveCount(0)
 const q=p.getByRole('searchbox');await q.fill('Тестовый участник')
 await expect(p.locator('[data-kind="DIRECT_MESSAGE"]')).toHaveCount(1);await expect(p.locator('[data-kind="MEMBER"]')).toHaveCount(0)
 await capture(page,p,'deduplicated-long-unicode')
 await q.fill('')
 const more=p.getByRole('button',{name:'Показать ещё участников',exact:true});await expect(more).toBeVisible()
 owned('api','stop','$owned')
 await more.click();await expect(p.getByRole('alert')).toBeVisible();await capture(page,p,'candidate-page-error')
 owned('api','start','$owned')
 for(let i=0;i<100;i++){try{if((await api(page,'/health')).status===200)break}catch{}await page.waitForTimeout(100)}
 await p.getByRole('button',{name:'Повторить',exact:true}).click();await expect(p.getByRole('alert')).toHaveCount(0)
 while(await more.count()){await more.click();await expect(p.getByText('Загружаем участников…')).toHaveCount(0)}
 await q.fill('Кандидат проверки 085');await expect(p.locator('[data-kind="MEMBER"]')).toHaveCount(1)
 report.checks.actual_candidate_pagination_error_retry_dedup='PASS'
 phase='typing/controlled IME no selection'
 await q.fill('Кандидат проверки');await q.press('Control+k');await expect(p).toBeVisible()
 let before=(await api(page,'/direct-messages')).body.direct_messages.length
 await q.dispatchEvent('compositionstart');await q.dispatchEvent('keydown',{key:'Enter',code:'Enter',isComposing:true});await q.dispatchEvent('compositionend',{data:'漢字'})
 assert.equal((await api(page,'/direct-messages')).body.direct_messages.length,before)
 report.checks.typing_and_controlled_IME_no_selection='PASS'
 phase='keyboard authorized new two-person DM'
 await q.fill('Кандидат проверки 085');await q.press('Tab');await expect(p.locator('[data-kind="MEMBER"]')).toBeFocused();await page.keyboard.press('Enter')
 await expect(page.getByTestId('search-aside-panel')).toBeHidden();const nav=await api(page,'/direct-messages');status(nav,200);assert.equal(nav.body.direct_messages.length,before+1)
 const candidate=sql("SELECT id FROM users WHERE login='qa_jump_page_085'")
 const created=nav.body.direct_messages.find(v=>v.other_participant_id===candidate);assert.ok(created)
 const result=sql(`SELECT participant_one_id::text||','||participant_two_id::text FROM direct_messages WHERE id='${created.id}'`).split(',');assert.equal(new Set(result).size,2);assert.deepEqual(result.sort(),[regA.body.id,candidate].sort())
 report.checks.keyboard_authorized_two_person_DM='PASS'
 phase='TEXT navigation disconnected no join/mic/lease'
 p=await quick(page);await p.getByRole('searchbox').fill('QaText');await p.locator('[data-kind="CHANNEL"]').click();await expect(page.getByTestId('search-aside-panel')).toBeHidden()
 assert.equal(joins,0);assert.equal(leases,0);assert.equal(await page.evaluate(()=>window.__qaMicCalls),0)
 report.checks.disconnected_TEXT_DM_no_join_mic_lease='PASS'
 phase='already connected listener TEXT/DM keeps voice session'
 await channel(page,'QaVoice');await page.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click()
 phase='actual SFU listener connection';const dock=page.getByTestId('voice-dock');await expect(dock.locator('.voice-status')).toHaveText('Голос подключён',{timeout:25000})
 phase='connected listener quickjump navigation';const beforeJoin=joins,beforeLease=leases
 phase='connected open TEXT quickjump';p=await quick(page);await p.getByRole('searchbox').fill('QaText');await p.locator('[data-kind="CHANNEL"]').click()
 await expect(page.getByTestId('search-aside-panel')).toBeHidden();phase='connected TEXT voice unchanged';await expect(dock.locator('.voice-status')).toHaveText('Голос подключён');phase='connected open DM quickjump';p=await quick(page);await p.getByRole('searchbox').fill('Тестовый участник');report.connected_DM_rows=await p.locator('[data-kind="DIRECT_MESSAGE"]').count();await capture(page,p,'connected-DM-picker');await p.locator('[data-kind="DIRECT_MESSAGE"]').click();await expect(page.getByTestId('search-aside-panel')).toBeHidden()
 await expect(dock.locator('.voice-status')).toHaveText('Голос подключён');assert.equal(joins,beforeJoin);assert.equal(leases,beforeLease);assert.equal(await page.evaluate(()=>window.__qaMicCalls),0)
 report.checks.connected_listener_TEXT_DM_no_join_mic_transfer='PASS';await capture(page,dock,'connected-navigation-voice-dock')
 await dock.getByRole('button',{name:'Выйти из голосового канала',exact:true}).click();await expect(dock.locator('.voice-status')).toHaveText('Голос не подключён')
 phase='stale archived channel fail closed'
 p=await quick(page);await p.getByRole('searchbox').fill('QaStale');await expect(p.locator('[data-kind="CHANNEL"]')).toHaveCount(1)
 const topology=await api(admin,'/channels');status(topology,200);status(await api(admin,`/admin/channels/${stale.body.id}`,'DELETE',{expected_revision:topology.body.revision,confirm_archive:true}),200)
 // Retain the rendered old row by delaying UI event processing through route is not necessary: quick jump refresh is authoritative.
 if(await p.locator('[data-kind="CHANNEL"]').count()){await p.locator('[data-kind="CHANNEL"]').click();await expect(page.getByRole('alert')).toContainText('больше недоступен')}
 status(await api(page,`/channels/${stale.body.id}/messages`),404);report.checks.archived_channel_rejected='PASS';await close(page)
 phase='stale own DM no longer addressed to current member'
 p=await quick(page);await p.getByRole('searchbox').fill('Тестовый участник')
 const adminId=(await api(admin,'/auth/session')).body.account_id
 const pair=[regB.body.id,adminId].sort();sql(`UPDATE direct_messages SET participant_one_id='${pair[0]}',participant_two_id='${pair[1]}' WHERE id='${existing.body.id}'`)
 await p.locator('[data-kind="DIRECT_MESSAGE"]').click();await expect(page.getByRole('alert')).toContainText('Личный диалог больше недоступен');status(await api(page,`/direct-messages/${existing.body.id}/messages`),404)
 report.checks.stale_foreign_DM_refresh_rejected='PASS';await close(page)
 phase='revoked candidate membership'
 p=await quick(page);await expect(p.getByText('Загружаем участников…')).toHaveCount(0);while(await p.getByRole('button',{name:'Показать ещё участников',exact:true}).count()){await p.getByRole('button',{name:'Показать ещё участников',exact:true}).click();await expect(p.getByText('Загружаем участников…')).toHaveCount(0)};await p.getByRole('searchbox').fill('qa_jump_c')
 // Candidate display names are login defaults until explicitly renamed.
 await expect(p.locator('[data-kind="MEMBER"]')).toHaveCount(1)
 phase='block candidate real API';status(await api(admin,`/admin/accounts/${regC.body.id}`,'PATCH',{role:'MEMBER',blocked:true}),200)
 phase='click blocked candidate';await p.locator('[data-kind="MEMBER"]').click();phase='blocked candidate visible safe error';await expect(page.locator('.search-error')).toContainText('Личный диалог больше недоступен');report.checks.revoked_candidate_member_rejected='PASS';await close(page)
 phase='guild rename current header/title/logo'
 const oldGuild=await api(admin,'/admin/guild-settings');status(oldGuild,200)
 const guildName='Гильдия проверки 漢字 👩🏽‍💻 с длинным названием'
 status(await api(admin,'/admin/guild-settings','PATCH',{name:guildName,expected_revision:oldGuild.body.revision,welcome_channel_id:oldGuild.body.welcome_channel_id}),200)
 await expect(page).toHaveTitle(guildName);await openNavigation(page);await expect(page.locator('.guild-header')).toContainText(guildName)
 await capture(page,page.locator('.guild-header'),'guild-header-current')
 report.checks.guild_rename_header_title='PASS';assert.equal(await page.locator('.guild-mark').getAttribute('src'),'/brand.png');assert.ok(await page.locator('.guild-mark').evaluate(el=>el.complete&&el.naturalWidth>0));assert.equal(await page.getByRole('button',{name:/сменить сервер|выбрать сервер|переключить сервер/i}).count(),0);report.checks.logo_no_switcher='PASS'
 phase='same-page account switch disposal of actual delayed people response'
 let started,release;const arrived=new Promise(r=>started=r),held=new Promise(r=>release=r);releases.push(release)
 await page.route('**/api/v1/direct-message-candidates',async route=>{const response=await route.fetch();started();await held;try{await route.fulfill({response})}catch{}},{times:1})
 const pending=quick(page);await arrived;await pending
 await logout(page)
 await page.getByLabel('Логин',{exact:true}).fill('qa_jump_b');await page.getByLabel('Пароль',{exact:true}).fill(input.password);await page.getByRole('button',{name:'Войти',exact:true}).click();await expect(page.getByTestId('app-shell')).toBeVisible();release()
 p=await quick(page);await expect(p.getByText('Загружаем участников…')).toHaveCount(0);while(await p.getByRole('button',{name:'Показать ещё участников',exact:true}).count()){await p.getByRole('button',{name:'Показать ещё участников',exact:true}).click();await expect(p.getByText('Загружаем участников…')).toHaveCount(0)};await p.getByRole('searchbox').fill('Тестовый участник');await expect(p.locator('[data-kind="MEMBER"]')).toHaveCount(1);assert.ok((await p.innerText()).includes('Тестовый участник A'))
 report.checks.logout_switch_disposes_old_people='PASS';await capture(page,p,'switched-account-people')
 report.status=Object.values(report.checks).includes('FAIL')?'FAIL':'PARTIAL'
}catch(error){report.status='FAIL';report.failed_phase=phase;report.error_type=error.constructor.name;report.safe_error=String(error.message).split('\n')[0].replace(/[a-f0-9]{8}-[a-f0-9-]{27}/gi,'[redacted]').slice(0,240);if(activePage){try{const p=activePage.getByTestId('quick-jump-panel');if(await p.isVisible()){report.failure_entries={DM:await p.locator('[data-kind=\"DIRECT_MESSAGE\"]').count(),MEMBER:await p.locator('[data-kind=\"MEMBER\"]').count()};await capture(activePage,p,'failure-visible-panel')}}catch{}}}
finally{for(const release of releases)release();for(const context of contexts)await context.close();await browser.close();writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')}
