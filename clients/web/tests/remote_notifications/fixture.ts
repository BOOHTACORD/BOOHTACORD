import { createApp } from 'vue'
import { createPinia } from 'pinia'
import Settings from '../../src/notification/server_preferences/Settings.vue'
import { useServerNotifications } from '../../src/notification/server_preferences/state'
import '../../src/style.css'
const pinia = createPinia(), remote = useServerNotifications(pinia)
remote.snapshot = { capability: { version: 1, available: false, device_transport: 'unavailable' }, settings: { version: 1, revision: 2, enabled: false, imported: false, dm: { mode: 'all', paused_until: null }, text: { mode: 'mentions', paused_until: null }, overrides: [] } }
remote.preview = { source_present: true, overrides: [], local_disabled: true, errors: [] }
remote.status = 'Оператор не настроил фоновую доставку'
remote.save = async change => { if (remote.snapshot) change(remote.snapshot.settings) }
const mount = document.getElementById('app')!; mount.style.cssText = 'max-width:760px;margin:24px auto;padding:16px;box-sizing:border-box'
createApp(Settings).use(pinia).mount(mount)
