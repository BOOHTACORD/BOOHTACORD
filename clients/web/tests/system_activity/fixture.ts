import { createApp, h } from 'vue'
import { createPinia } from 'pinia'
import ProfileSettings from '../../src/identity/ProfileSettings.vue'
import { createBrowserSystemActivity } from '../../src/realtime/system_activity/browser'
import '../../src/style.css'

const observed = { reports: 0 }
const activity = createBrowserSystemActivity(() => observed.reports++)
Object.assign(window, { activityFixture: { activity, observed } })
const profile = { account_id: '11111111-1111-4111-8111-111111111111', login: 'qa', display_name: 'QA', role: 'MEMBER' as const, avatar_url: null }
createApp({ render: () => h('main', { class: 'workspace-main-panel--profile', style: 'height: 900px' }, [
  h(ProfileSettings, { profile, loading: false, loadError: null, systemActivity: activity }),
]) }).use(createPinia()).mount('#app')
