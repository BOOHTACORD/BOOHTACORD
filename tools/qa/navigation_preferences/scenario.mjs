import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { api, status, login, chromium, expect, openNavigation, channel } from '../client_lifecycle/request.mjs'
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
const report = { issue: 251, width: input.width, checks: {}, origins: ['https://localhost:4810', 'https://localhost:4811'], roles: ['ADMIN', 'MEMBER'], mocks: false }
const browser = await chromium.launch({ args: ['--allow-loopback-in-peer-connection'] })
const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: input.width, height: 900 } })
context.setDefaultTimeout(20000)
const page = await context.newPage()
const disclosure = name => page.getByRole('button', { name, exact: true })
async function screenshot(name) { await page.screenshot({ path: input.directory+'/'+name+'.png' }) }
async function signedIn(origin, name) {
  await page.goto(origin)
  await page.getByLabel('Логин', { exact:true }).fill(name)
  await page.getByLabel('Пароль', { exact:true }).fill(input.password)
  await page.getByRole('button', { name:'Войти', exact:true }).click()
  await expect(page.getByTestId('app-shell')).toBeVisible()
  await openNavigation(page)
}
async function logout() { status(await api(page,'/auth/logout','POST',{}),204) }
try {
  await login(page,'qa_admin',input.password)
  status(await api(page,'/auth/register','POST',{login:'qa_favorites_member',password:input.password}),201)
  const category = await api(page,'/admin/categories','POST',{name:'QaFavorites'}); status(category,201)
  const text = await api(page,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaText',kind:'TEXT'}); status(text,201)
  const voice = await api(page,`/admin/categories/${category.body.id}/channels`,'POST',{name:'QaVoice',kind:'VOICE'}); status(voice,201)
  await page.reload(); await openNavigation(page)
  await disclosure('Добавить в избранное: QaText').click()
  await expect(page.locator('.channel-favorite-link')).toHaveCount(1)
  await disclosure('Свернуть раздел QaFavorites').click()
  await expect(disclosure('Развернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','false')
  await page.reload(); await openNavigation(page)
  await expect(page.locator('.channel-favorite-link')).toHaveCount(1)
  await expect(disclosure('Развернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','false')
  await screenshot('favorite-restored')
  report.checks.add_reload_restore = 'PASS'
  await logout(); await signedIn('https://localhost:4810','qa_favorites_member')
  await expect(page.locator('.channel-favorite-link')).toHaveCount(0)
  await expect(disclosure('Свернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','true')
  await disclosure('Добавить в избранное: QaVoice').click()
  await disclosure('Свернуть раздел QaFavorites').click()
  await logout(); await signedIn('https://localhost:4810','qa_admin')
  await expect(page.locator('.channel-favorite-link')).toHaveCount(1)
  await expect(page.locator('.channel-favorite-link')).toContainText('QaText')
  await expect(disclosure('Развернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','false')
  report.checks.accounts_isolated = 'PASS'
  // Same cookie jar, same guild/user IDs, same browser profile: only origin changes.
  await page.goto('https://localhost:4811')
  await expect(page.getByTestId('app-shell')).toBeVisible()
  await openNavigation(page)
  await expect(page.locator('.channel-favorite-link')).toHaveCount(0)
  await expect(disclosure('Свернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','true')
  await disclosure('Добавить в избранное: QaVoice').click()
  await disclosure('Свернуть раздел QaFavorites').click()
  await page.goto('https://localhost:4810'); await openNavigation(page)
  await expect(page.locator('.channel-favorite-link')).toHaveCount(1)
  await expect(page.locator('.channel-favorite-link')).toContainText('QaText')
  await expect(disclosure('Развернуть раздел QaFavorites')).toHaveAttribute('aria-expanded','false')
  report.checks.origins_isolated = 'PASS'
  await disclosure('Развернуть раздел QaFavorites').click()
  await disclosure('Убрать из избранного: QaText').click()
  await page.reload(); await openNavigation(page)
  await expect(page.locator('.channel-favorite-link')).toHaveCount(0)
  report.checks.remove_reload_restore = 'PASS'
  const search = page.getByRole('searchbox',{name:'Поиск каналов',exact:true})
  await search.fill('qAtExT')
  await expect(page.locator('.channel-row .channel-button')).toHaveCount(1)
  await channel(page,'QaText'); await openNavigation(page)
  await expect(page.locator('.channel-row .channel-button').filter({hasText:'QaText'})).toHaveAttribute('aria-current','page')
  await search.fill('qAfAvOrItEs')
  await expect(page.locator('.channel-row .channel-button')).toHaveCount(2)
  await screenshot('case-insensitive-search')
  await search.fill('')
  report.checks.case_insensitive_search_and_navigation = 'PASS'
  await channel(page,'QaVoice')
  await page.getByRole('button',{name:'Подключиться без микрофона',exact:true}).click()
  const dock = page.getByTestId('voice-dock')
  await expect(dock.locator('.voice-status')).toHaveText('Голос подключён',{timeout:25000})
  await openNavigation(page)
  await disclosure('Свернуть раздел QaFavorites').click()
  await expect(dock).toBeVisible()
  await expect(dock.getByRole('button',{name:'Выйти из голосового канала',exact:true})).toBeVisible()
  await screenshot('collapsed-connected-dock')
  await dock.getByRole('button',{name:'Выйти из голосового канала',exact:true}).click()
  await expect(dock.locator('.voice-status')).toHaveText('Голос не подключён')
  report.checks.collapsed_voice_dock_and_controls = 'PASS'
  await openNavigation(page)
  await disclosure('Развернуть раздел QaFavorites').click()
  await disclosure('Добавить в избранное: QaText').click()
  const before = await api(page,'/channels'); status(before,200)
  status(await api(page,`/admin/channels/${text.body.id}`,'DELETE',{expected_revision:before.body.revision,confirm_archive:true}),200)
  await expect(page.locator('.channel-favorite-link')).toHaveCount(0)
  const after = await api(page,'/channels'); status(after,200)
  assert.equal(after.body.categories.length,before.body.categories.length)
  assert.deepEqual(after.body.categories.flatMap(c=>c.channels.map(x=>x.id)).sort(),before.body.categories.flatMap(c=>c.channels.map(x=>x.id)).filter(id=>id!==text.body.id).sort())
  const account = (await api(page,'/auth/session')).body.account_id
  await expect.poll(() => page.evaluate(({account, id}) => {
    const key = `boohtacord:navigation:${encodeURIComponent(location.origin)}:${encodeURIComponent(account)}:v1`
    const raw = localStorage.getItem(key)
    return raw !== null && !JSON.parse(raw).favorites.includes(id)
  }, {account, id:text.body.id})).toBe(true)
  await screenshot('archived-favorite-pruned')
  report.checks.archive_prune_no_extra_topology_mutation = 'PASS'
  report.status = 'PASS'
  report.browser = browser.version()
} finally {
  writeFileSync(process.env.QA_RESULT,JSON.stringify(report,null,2)+'\n')
  await context.close(); await browser.close()
}
