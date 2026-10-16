import { test,expect } from '@playwright/test'
const author='11111111-1111-4111-8111-111111111111',channel='22222222-2222-4222-8222-222222222222'
for (const width of [390,1440]) test(`tab switch keeps search filter/query/scroll at ${width}px`,async({page})=>{
  await page.setViewportSize({width,height:900})
  const reads:URLSearchParams[]=[]
  await page.route('**/api/v1/**',r=>{
    const url=new URL(r.request().url()),path=url.pathname
    const json=path.endsWith('/members')?{members:[{user_id:author,login:'fixture',display_name:'Автор',role:'MEMBER',presence:'online'}]}
      :path.endsWith('/search/messages')?{messages:Array.from({length:30},(_,i)=>({id:`00000000-0000-4000-8000-${String(i).padStart(12,'0')}`,kind:'CHANNEL',channel_id:channel,author_id:author,body:'Synthetic orbit result',created_at:'2026-10-12T10:00:00Z',revision:1}))}
      :path.endsWith('/pins')?{pins:[],can_manage:false}:{members:[]}
    if(path.endsWith('/search/messages'))reads.push(url.searchParams)
    return r.fulfill({json})
  })
  await page.goto('/tests/search_sessions/tabs.html')
  const aside=page.locator('.search-aside'),query=page.getByRole('searchbox',{name:'Запрос',exact:true})
  await query.fill('orbit');await page.getByLabel('Область поиска').selectOption('current')
  await page.locator('.search-filters select').nth(0).selectOption(author)
  await page.locator('.search-filters select').nth(1).selectOption('without')
  await page.getByLabel('С даты',{exact:true}).fill('2026-10-01')
  await page.getByRole('button',{name:'Найти',exact:true}).click()
  await expect(page.locator('.search-result')).toHaveCount(30)
  await aside.evaluate(el=>{el.scrollTop=280;el.dispatchEvent(new Event('scroll'))})
  await expect.poll(()=>aside.evaluate(el=>el.scrollTop)).toBe(280)
  const tab=page.getByRole('button',{name:'Закреплённые',exact:true})
  await expect(tab).toBeInViewport()
  await tab.click();await expect(page.getByText('Закреплений пока нет.',{exact:true})).toBeVisible()
  await page.getByRole('group',{name:'Поиск и упоминания'}).getByRole('button',{name:'Сообщения',exact:true}).click()
  await expect.poll(()=>aside.evaluate(el=>el.scrollTop)).toBe(280)
  await expect(query).toHaveValue('orbit')
  await expect(page.locator('.search-filters select').nth(0)).toHaveValue(author)
  await expect(page.locator('.search-filters select').nth(1)).toHaveValue('without')
  await expect(page.getByLabel('С даты',{exact:true})).toHaveValue('2026-10-01')
  expect(reads).toHaveLength(1)
  await query.fill('fresh query')
  await page.getByRole('button',{name:'Найти',exact:true}).click()
  await expect.poll(()=>reads.length).toBe(2)
  await expect.poll(()=>aside.evaluate(el=>el.scrollTop)).toBe(0)
})
