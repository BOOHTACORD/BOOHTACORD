<script setup lang="ts">
import { computed, ref } from 'vue'

import { createPasswordResetForm } from './password_reset_form'
import { usePasswordResetResultFocus } from './password_reset_result_focus'

const props = defineProps<{ validLink: boolean; complete: (password: string) => Promise<void> }>()
const emit = defineEmits<{ invalidLink: []; returnToLogin: [] }>()
const { password, confirmation, pending, completed, unusable, error, submit } = createPasswordResetForm(
  (value) => props.complete(value),
  () => emit('invalidLink'),
)
const showPassword = ref(false)
const showConfirmation = ref(false)
const resultMessage = ref<HTMLElement | null>(null)
usePasswordResetResultFocus(computed(() => completed.value || unusable.value || !props.validLink), resultMessage)
</script>

<template>
  <main class="authentication-page" aria-labelledby="password-reset-title">
    <section class="authentication-card">
      <p class="eyebrow">Безопасность аккаунта</p>
      <h1 id="password-reset-title">Новый пароль</h1>
      <p v-if="completed" ref="resultMessage" class="authentication-intro" role="status" tabindex="-1">Пароль изменён. Войдите в аккаунт с новым паролем.</p>
      <p v-else-if="!validLink || unusable" ref="resultMessage" class="authentication-error" role="alert" tabindex="-1">{{ error ?? 'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.' }}</p>
      <form v-else class="authentication-form" @submit.prevent="submit">
        <div class="authentication-field">
          <label for="password-reset-password">Новый пароль</label>
          <span class="authentication-password-control">
            <input id="password-reset-password" v-model="password" :type="showPassword ? 'text' : 'password'" autocomplete="new-password" required :disabled="pending" :aria-invalid="Boolean(error)" :aria-describedby="error ? 'password-reset-length-hint password-reset-error' : 'password-reset-length-hint'">
            <button class="authentication-password-toggle" type="button" :disabled="pending" :aria-label="showPassword ? 'Скрыть пароль' : 'Показать пароль'" :aria-pressed="showPassword" @click="showPassword = !showPassword"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z" /></svg></button>
          </span>
        </div>
        <div class="authentication-field">
          <label for="password-reset-confirmation">Повторите пароль</label>
          <span class="authentication-password-control">
            <input id="password-reset-confirmation" v-model="confirmation" :type="showConfirmation ? 'text' : 'password'" autocomplete="new-password" required :disabled="pending" :aria-invalid="Boolean(error)" :aria-describedby="error ? 'password-reset-error' : undefined">
            <button class="authentication-password-toggle" type="button" :disabled="pending" :aria-label="showConfirmation ? 'Скрыть пароль' : 'Показать пароль'" :aria-pressed="showConfirmation" @click="showConfirmation = !showConfirmation"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z" /></svg></button>
          </span>
        </div>
        <p id="password-reset-length-hint" class="authentication-hint">От 12 до 128 символов.</p>
        <p v-if="error" id="password-reset-error" class="authentication-error" role="alert">{{ error }}</p>
        <button class="authentication-submit" type="submit" :disabled="pending">{{ pending ? 'Меняем пароль…' : 'Изменить пароль' }}</button>
      </form>
      <button v-if="completed || !validLink || unusable" class="authentication-submit" type="button" @click="emit('returnToLogin')">Перейти ко входу</button>
    </section>
  </main>
</template>
