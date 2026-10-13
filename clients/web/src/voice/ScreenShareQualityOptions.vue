<script setup lang="ts">
import type { ScreenFrameRate, ScreenResolution } from './media_publishing'
defineProps<{ resolution: ScreenResolution; frameRate: ScreenFrameRate; mode: 'motion' | 'text' }>()
const emit = defineEmits<{ 'update:resolution': [value: ScreenResolution]; 'update:frameRate': [value: ScreenFrameRate]; 'update:mode': [value: 'motion' | 'text'] }>()
const resolutions: readonly ScreenResolution[] = [720, 1080, 1440]
const frameRates: readonly ScreenFrameRate[] = [15, 30, 60]
</script>
<template>
  <fieldset class="screen-share-quality__row screen-share-quality__mode"><legend>Сценарий</legend>
    <div class="screen-share-quality__scenarios" role="radiogroup" aria-label="Сценарий демонстрации">
      <label class="screen-share-quality__scenario-option"><input :checked="mode === 'motion'" type="radio" name="screen-share-mode" value="motion" @change="emit('update:mode', 'motion')"><span class="screen-share-quality__scenario-copy"><strong class="screen-share-quality__scenario-title">Плавность</strong><small>Игры и видео</small></span></label>
      <label class="screen-share-quality__scenario-option"><input :checked="mode === 'text'" type="radio" name="screen-share-mode" value="text" @change="emit('update:mode', 'text')"><span class="screen-share-quality__scenario-copy"><strong class="screen-share-quality__scenario-title">Чёткость текста</strong><small>Документы и код</small></span></label>
    </div>
  </fieldset>
  <section class="screen-share-quality__settings" aria-labelledby="screen-share-quality-settings-title">
    <h4 id="screen-share-quality-settings-title">Качество изображения</h4>
    <div class="screen-share-quality__settings-options">
      <fieldset class="screen-share-quality__row"><legend>Максимальное разрешение</legend>
        <div class="screen-share-quality__segments screen-share-quality__segments--3" role="radiogroup" aria-label="Верхний предел разрешения трансляции">
          <label v-for="value in resolutions" :key="value" class="screen-share-quality__option"><input :checked="resolution === value" type="radio" name="screen-share-resolution" :value="value" @change="emit('update:resolution', value)"><span>{{ value }}p</span></label>
        </div>
      </fieldset>
      <fieldset class="screen-share-quality__row screen-share-quality__row--frame-rate"><legend>Частота кадров</legend>
        <div class="screen-share-quality__segments screen-share-quality__segments--3" role="radiogroup" :aria-label="`Частота кадров для ${mode === 'motion' ? 'плавности' : 'текста'}`">
          <label v-for="value in frameRates" :key="value" class="screen-share-quality__option"><input :checked="frameRate === value" type="radio" name="screen-share-frame-rate" :value="value" :disabled="resolution === 1440 && value === 60" @change="emit('update:frameRate', value)"><span>{{ value }} FPS</span></label>
        </div>
      </fieldset>
    </div>
  </section>
</template>
