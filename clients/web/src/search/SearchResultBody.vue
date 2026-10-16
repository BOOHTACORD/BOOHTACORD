<script setup lang="ts">
import { computed } from 'vue'
import { searchResultSnippet } from './result_snippet'
const props = defineProps<{ body: string; query: string }>()
const parts = computed(() => searchResultSnippet(props.body, props.query))
</script>

<template>
  <div class="search-result-body"><p><template v-for="(part, index) in parts" :key="index"><mark v-if="part.match">{{ part.value }}</mark><template v-else>{{ part.value }}</template></template></p></div>
</template>
