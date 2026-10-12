import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { createRequire } from 'node:module'
import { readFileSync, writeFileSync, existsSync, unlinkSync, renameSync } from 'node:fs'
import { chromium, expect, login, api, status, openNavigation, security, channel } from '../client_lifecycle/request.mjs'
import { installSyntheticCapture, installPeerObservation } from './publisher.mjs'
const require = createRequire(new URL('../../../clients/web/package.json', import.meta.url))
const { SignalRequest } = require('@livekit/protocol')
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
const report = { publisher_bridge_handler:{scenario_sha256:createHash('sha256').update(readFileSync(new URL(import.meta.url))).digest('hex'),protocol:'live-string-atomic-ui-v2'}, issue: 247, status: 'RUNNING', checks: {}, observations: [], source: { mode: 'synthetic canvas plus 440Hz tone', width: 640, height: 360, requested_fps: 30 }, actual_api: true, actual_sfu: true, transport_mocks: false, native: 'NOT_RUN' }
const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] }), contexts = []
let phase = 'setup', viewer, publisher
const signaling = { subscribe: 0, unsubscribe: 0, frames: 0 }
async function client(name, source = false) {
 const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 1000 } }); contexts.push(context)
 context.setDefaultTimeout(15000); await context.addInitScript(installPeerObservation)
 if (source) await context.addInitScript(installSyntheticCapture)
 const page = await context.newPage()
 if (!source && name !== 'qa_admin') await page.routeWebSocket(url => new URL(url).pathname.startsWith('/qa-sfu'), socket => {
   const server = socket.connectToServer()
   socket.onMessage(data => {
     try { const r = typeof data === 'string' ? SignalRequest.fromJsonString(data) : SignalRequest.fromBinary(data)
       const s = r.message?.case === 'subscription' ? r.message.value : r.subscription
       signaling.frames++; if (s) { const count = s.trackSids?.length || s.participantTracks?.reduce((n,p) => n+(p.trackSids?.length || 0), 0) || 0
         signaling[s.subscribe ? 'subscribe' : 'unsubscribe'] += count }
     } catch { /* transport frames still forwarded unmodified */ }
     server.send(data)
   }); server.onMessage(data => socket.send(data))
 })
 await login(page, name, input.password); return page
}
async function connected(page) { await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 30000 }); await expect.poll(() => page.evaluate(() => window.__qaPeers.some(p => p.connectionState === 'connected')), { timeout: 30000 }).toBe(true) }
async function select() { await channel(viewer, 'QaScreen'); await viewer.locator('[data-testid=stream-select]:visible').first().click(); await expect.poll(() => viewer.locator('video.screen-player').evaluate(v => v.videoWidth > 0 && v.getVideoPlaybackQuality().totalVideoFrames > 0), { timeout: 30000 }).toBe(true) }
async function snapshot(name, keepIdentity = false) {
 const value = await viewer.evaluate(({name,keepIdentity}) => {
   const v = document.querySelector('video.screen-player'), a = document.querySelector('.screen-viewer audio')
   const vt = v?.srcObject?.getVideoTracks() ?? [], at = a?.srcObject?.getAudioTracks() ?? []
   const now = { v, a, video: vt[0], audio: at[0] }, old = window.__qaSelected
   if (keepIdentity && old && (old.v !== v || old.a !== a || old.video !== vt[0] || old.audio !== at[0])) throw new Error('Selected media output or track changed')
   if (!keepIdentity) window.__qaSelected = now
   return { name, viewer_elements: document.querySelectorAll('.screen-viewer').length, video_outputs: vt.filter(t=>t.readyState==='live').length,
     audio_outputs: at.filter(t=>t.readyState==='live').length, decoded_frames: v?.getVideoPlaybackQuality().totalVideoFrames ?? 0,
     width: v?.videoWidth ?? 0, height: v?.videoHeight ?? 0, audio_muted: a?.muted ?? null,
     connected_peers: window.__qaPeers.filter(p=>p.connectionState==='connected').length,
     retained_video_receiver_objects: window.__qaPeers.flatMap(p=>p.getReceivers()).filter(r=>r.track.kind==='video'&&r.track.readyState==='live').length,
     document_overflow: document.documentElement.scrollWidth>innerWidth }
 }, {name,keepIdentity})
 value.subscription_requests = { ...signaling }; report.observations.push(value); writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n'); return value
}
async function capture(name) { await expect(viewer.locator('.voice-stream-alert-notice')).toBeHidden({timeout:10000}); await viewer.evaluate(()=>document.fonts.ready); await viewer.screenshot({path: input.directory+'/'+name+'.png'}) }
async function pinnedText() { await select(); await viewer.getByRole('button',{name:'Закрепить просмотр',exact:true}).click(); await channel(viewer,'QaText'); await expect(viewer.locator('.voice-room--mini')).toBeVisible() }
async function clean(name) { await expect.poll(()=>viewer.locator('video.screen-player').count()).toBe(0); const s=await snapshot(name); assert.equal(s.video_outputs,0); assert.equal(s.audio_outputs,0) }
async function nativePublisherHold() {
 const commandPath=input.directory+'/../publisher-command.json', ackPath=input.directory+'/../publisher-ack.json'
 while(!existsSync('/private/tmp/qa247-release')) {
  if(existsSync(commandPath)) {
   const command=JSON.parse(readFileSync(commandPath,'utf8')); unlinkSync(commandPath)
   try {
    assert.ok(['remove','publish'].includes(command.action))
    if(command.action==='remove') {
     const dock=publisher.getByTestId('voice-dock')
     await dock.getByRole('button',{name:'Остановить демонстрацию экрана',exact:true}).click()
     await expect(dock.getByRole('button',{name:'Остановить демонстрацию экрана',exact:true})).toBeHidden({timeout:30000})
     await expect(dock.getByRole('button',{name:'Начать демонстрацию экрана',exact:true})).toBeVisible({timeout:30000})
    }
    else { await publisher.getByTestId('voice-dock').getByRole('button',{name:'Начать демонстрацию экрана',exact:true}).click(); await publisher.getByRole('dialog',{name:'Демонстрация экрана',exact:true}).getByRole('button',{name:'Начать трансляцию',exact:true}).first().click(); await expect(publisher.getByTestId('voice-dock').getByRole('button',{name:'Остановить демонстрацию экрана',exact:true})).toBeVisible({timeout:30000}) }
    writeFileSync(ackPath+'.pending',JSON.stringify({request:command.request,status:'PASS',actual_publisher_ui:true})); renameSync(ackPath+'.pending',ackPath)
   } catch(error) {writeFileSync(ackPath+'.pending',JSON.stringify({request:command.request,status:'FAIL',error_type:error?.name})); renameSync(ackPath+'.pending',ackPath)}
  }
  await new Promise(r=>setTimeout(r,100))
 }
}
async function logout() { await security(viewer); await viewer.getByRole('button',{name:'Выйти из аккаунта',exact:true}).click(); await viewer.getByRole('dialog',{name:'Подтвердите выход из аккаунта'}).getByRole('button',{name:'Выйти',exact:true}).click(); await expect(viewer.locator('.authentication-page')).toBeVisible() }
try {
 report.browser = browser.version()
 const admin = await client('qa_admin')
 const a = await api(admin,'/auth/register','POST',{login:'qa_screen_source',password:input.password}); status(a,201)
 const b = await api(admin,'/auth/register','POST',{login:'qa_screen_viewer',password:input.password}); status(b,201)
 publisher = await client('qa_screen_source',true); viewer = await client('qa_screen_viewer')
 status(await api(publisher,'/me','PATCH',{display_name:'Источник проверки'}),200)
 status(await api(viewer,'/me','PATCH',{display_name:'Просмотр проверки'}),200)
 const category = await api(admin,'/admin/categories','POST',{name:'QaScreen'}); status(category,201)
 for (const [name,kind] of [['QaScreen','VOICE'],['QaText','TEXT']]) status(await api(admin,`/admin/categories/${category.body.id}/channels`,'POST',{name,kind}),201)
 status(await api(viewer,'/direct-messages','POST',{participant_id:a.body.id}),201)
 for (const p of [publisher,viewer]) { await p.reload(); await channel(p,'QaScreen'); await p.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click(); await connected(p) }
 phase = 'publish actual screen via production UI'
 await publisher.getByTestId('voice-dock').getByRole('button',{name:'Начать демонстрацию экрана',exact:true}).click()
 // The production setup dialog can ask to confirm profile before capture.
 const start = publisher.getByRole('dialog',{name:'Демонстрация экрана',exact:true}).getByRole('button',{name:'Начать трансляцию',exact:true})
 phase='confirm real screen setup'; await start.first().click()
 await expect(publisher.getByTestId('voice-dock').getByRole('button',{name:'Остановить демонстрацию экрана',exact:true})).toBeVisible({timeout:35000})
 phase='select actual remote screen'; await select(); const selected = await snapshot('selected'); assert.equal(selected.video_outputs,1); assert.equal(selected.audio_outputs,1)
 assert.equal(signaling.subscribe,2); await capture('full-viewer')
 const before = {...signaling}
 phase = 'pin TEXT DM settings retains one actual output and subscription'
 await viewer.getByRole('button',{name:'Закрепить просмотр',exact:true}).click(); await channel(viewer,'QaText')
 await expect(viewer.locator('.voice-room--mini')).toBeVisible(); await snapshot('pinned TEXT',true); await capture('pinned-text')
 await openNavigation(viewer); await viewer.getByRole('button',{name:'Личные',exact:true}).click(); await viewer.getByRole('navigation',{name:'Личные сообщения'}).getByRole('button',{name:/Источник проверки/}).click()
 await expect(viewer.locator('.direct-message-conversation')).toBeVisible(); await snapshot('pinned DM',true); await capture('pinned-dm')
 await security(viewer); await snapshot('pinned settings',true); await capture('pinned-settings')
 assert.equal(signaling.subscribe,before.subscribe); assert.equal(signaling.unsubscribe,before.unsubscribe)
 report.checks.pin_TEXT_DM_settings_one_output_no_resubscription = 'PASS'
 phase = 'return full then expanded mini return'
 await viewer.getByRole('button',{name:'К голосу',exact:true}).click(); await snapshot('return full',true)
 await viewer.getByLabel('Дополнительные действия',{exact:true}).click(); await viewer.getByRole('button',{name:'Развернуть на всю область',exact:true}).click()
 await expect(viewer.locator('.voice-room--screen-expanded')).toBeVisible(); await snapshot('expanded',true); await capture('expanded-viewer')
 const actions=viewer.locator('details.stream-more-actions'); if(await actions.getAttribute('open')===null)await actions.locator('summary').click(); await viewer.getByRole('button',{name:'Вернуть в окно канала',exact:true}).click(); await expect(viewer.locator('.voice-room--screen-expanded')).toHaveCount(0); await snapshot('expanded return',true); await channel(viewer,'QaText'); await expect(viewer.locator('.voice-room--mini')).toBeVisible(); await snapshot('full to mini',true)
 await viewer.getByRole('button',{name:'К голосу',exact:true}).click(); await snapshot('mini return full',true)
 assert.equal(signaling.subscribe,before.subscribe); assert.equal(signaling.unsubscribe,before.unsubscribe)
 report.checks.full_mini_full_return_preserves_stream = 'PASS'
 phase = 'adaptive viewport keyboard controls'
 await channel(viewer,'QaText')
 for (const width of [1024,768,393,320]) { await viewer.setViewportSize({width,height:900}); const s=await snapshot('viewport '+width,true); assert.equal(s.document_overflow,false)
   const mini=viewer.locator('.voice-room--mini'),box=await mini.boundingBox(); assert.ok(box&&box.x>=0&&box.x+box.width<=width+1)
   await mini.getByRole('button',{name:'К голосу',exact:true}).focus(); await expect(mini.getByRole('button',{name:'К голосу',exact:true})).toBeFocused(); await capture('mini-width-'+width)
 }
 report.checks.viewport_320_adaptive_keyboard_labels = 'PASS'
 await viewer.setViewportSize({width:1440,height:1000})
 phase = 'mute and stop exactly once'
 const mini=viewer.locator('.voice-room--mini'); await mini.getByRole('button',{name:'Выключить звук',exact:true}).click(); await expect(mini.getByRole('button',{name:'Включить звук',exact:true})).toHaveAttribute('aria-pressed','false')
 assert.equal((await snapshot('muted actual output',true)).audio_muted,true); await mini.getByRole('button',{name:'Включить звук',exact:true}).click(); assert.equal((await snapshot('unmuted actual output',true)).audio_muted,false); await expect(mini.getByRole('button',{name:'Выключить звук',exact:true})).toHaveAttribute('aria-pressed','true')
 const stopBefore={...signaling}; await mini.getByRole('button',{name:'Остановить просмотр',exact:true}).click(); await clean('explicit stop'); await viewer.waitForTimeout(300)
 assert.equal(signaling.unsubscribe-stopBefore.unsubscribe,2); assert.equal(signaling.subscribe,stopBefore.subscribe)
 report.checks.stop_two_publications_exactly_once_and_mute = 'PASS'
 phase='unpinned navigation stops default'; await select(); const unpinnedBefore={...signaling}; await channel(viewer,'QaText'); await clean('unpinned route stop'); await viewer.waitForTimeout(300); assert.equal(signaling.unsubscribe-unpinnedBefore.unsubscribe,2)
 report.checks.no_pin_default_route_stop = 'PASS'
 phase='source removal clears'; await pinnedText(); await publisher.getByTestId('voice-dock').getByRole('button',{name:'Остановить демонстрацию экрана',exact:true}).click(); await clean('publisher removal'); report.checks.source_removal_cleanup='PASS'
 phase='republish'; await publisher.getByTestId('voice-dock').getByRole('button',{name:'Начать демонстрацию экрана',exact:true}).click(); await start.first().click(); await expect(publisher.getByTestId('voice-dock').getByRole('button',{name:'Остановить демонстрацию экрана',exact:true})).toBeVisible({timeout:30000})
 phase='disconnect clears'; await pinnedText(); await viewer.getByTestId('voice-dock').getByRole('button',{name:'Выйти из голосового канала',exact:true}).click(); await clean('voice disconnect'); report.checks.disconnect_cleanup='PASS'
 phase='logout account switch clears'; await channel(viewer,'QaScreen'); await viewer.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click(); await connected(viewer); await pinnedText(); await logout(); await clean('logout'); await login(viewer,'qa_admin',input.password); await clean('other account login'); report.checks.logout_account_switch_cleanup='PASS'
 phase='actual account revoke clears'; await logout(); await login(viewer,'qa_screen_viewer',input.password); await channel(viewer,'QaScreen'); await viewer.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click(); await connected(viewer); await pinnedText(); status(await api(admin,`/admin/accounts/${b.body.id}`,'PATCH',{role:'MEMBER',blocked:true}),200); await expect(viewer.locator('.authentication-page')).toBeVisible({timeout:35000}); await clean('account revoke'); report.checks.revoke_cleanup='PASS'
 report.status='PASS'; phase='complete'
 writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')
 console.log('#247 Web scenarios complete; synthetic publisher available for native receiver')
 if(process.env.QA_HOLD_FOR_NATIVE==='1')await nativePublisherHold()
} catch(error) {
 report.status='FAIL'; report.failed_at=phase; report.error_type=error?.name || 'UnknownError'; if(typeof error?.actual==='number'&&typeof error?.expected==='number')report.assertion={actual:error.actual,expected:error.expected}; console.error('#247 failed_at='+phase+' error_type='+report.error_type+' detail='+String(error?.message).split('\n')[0].replace(/https?:\/\/\S+/g,'[URL]').replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi,'[ID]'))
 if(viewer)await capture('failure').catch(()=>{}); if(publisher)await publisher.screenshot({path:input.directory+'/publisher-failure.png'}).catch(()=>{})
 // Never persist assertion snippets: they can contain account/stream IDs.
 process.exitCode=1; writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n'); if(process.env.QA_HOLD_FOR_NATIVE==='1'&&publisher&&await publisher.getByTestId('voice-dock').getByRole('button',{name:'Остановить демонстрацию экрана',exact:true}).isVisible().catch(()=>false)) { console.log('#247 Web failure retained actual publisher for native receiver'); await nativePublisherHold() }
} finally {
 report.subscription_requests={...signaling}; writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')
 await Promise.allSettled(contexts.map(c=>c.close())); await browser.close()
}
