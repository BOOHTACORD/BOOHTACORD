<script setup lang="ts">
import { computed } from 'vue'
import { messageTimestamp } from './message_timestamp'
const props = defineProps<{ createdAt: string }>()
const label = computed(() => messageTimestamp(props.createdAt))
</script>
<template>
  <time class="message-time" :datetime="createdAt" :aria-label="label.full" :title="label.full">{{ label.short }}</time>
</template>
