<script setup lang="ts">
import Viewer from './protected_image_viewer/component.vue'
const props = defineProps<{ name: string; previewUrl: string; downloadUrl: string }>()
</script>
<template><Viewer v-bind="props"><slot /></Viewer></template>
