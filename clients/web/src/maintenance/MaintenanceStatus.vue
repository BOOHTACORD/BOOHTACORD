<script setup lang="ts">
import MaintenanceBanner from './MaintenanceBanner.vue'
defineProps<{ active: boolean; known: boolean }>()
</script>

<template>
  <MaintenanceBanner v-if="active" />
  <section v-if="!known" class="maintenance-banner" role="status">Проверяем статус обслуживания и восстанавливаем связь…</section>
</template>
