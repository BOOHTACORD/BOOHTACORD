import { createApp, h } from 'vue'
import '/src/style.css'
import ScreenShareSetupDialog from '/src/voice/ScreenShareSetupDialog.vue'

declare global {
  interface Window {
    selectedScreenQuality?: string
  }
}

createApp({
  render: () => h(ScreenShareSetupDialog, {
    initialProfile: new URLSearchParams(location.search).get('profile') ?? 'P1080_60',
    onStart: (profile: string) => { window.selectedScreenQuality = profile },
  }),
}).mount('#app')
