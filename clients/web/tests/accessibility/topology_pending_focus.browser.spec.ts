import { expect, test } from '@playwright/test'

for (const width of [393, 1440]) {
  test(`pending topology create keeps focus inside modal at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    let release!: () => void
    let requested!: () => void
    const started = new Promise<void>(resolve => { requested = resolve })
    await page.route('**/api/v1/categories', async route => {
      requested()
      await new Promise<void>(resolve => { release = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ error: { code: 'UNAVAILABLE', message: 'QA service unavailable' } }) })
    })
    await page.goto('/')
    await page.evaluate(async () => {
      const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
      const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
      const { default: Actions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
      const qaWindow = window as Window & { __qaUnderlyingEscapeCount?: number }
      qaWindow.__qaUnderlyingEscapeCount = 0
      window.addEventListener('keydown', event => { if (event.key === 'Escape') qaWindow.__qaUnderlyingEscapeCount!++ })
      document.body.innerHTML = '<button id="outside">Underlying navigation</button><div id="mount"></div>'
      const app = createApp({ render: () => h(Actions, {
        accountId: 'qa-fixture', voicePresence: null,
        topology: { revision: 1, categories: [] },
        permissions: { 'category.create': true, 'category.delete': false, 'channel.text.create': true, 'channel.text.delete': false, 'channel.voice.create': true, 'channel.voice.delete': false },
      }) })
      app.use(createPinia()); app.mount('#mount')
    })
    await page.getByRole('button', { name: 'Создать раздел или канал', exact: true }).click()
    const dialog = page.getByRole('dialog', { name: 'Создать раздел', exact: true })
    await dialog.getByLabel('Название раздела').fill('QA pending')
    await dialog.getByLabel('Название раздела').press('Enter')
    await started
    await expect(dialog.getByRole('button', { name: 'Создаём…' })).toBeDisabled()
    try {
      await expect.poll(() => dialog.evaluate(element => element.contains(document.activeElement))).toBe(true)
      for (const key of ['Tab', 'Shift+Tab', 'Enter', 'Escape']) {
        await page.keyboard.press(key)
        await expect(dialog).toBeVisible()
        expect(await dialog.evaluate(element => element.contains(document.activeElement))).toBe(true)
      }
      expect(await page.evaluate(() => (window as Window & { __qaUnderlyingEscapeCount: number }).__qaUnderlyingEscapeCount)).toBe(0)
    } finally { release() }
    await expect(dialog.getByRole('alert')).toBeVisible()
  })
}

for (const width of [393, 1440]) {
  test(`destructive confirmation Escape cancels without closing background at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await page.goto('/')
    await page.evaluate(async () => {
      const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
      const { createPinia } = await import('/node_modules/.vite/deps/pinia.js')
      const { default: Actions } = await import('/src/channel/member_topology/ChannelTopologyActions.vue')
      const qaWindow = window as Window & { __qaUnderlyingEscapeCount?: number }
      qaWindow.__qaUnderlyingEscapeCount = 0
      window.addEventListener('keydown', event => { if (event.key === 'Escape') qaWindow.__qaUnderlyingEscapeCount!++ })
      document.body.innerHTML = '<button id="outside">Underlying navigation</button><div id="mount"></div>'
      const app = createApp({ render: () => h(Actions, {
        accountId: 'qa-fixture', voicePresence: null,
        topology: { revision: 1, categories: [{id:'qa-category',name:'QA empty',position:0,channels:[]}] },
        permissions: { 'category.create': true, 'category.delete': true, 'channel.text.create': true, 'channel.text.delete': false, 'channel.voice.create': true, 'channel.voice.delete': false },
      }) })
      app.use(createPinia()); app.mount('#mount')
    })
    const trigger = page.getByRole('button', {name:'Действия с разделом QA empty',exact:true})
    await trigger.click()
    const dialog = page.getByRole('dialog', {name:'Подтвердите действие',exact:true})
    await expect(dialog.getByRole('button',{name:'Отмена',exact:true})).toBeFocused()
    await page.keyboard.press('Escape')
    await expect(dialog).toBeHidden()
    await expect(trigger).toBeFocused()
    expect(await page.evaluate(() => (window as Window & { __qaUnderlyingEscapeCount: number }).__qaUnderlyingEscapeCount)).toBe(0)
  })
}

for (const width of [393, 1440]) {
  test(`workspace retains open create intent through cached topology refresh and error at ${width}px`, async ({ page }) => {
    await page.setViewportSize({width,height:900})
    await page.route('**/api/v1/**', route => route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{code:'UNAVAILABLE',message:'QA unavailable'}})}))
    await page.goto('/')
    await page.evaluate(async () => {
      const load=(path:string)=>import(path)
      const [{createApp,h},{createPinia},{default:Workspace},{useTopologyStore},{usePermissionStore}] = await Promise.all([
        load('/node_modules/.vite/deps/vue.js'),load('/node_modules/.vite/deps/pinia.js'),load('/src/workspace/WorkspaceApp.vue'),load('/src/channel/topology_store.ts'),load('/src/authorization/permission_store.ts')])
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
      const {createApp,h}=await import('/node_modules/.vite/deps/vue.js')
      const {createPinia}=await import('/node_modules/.vite/deps/pinia.js')
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

for (const [width, textScale] of [[320, 1], [393, 1], [1440, 1], [320, 2], [393, 2], [1440, 2]]) {
  test(`destructive action stays inside dialog at ${width}px text ${textScale}`, async ({ page }) => {
    await page.setViewportSize({width, height:640})
    await page.goto('/')
    await page.evaluate(async scale => {
      const {createApp,h,ref,onMounted}=await import('/node_modules/.vite/deps/vue.js')
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
   const [{createApp,h},{createPinia},{default:Workspace}]=await Promise.all([load('/node_modules/.vite/deps/vue.js'),load('/node_modules/.vite/deps/pinia.js'),load('/src/workspace/WorkspaceApp.vue')])
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
