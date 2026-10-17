import { expect, test } from '@playwright/test'

for (const kind of ['TEXT', 'DM']) {
  for (const viewport of [{width:320,height:640},{width:393,height:852},{width:844,height:390},{width:1440,height:900}]) {
    test(`${kind} exposes conversation files menu at ${viewport.width}px`, async ({page}) => {
      await page.setViewportSize(viewport)
      await page.goto('/')
      await page.evaluate(async kind => {
        const load = (path: string) => import(path)
        const {createApp,h} = await load('/node_modules/.vite/deps/vue.js')
        const {default: HeaderActions} = await load('/src/shared/workspace_header/WorkspaceHeaderActions.vue')
        const {default: Overflow} = await load('/src/conversation/ConversationOverflowMenu.vue')
        document.body.innerHTML = '<div id="mount"></div>'
        createApp({render:()=>h('header',{class:'conversation-header'},[
          h('div',{class:'main-title'},[h('strong',{},'Длинное название канала или личной беседы')]),
          h(HeaderActions,{membersExpanded:false,navExpanded:false,showMembers:kind==='TEXT'}, {
            default:()=>h('button',{class:'header-action','aria-label':'Найти сообщение'},'⌕'),
            overflow:()=>h(Overflow,{showFiles:true,showMembers:kind==='TEXT',onFiles:()=>{document.body.dataset.filesOpened='true'}}),
          }),
        ])}).mount('#mount')
      },kind)
      const trigger=page.getByRole('button',{name:'Другие действия',exact:true})
      await expect(trigger).toBeVisible()
      const bounds=await trigger.boundingBox()
      expect(bounds).not.toBeNull()
      expect(bounds!.x).toBeGreaterThanOrEqual(0)
      expect(bounds!.x+bounds!.width).toBeLessThanOrEqual(viewport.width)
      if (viewport.width < 1024) expect(bounds!.height).toBeGreaterThanOrEqual(44)
      await trigger.click()
      await page.getByRole('menuitem',{name:'Файлы беседы',exact:true}).click()
      await expect(page.locator('body')).toHaveAttribute('data-files-opened','true')
      await expect(page.getByRole('tooltip')).toHaveCount(0)
    })
  }
}
