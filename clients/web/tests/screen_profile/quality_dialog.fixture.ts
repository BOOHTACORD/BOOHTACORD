import { createApp, h } from 'vue'
import '/src/style.css'
import ScreenShareSetupDialog from '/src/voice/ScreenShareSetupDialog.vue'

declare global {
  interface Window {
    selectedScreenQuality?: string
    selectedScreenMode?: 'motion' | 'text'
  }
}

createApp({
  render: () => h(ScreenShareSetupDialog, {
    initialProfile: new URLSearchParams(location.search).get('profile') ?? 'P1080_60',
    onStart: (profile: string, mode: 'motion' | 'text') => { window.selectedScreenQuality = profile; window.selectedScreenMode = mode },
  }),
}).mount('#app')
