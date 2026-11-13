import { afterEach, expect, it, vi } from 'vitest'
import { createSSRApp, h } from 'vue'
import { renderToString } from '@vue/server-renderer'
import NoiseSuppressionSelect from './NoiseSuppressionSelect.vue'

afterEach(() => vi.unstubAllEnvs())
async function render(mode: string) {
  return renderToString(createSSRApp({ render: () => h(NoiseSuppressionSelect, { mode: mode as never }) }))
}

it('keeps experimental DeepFilter hidden by default and preserves a disabled saved choice', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'false')
  expect(await render('browser')).not.toContain('DeepFilterNet3')
  const retained = await render('deepfilter')
  expect(retained).toContain('DeepFilterNet3 — недоступен в этой сборке')
  expect(retained).toMatch(/value="deepfilter"[^>]*disabled/)
})

it('offers the experimental mode with a resource warning only when explicitly enabled', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const html = await render('deepfilter')
  expect(html).toContain('DeepFilterNet3')
  expect(html).toContain('Может повысить нагрузку процессора и задержку')
})
