<script setup lang="ts">
import Settings from './Settings.vue'
import LegacyReview from './LegacyReview.vue'
import { voiceSoundPreferences as preferences, previewSound } from '../sound_playback/runtime'
const { settings, unsynchronised, ready } = preferences
</script>
<template><LegacyReview /><Settings :settings="settings" :ready="ready" :unsynchronised="unsynchronised" @change="change => preferences.patch(change)" @preview="previewSound" /></template>
