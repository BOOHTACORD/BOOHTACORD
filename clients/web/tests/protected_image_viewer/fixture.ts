import { createApp, h, ref } from 'vue'
import TextAttachments from '../../src/conversation/TextMessageAttachments.vue'
import DirectAttachments from '../../src/direct_message/DirectMessageAttachments.vue'
import '../../src/style.css'

const params = new URLSearchParams(location.search)
const kind = params.get('kind') === 'DM' ? 'DM' : 'TEXT'
const scope = ref('first')
const name = 'Защищённое изображение с длинным именем.png'
const attachment = { id: 'shared-attachment', originalName: name, sizeBytes: 1280 }
declare global { interface Window { viewerFixture: { changeScope: () => void } } }
window.viewerFixture = { changeScope: () => { scope.value = 'second' } }
createApp({ render: () => h('main', { style: 'padding:16px;max-width:720px;margin:auto' }, [
  h('button', { id: 'outside', type: 'button' }, 'Другой элемент'),
  kind === 'TEXT'
    ? h(TextAttachments, { channelId: scope.value, attachments: [attachment] })
    : h(DirectAttachments, { directMessageId: scope.value, attachments: [attachment] }),
]) }).mount('#app')
