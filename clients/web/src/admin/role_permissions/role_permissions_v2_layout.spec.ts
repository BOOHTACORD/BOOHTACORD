import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./AdminRolePermissions.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../../design/design_v2_settings.css', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../../design/design_v2_admin_permissions.css', import.meta.url), 'utf8')
const workspace = readFileSync(new URL('../../workspace/WorkspaceMain.vue', import.meta.url), 'utf8')

describe('Design V2 role permission table', () => {
  it('groups all six existing permission keys into three create/delete rows', () => {
    expect(component).toContain('role-permission-table')
    expect(component).toContain('v-for="row in permissionRows"')
    expect(component.match(/create: '.*\.create'/g)).toHaveLength(3)
    expect(component.match(/remove: '.*\.delete'/g)).toHaveLength(3)
  })

  it('keeps the canonical desktop row, table, selector and mobile touch sizes', () => {
    expect(styles).toContain('height: 46px;')
    expect(styles).toContain('height: 44px;')
    expect(styles).toContain('height: 76px;')
    expect(styles).toContain('padding: 24px 24px 12px;')
  })

  it('binds every checkbox directly to the existing permission draft and admin lock', () => {
    expect(component).toContain('v-model="displayed[row.create]"')
    expect(component).toContain('v-model="displayed[row.remove]"')
    expect(component).toContain(':disabled="selected === \'ADMINISTRATOR\'"')
    expect(component).toContain('@click="reset"')
    expect(component).toContain('@click="cancel"')
    expect(component).toContain('@click="save()"')
  })

  it('uses a functional settings header and keeps the mobile deletion notice visible', () => {
    expect(workspace).toContain('<SettingsWorkspaceHeader panel="admin"')
    expect(workspace).toContain("emit('closePanel', 'admin')")
    expect(presentation).toContain('.role-permission-notice { display: flex;')
    expect(presentation).toContain('.role-policy-status { display: block;')
    expect(presentation).not.toContain('.role-policy-actions button:first-of-type { position: absolute;')
  })
})
