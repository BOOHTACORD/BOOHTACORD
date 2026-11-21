import { createApp, h } from 'vue'
import Settings from '../../src/realtime/system_activity/Settings.vue'
import { startAppInteraction } from '../../src/realtime/system_activity/app_interaction'
import { createBrowserSystemActivity } from '../../src/realtime/system_activity/browser'

const observed = { reports: 0, inactive: 0 }
const activity = createBrowserSystemActivity(() => observed.reports++, () => observed.inactive++)
const stop = startAppInteraction(window, () => observed.reports++)
Object.assign(window, { fallbackFixture: { activity, observed, stop } })
createApp({ render: () => h(Settings, { activity }) }).mount('#app')
