import { expect, test } from '@playwright/test'

for (const width of [393, 1440]) {
  test(`workspace retains open create intent through cached topology refresh and error at ${width}px`, async ({ page }) => {
    await page.setViewportSize({width,height:900})
    await page.route('**/api/v1/**', route => route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{code:'UNAVAILABLE',message:'QA unavailable'}})}))
    await page.goto('/')
    await page.evaluate(async () => {
      const load=(path:string)=>import(path)
      const [{createApp,h},{createPinia},{default:Workspace},{useTopologyStore},{usePermissionStore}] = await Promise.all([
        load('/tests/browser_runtime/fixture_dependencies.ts'),load('/tests/browser_runtime/fixture_dependencies.ts'),load('/src/workspace/WorkspaceApp.vue'),load('/src/channel/topology_store.ts'),load('/src/authorization/permission_store.ts')])
      const pinia=createPinia()
      document.body.innerHTML='<div id="mount"></div>'
      const app=createApp({render:()=>h(Workspace,{role:'ADMINISTRATOR',accountId:'qa-fixture'})});app.use(pinia);app.mount('#mount')
      const qa=window as Window & {__qaTopology?:ReturnType<typeof useTopologyStore>;__qaPermissions?:ReturnType<typeof usePermissionStore>}
      qa.__qaTopology=(app as any)._instance.subTree.component.setupState.topologyStore;qa.__qaPermissions=(app as any)._instance.subTree.component.setupState.permissions
    })
    await page.waitForTimeout(1800)
    await page.evaluate(() => {
      const qa=window as any
      qa.__qaTopology.refresh = () => Promise.resolve(); qa.__qaTopology.$patch({topology:{revision:1,categories:[]},loading:false,error:null})
      qa.__qaPermissions.snapshot={accountId:'qa-fixture',role:'ADMINISTRATOR',revision:1,permissions:{'category.create':true}}
    })
    if(width<600)await page.getByRole('button',{name:'Открыть навигацию',exact:true}).click()
    await page.getByRole('button',{name:'Создать раздел или канал',exact:true}).click()
    const dialog=page.getByRole('dialog',{name:'Создать раздел',exact:true}),name=dialog.getByLabel('Название раздела')
    await name.fill('QA retained intent')
    await page.evaluate(() => {(window as any).__qaTopology.loading=true})
    await expect(dialog).toBeVisible();await expect(name).toHaveValue('QA retained intent');await expect(name).toBeFocused()
    await page.evaluate(() => {(window as any).__qaTopology.$patch({loading:false,error:'QA unavailable'})})
    await expect(dialog).toBeVisible();await expect(name).toHaveValue('QA retained intent')
    await page.evaluate(() => {(window as any).__qaTopology.$patch({loading:false,error:null,topology:{revision:2,categories:[]}})})
    await expect(dialog).toBeVisible();await expect(name).toHaveValue('QA retained intent')
    await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0)
    await page.evaluate(() => {(window as any).__qaPermissions.snapshot={accountId:'qa-fixture',role:'MEMBER',revision:2,permissions:{}}})
    await expect(page.getByRole('button',{name:'Создать раздел или канал',exact:true})).toHaveCount(0)
  })
}

for (const [width,height,textScale] of [[320,900,1],[393,900,1],[1440,900,1],[320,640,1],[320,640,2],[393,640,2]]) {
  test(`category error keeps actions visible and pointer reachable at ${width}x${height} text ${textScale}`, async ({ page }) => {
    await page.setViewportSize({width,height})
    await page.route('**/api/v1/categories', route => route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{code:'UNAVAILABLE',message:'QA unavailable'}})}))
    await page.goto('/')
    await page.evaluate(async () => {
      const {createApp,h}=await import('/tests/browser_runtime/fixture_dependencies.ts')
      const {createPinia}=await import('/tests/browser_runtime/fixture_dependencies.ts')
      const {default:Actions}=await import('/src/channel/member_topology/ChannelTopologyActions.vue')
      document.body.innerHTML='<div id="mount"></div>'
      const app=createApp({render:()=>h(Actions,{accountId:'qa-fixture',voicePresence:null,topology:{revision:1,categories:[]},permissions:{'category.create':true}})})
      app.use(createPinia());app.mount('#mount')
    })
    await page.evaluate(scale=>{document.documentElement.style.fontSize=`${16*scale}px`},textScale)
    await page.getByRole('button',{name:'Создать раздел или канал',exact:true}).click()
    const dialog=page.getByRole('dialog',{name:'Создать раздел',exact:true})
    await dialog.getByLabel('Название раздела').fill('QA error retry')
    await dialog.getByLabel('Название раздела').press('Enter')
    await expect(dialog.getByRole('alert')).toBeVisible()
    await dialog.hover()
    await page.mouse.wheel(0, 1000)
    await page.waitForTimeout(100)
    const submit=dialog.getByRole('button',{name:'Создать раздел',exact:true})
    const cancel=dialog.getByRole('button',{name:'Отмена',exact:true})
    for (const button of [submit,cancel]) {
      const metrics=await button.evaluate(element=>{
        const r=element.getBoundingClientRect(),owner=element.closest('[role=dialog]')!,d=owner.getBoundingClientRect()
        return {bottom:r.bottom,viewport:innerHeight,dialogBottom:d.bottom,hit:element.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))}
      })
      expect(metrics.bottom).toBeLessThanOrEqual(metrics.viewport)
      expect(metrics.bottom).toBeLessThanOrEqual(metrics.dialogBottom)
      expect(metrics.hit).toBe(true)
    }
    await cancel.click()
    await expect(dialog).toBeHidden()
  })
}
