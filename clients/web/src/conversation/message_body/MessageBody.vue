<script setup lang="ts">
import { computed } from 'vue'

import { decorateMessageMentions, type MentionRecipient } from './inline_mentions'

const props = defineProps<{ body: string; mentions?: MentionRecipient[] }>()
const blocks = computed(() => decorateMessageMentions(props.body, props.mentions ?? []).blocks)
</script>

<template>
  <template v-for="(block, blockIndex) in blocks" :key="blockIndex">
    <pre v-if="block.kind === 'CODE_BLOCK'" class="message-code" tabindex="0" role="region" aria-label="Код сообщения"><code>{{ block.value }}</code></pre>
    <p v-else>
      <template v-for="(span, spanIndex) in block.spans" :key="spanIndex">
        <strong v-if="span.kind === 'BOLD'">{{ span.value }}</strong>
        <em v-else-if="span.kind === 'ITALIC'">{{ span.value }}</em>
        <code v-else-if="span.kind === 'CODE'">{{ span.value }}</code>
        <a v-else-if="span.kind === 'LINK'" :href="span.href" target="_blank" rel="noopener noreferrer">{{ span.value }}</a>
        <span v-else-if="span.kind === 'MENTION'" class="message-mention">{{ span.value }}</span>
        <template v-else>{{ span.value }}</template>
      </template>
    </p>
  </template>
</template>
