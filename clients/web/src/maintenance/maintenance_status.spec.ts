import { createSSRApp } from 'vue'
import { renderToString } from '@vue/server-renderer'
import { describe, expect, it } from 'vitest'
import MaintenanceStatus from './MaintenanceStatus.vue'

describe('maintenance status', () => {
  it('distinguishes unavailable state from an inactive flag', async () => {
    const unknown = await renderToString(createSSRApp(MaintenanceStatus, { active: false, known: false }))
    const inactive = await renderToString(createSSRApp(MaintenanceStatus, { active: false, known: true }))
    expect(unknown).toContain('Проверяем статус обслуживания')
    expect(inactive).not.toContain('Проверяем статус обслуживания')
  })

  it('retains the maintenance warning while reconnecting', async () => {
    const stale = await renderToString(createSSRApp(MaintenanceStatus, { active: true, known: false }))
    expect(stale).toContain('Идёт обновление')
    expect(stale).toContain('Проверяем статус обслуживания')
  })
})
