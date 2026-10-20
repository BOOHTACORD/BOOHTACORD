import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolvePublicOrigin } from './src/social_preview/origin.ts'

const document = JSON.parse(readFileSync(new URL('../../contracts/client-build.json', import.meta.url), 'utf8'))
const build = document.builds.web
const buildInfo = { schema_version:1, application_family:document.application_family, ...build }
const buildInfoJSON = JSON.stringify(buildInfo, null, 2) + '\n'
const digest = createHash('sha256').update(buildInfoJSON).digest('hex')

export default defineConfig(({ mode }) => {
  const environment = loadEnv(mode, process.cwd(), 'VITE_')
  const socialOrigin = resolvePublicOrigin(environment.VITE_PUBLIC_ORIGIN, mode)
  return {
    define: {
      __APP_RELEASE_ID__: JSON.stringify(build.release_id),
      __APP_RELEASE_ORDER__: JSON.stringify(build.release_order),
      __APP_VERSION__: JSON.stringify(build.version),
      __APP_NATIVE_BUILD__: JSON.stringify(build.native_build),
    },
    plugins: [vue(), {
      name: 'social-preview-origin',
      transformIndexHtml: (html) => html.replaceAll('__SOCIAL_ORIGIN__', socialOrigin),
    }, {
      name:'client-build-info', generateBundle() {
        this.emitFile({ type:'asset', fileName:'build-info.json', source:buildInfoJSON })
        this.emitFile({ type:'asset', fileName:'release-receipt.json', source:JSON.stringify({ ...buildInfo, architecture:'any', build_info_sha256:digest, source_revision:process.env.SOURCE_REVISION ?? 'unknown', signature_evidence:'oci_attestation', download_available:true }, null, 2)+'\n' })
      }
    }],
    test: {
      environment: 'node',
      include: ['src/**/*.spec.ts', 'tests/uiux_2026/visual_matrix.spec.ts', 'tests/settings_hierarchy/*.unit.spec.ts'],
    },
  }
})
