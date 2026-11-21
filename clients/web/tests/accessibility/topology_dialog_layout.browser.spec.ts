import { expect, test } from '@playwright/test'

for (const [width, textScale] of [[320, 1], [393, 1], [1440, 1], [320, 2], [393, 2], [1440, 2]]) {
  test(`destructive action stays inside dialog at ${width}px text ${textScale}`, async ({ page }) => {
    await page.setViewportSize({width, height:640})
    await page.goto('/')
    await page.evaluate(async scale => {
      const {createApp,h,ref,onMounted}=await import('/tests/browser_runtime/fixture_dependencies.ts')
      const {default:Confirmation}=await import('/src/channel/AdminConfirmation.vue')
      document.body.innerHTML='<div id="mount"></div>'
      document.documentElement.style.fontSize=`${16*scale}px`
      createApp({setup(){const dialog=ref();onMounted(()=>dialog.value.ask('Архивировать «QaInactiveVoice»? Канал скроется из списка, история сообщений сохранится. Это действие нельзя отменить.'));return()=>h(Confirmation,{ref:dialog,id:'qa-danger',title:'Подтвердите действие',confirmLabel:'Архивировать'})}}).mount('#mount')
    }, textScale)
    const dialog=page.getByRole('dialog',{name:'Подтвердите действие',exact:true})
    await expect(dialog).toBeVisible()
    if(width===1440 && textScale===1) expect((await dialog.boundingBox())!.height).toBe(287)
    const messageWidth=await dialog.locator('p').evaluate(e=>({scroll:e.scrollWidth,client:e.clientWidth}))
    expect(messageWidth.scroll).toBeLessThanOrEqual(messageWidth.client)
    for(const button of [dialog.getByRole('button',{name:'Отмена',exact:true}),dialog.getByRole('button',{name:'Архивировать',exact:true})]) {
      const rect=await button.evaluate(element=>{const r=element.getBoundingClientRect(),d=element.closest('dialog')!.getBoundingClientRect();return {left:r.left,right:r.right,bottom:r.bottom,dialogLeft:d.left,dialogRight:d.right,dialogBottom:d.bottom,viewportWidth:innerWidth,viewportHeight:innerHeight,scroll:element.scrollWidth,client:element.clientWidth,hit:element.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))}})
      expect(rect.right).toBeLessThanOrEqual(rect.dialogRight)
      expect(rect.right).toBeLessThanOrEqual(rect.viewportWidth)
      expect(rect.left).toBeGreaterThanOrEqual(rect.dialogLeft)
      expect(rect.bottom).toBeLessThanOrEqual(rect.dialogBottom)
      expect(rect.bottom).toBeLessThanOrEqual(rect.viewportHeight)
      expect(rect.scroll).toBeLessThanOrEqual(rect.client)
      expect(rect.hit).toBe(true)
    }
    await dialog.getByRole('button',{name:'Отмена',exact:true}).click()
    await expect(dialog).toBeHidden()
  })
}

for(const [width,textScale] of [[320,1],[393,1],[1440,1],[320,2]]) {
 test(`workspace archive action fits modal at ${width}px text ${textScale}`,async({page})=>{
  await page.setViewportSize({width,height:640})
  await page.route('**/api/v1/**',r=>r.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{code:'UNAVAILABLE',message:'QA unavailable'}})}))
  await page.goto('/')
  await page.evaluate(async()=>{
   const load=(p:string)=>import(p)
   const [{createApp,h},{createPinia},{default:Workspace}]=await Promise.all([load('/tests/browser_runtime/fixture_dependencies.ts'),load('/tests/browser_runtime/fixture_dependencies.ts'),load('/src/workspace/WorkspaceApp.vue')])
   const pinia=createPinia();document.body.innerHTML='<div id="mount"></div>';const app=createApp({render:()=>h(Workspace,{role:'ADMINISTRATOR',accountId:'qa-fixture'})});app.use(pinia);app.mount('#mount');const qa=window as any;qa.__qaTopology=(app as any)._instance.subTree.component.setupState.topologyStore;qa.__qaPermissions=(app as any)._instance.subTree.component.setupState.permissions
  })
  await page.waitForTimeout(1800)
  await page.evaluate(scale=>{const qa=window as any;document.documentElement.style.fontSize=`${16*scale}px`;qa.__qaTopology.refresh=()=>Promise.resolve();qa.__qaTopology.$patch({loading:false,error:null,topology:{revision:1,categories:[{id:'qa-category',name:'QA category',position:0,channels:[{id:'qa-text',name:'QA disposable',kind:'TEXT',position:0}]}]}});qa.__qaPermissions.snapshot={accountId:'qa-fixture',role:'ADMINISTRATOR',revision:1,permissions:{'channel.text.delete':true}}},textScale)
  if(width<600)await page.getByRole('button',{name:'Открыть навигацию',exact:true}).click()
  const trigger=page.getByRole('button',{name:'Действия с каналом QA disposable',exact:true});await trigger.focus();await page.keyboard.press('Enter')
  const dialog=page.getByRole('dialog',{name:'Подтвердите действие',exact:true});await expect(dialog).toBeVisible()
  const button=dialog.getByRole('button',{name:'Архивировать',exact:true})
  const r=await button.evaluate(e=>{const r=e.getBoundingClientRect(),d=e.closest('dialog')!.getBoundingClientRect();return{right:r.right,dialogRight:d.right,bottom:r.bottom,dialogBottom:d.bottom,hit:e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))}})
  expect(r.right).toBeLessThanOrEqual(r.dialogRight);expect(r.right).toBeLessThanOrEqual(width);expect(r.bottom).toBeLessThanOrEqual(r.dialogBottom);expect(r.hit).toBe(true)
  await dialog.getByRole('button',{name:'Отмена',exact:true}).click();await expect(dialog).toBeHidden()
 })
}
