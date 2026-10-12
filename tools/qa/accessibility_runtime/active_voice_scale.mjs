import assert from 'node:assert/strict'
import {readFileSync,writeFileSync} from 'node:fs'
import {chromium,expect,login,api,status,openNavigation,channel as rawChannel} from '../client_lifecycle/request.mjs'
const input=JSON.parse(readFileSync(process.env.QA_INPUT,'utf8')),report={issue:301,actual_api:true,actual_sfu:false,mocks:false,css_method:process.env.QA_EXTRA_CSS?'source CSS diagnostic on pinned binary':'pinned production dist',rows:[]}
const browser=await chromium.launch(),context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:393,height:900}}),page=await context.newPage();page.setDefaultTimeout(15000)
async function channel(name){await openNavigation(page);await page.getByRole('button',{name:'Каналы',exact:true}).click();await rawChannel(page,name)}
try{
 await login(page,'qa_admin',input.password);const session=await api(page,'/me/sessions');status(session,200)
 assert.equal(await page.evaluate(async owner=>(await fetch('/api/v1/me/sessions/revoke-others',{method:'POST',headers:{'X-Account-ID':owner},credentials:'same-origin'})).status,session.body.account_id),204)
 await channel('AccessVoice');await page.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click();await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён',{timeout:30000});report.actual_sfu=true
 if(process.env.QA_EXTRA_CSS)await page.addStyleTag({content:readFileSync(process.env.QA_EXTRA_CSS,'utf8')})
 for(const width of [393,320])for(const scale of [1,2])for(const kind of ['TEXT','DM']){
  await page.setViewportSize({width,height:900});await page.evaluate(scale=>document.documentElement.style.fontSize=scale===2?'200%':'',scale)
  if(kind==='TEXT')await channel('AccessText');else{await openNavigation(page);await page.getByRole('button',{name:'Личные',exact:true}).click();await page.getByRole('navigation',{name:'Личные сообщения'}).getByRole('button',{name:/qa_a11y_peer/}).click();await expect(page.locator('.direct-message-conversation')).toBeVisible()}
  await page.waitForTimeout(400)
  const measurements=await page.evaluate(()=>{const rect=s=>document.querySelector(s).getBoundingClientRect(),dock=rect('.mobile-voice-dock'),field=rect('.composer textarea'),send=rect('.composer button[type="submit"]');return{dock_top:dock.top,dock_bottom:dock.bottom,field_bottom:field.bottom,send_bottom:send.bottom,viewport:innerHeight}})
  const name=`voice-${kind}-${width}-${scale}x`,pass=measurements.field_bottom<=measurements.dock_top&&measurements.send_bottom<=measurements.dock_top
  report.rows.push({name,status:pass?'PASS':'FAIL',measurements});await page.screenshot({path:input.directory+'/'+name+'.png'})
  if(kind==='TEXT'){
   await page.getByRole('button',{name:'Открыть участников',exact:true}).click();await expect(page.getByTestId('members-panel')).toBeVisible()
   const members=await page.evaluate(()=>({panel_bottom:document.querySelector('.members-panel').getBoundingClientRect().bottom,dock_top:document.querySelector('.mobile-voice-dock').getBoundingClientRect().top}))
   report.rows.push({name:`members-${width}-${scale}x`,status:members.panel_bottom<=members.dock_top?'PASS':'FAIL',measurements:members});await page.screenshot({path:input.directory+`/members-${width}-${scale}x.png`});await page.keyboard.press('Escape')
   await openNavigation(page);await page.locator('.guild-search-button').click();await expect(page.getByTestId('search-aside-panel')).toBeVisible()
   const search=await page.locator('.search-close').evaluate(e=>{const r=e.getBoundingClientRect(),hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return{close_inside_viewport:r.top>=0&&r.bottom<=innerHeight,close_hit_target:e.contains(hit),full_modal:document.querySelector('.search-aside').getBoundingClientRect().bottom===innerHeight}})
   const scope=page.getByRole('combobox',{name:'Область поиска',exact:true});await scope.focus();await scope.press('ArrowDown');await scope.press('ArrowUp');await expect(scope).toHaveValue('all')
   const scopeGeometry=await scope.evaluate(e=>{
    const css=getComputedStyle(e),canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');ctx.font=`${css.fontWeight} ${css.fontSize} ${css.fontFamily}`
    const rect=e.getBoundingClientRect(),meta=e.closest('.search-form-meta').getBoundingClientRect(),heading=document.querySelector('.search-panel-heading').getBoundingClientRect(),title=document.querySelector('.search-panel-heading h1').getBoundingClientRect(),modes=document.querySelector('.workspace-search-modes').getBoundingClientRect(),filters=document.querySelector('.search-filters').getBoundingClientRect()
    const controls=[...document.querySelectorAll('.search-form input,.search-form select')].map(field=>{const c=getComputedStyle(field),line=parseFloat(c.lineHeight)||parseFloat(c.fontSize)*1.2;return{kind:field.tagName.toLowerCase(),content_height:field.clientHeight-parseFloat(c.paddingTop)-parseFloat(c.paddingBottom),line_height:line}})
    return{content_height:e.clientHeight-parseFloat(css.paddingTop)-parseFloat(css.paddingBottom),line_height:parseFloat(css.lineHeight),content_width:e.clientWidth-parseFloat(css.paddingLeft)-parseFloat(css.paddingRight),label_width:ctx.measureText(e.selectedOptions[0].textContent).width,meta_contains_scope:rect.top>=meta.top-.5&&rect.bottom<=meta.bottom+.5,filters_clear_meta:filters.top>=meta.bottom-.5,heading_contains_title:title.top>=heading.top-.5&&title.bottom<=heading.bottom+.5,title_clear_modes:title.top>=modes.bottom-.5,controls}
   })
   const scopePass=scopeGeometry.content_height+.5>=scopeGeometry.line_height&&scopeGeometry.content_width+.5>=scopeGeometry.label_width&&scopeGeometry.meta_contains_scope&&scopeGeometry.filters_clear_meta&&scopeGeometry.heading_contains_title&&scopeGeometry.title_clear_modes&&scopeGeometry.controls.every(c=>c.content_height+.5>=c.line_height)
   report.rows.push({name:`search-scope-${width}-${scale}x`,status:scopePass?'PASS':'FAIL',measurements:scopeGeometry});report.rows.push({name:`search-${width}-${scale}x`,status:search.close_inside_viewport&&search.close_hit_target?'PASS':'FAIL',measurements:search});await page.screenshot({path:input.directory+`/search-${width}-${scale}x.png`});await page.keyboard.press('Escape')
  }
 }
 report.status=report.rows.every(r=>r.status==='PASS')?'PASS':'FAIL'
}catch(error){report.status='FAIL';report.error_type=error.name;throw error}finally{const leave=page.getByRole('button',{name:'Выйти из голосового канала',exact:true});if(await leave.isVisible()){await leave.click();await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос не подключён',{timeout:15000});report.actual_voice_cleanup='PASS'}writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n');await context.close();await browser.close()}
if(report.status!=='PASS')process.exitCode=1
