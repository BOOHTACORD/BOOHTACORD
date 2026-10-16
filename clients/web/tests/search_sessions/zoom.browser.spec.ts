import { test, expect, chromium } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { captureZoomedPage, withBrowserZoom } from '../control_consistency/browser_zoom'
for (const width of [640, 780, 2048, 2880]) {
  test(`all four search modes at actual 200% zoom in ${width}px window`, async ({}, info) => {
    await withBrowserZoom(chromium, width, 2, async page => {
      await page.route('**/api/v1/**', route => {
        const path = new URL(route.request().url()).pathname
        return route.fulfill({ json: path.endsWith('/pins') ? { pins: [], can_manage: false }
          : path.endsWith('/mentions') ? { mentions: [] }
          : path.endsWith('/archives/text-channels') ? { channels: [], revision: 1, can_manage: false }
          : { members: [] } })
      })
      await page.goto('/tests/search_sessions/tabs.html')
      await page.evaluate(() => document.fonts.ready)
      const geometry = await page.evaluate(() => ({ outerWidth, innerWidth, dpr: devicePixelRatio,
        rootFont: getComputedStyle(document.documentElement).fontSize, cssZoom: getComputedStyle(document.body).zoom, pinch: visualViewport!.scale }))
      expect(geometry).toEqual({ outerWidth: width, innerWidth: width/2, dpr: 2, rootFont: '16px', cssZoom: '1', pinch: 1 })
      const aside = page.locator('.search-aside'), tabs = page.getByRole('group', { name: 'Поиск и упоминания' }).getByRole('button')
      const query = page.getByRole('searchbox', { name:'Запрос', exact:true })
      await query.fill('Запрос при масштабе 200%')
      await page.getByLabel('Область поиска').selectOption('current')
      for (let i=0;i<4;i++) {
        await tabs.nth(i).focus(); await page.keyboard.press('Enter')
        await expect(tabs.nth(i)).toHaveAttribute('aria-pressed','true')
        await expect(tabs.nth(i)).toBeInViewport()
        const rail = (await aside.boundingBox())!, box = (await tabs.nth(i).boundingBox())!
        expect(box.x).toBeGreaterThanOrEqual(rail.x)
        expect(box.x+box.width).toBeLessThanOrEqual(rail.x+rail.width+1)
        expect(await aside.evaluate(el=>el.scrollWidth-el.clientWidth)).toBeLessThanOrEqual(1)
        expect(await aside.evaluate(el=>el.scrollLeft)).toBe(0)
        const png = await captureZoomedPage(page,info.outputPath(`mode-${i}-zoom.png`))
        expect(png.readUInt32BE(16)).toBe(width)
      }
      await tabs.first().click()
      await expect(query).toHaveValue('Запрос при масштабе 200%')
      await expect(page.getByLabel('Область поиска')).toHaveValue('current')
      await tabs.last().evaluate(el=>{el.textContent='ОченьДлиннаяЛокализованнаяПодписьЗакреплённыхСообщений'})
      await tabs.last().focus()
      expect(await aside.evaluate(el=>el.scrollWidth-el.clientWidth)).toBeLessThanOrEqual(1)
      await writeFile(info.outputPath('browser-zoom.json'), JSON.stringify(geometry,null,2))
    })
  })
}
