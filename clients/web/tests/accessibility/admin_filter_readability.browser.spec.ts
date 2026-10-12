import {expect,test} from '@playwright/test'
for (const width of [320,393,1440]) {
 test(`admin filter selected labels fit readable text area at ${width}px`,async({page})=>{
  await page.setViewportSize({width,height:900})
  await page.route('**/api/v1/admin/accounts*',r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({accounts:[]})}))
  await page.goto('/')
  await page.evaluate(async()=>{
   const {createApp,h}=await import('/node_modules/.vite/deps/vue.js')
   const {default:Members}=await import('/src/admin/members/AdminMembersSection.vue')
   document.body.innerHTML='<main class="admin-panel admin-panel--members" style="max-width:880px; margin:auto; padding:16px;"><div id="mount"></div></main>'
   createApp({render:()=>h(Members)}).mount('#mount')
   await document.fonts.ready
  })
  for(const [label,values] of [['Фильтр по роли',['ALL','MEMBER','ADMINISTRATOR']],['Фильтр по статусу',['ALL','ACTIVE','BLOCKED']]] as const){
   const select=page.getByLabel(label)
   for(const value of values){
    await select.selectOption(value)
    const budget=await select.evaluate(element=>{
     const s=element as HTMLSelectElement,css=getComputedStyle(s),ctx=document.createElement('canvas').getContext('2d')!
     ctx.font=`${css.fontStyle} ${css.fontWeight} ${css.fontSize} ${css.fontFamily}`
     return {text:ctx.measureText(s.selectedOptions[0]!.textContent!).width,available:s.clientWidth-parseFloat(css.paddingLeft)-parseFloat(css.paddingRight)-20}
    })
    expect(budget.text,`${label} ${value} must leave native arrow room`).toBeLessThanOrEqual(budget.available)
   }
  }
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true)
 })
}
