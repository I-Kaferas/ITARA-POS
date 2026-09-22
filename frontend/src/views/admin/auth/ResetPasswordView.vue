<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import LanguageSwitcher from '../../../components/ui/LanguageSwitcher.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useAuthStore } from '../../../stores/auth'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const email = ref((route.query.email as string) ?? '')
const token = ref((route.query.token as string) ?? '')
const password = ref('')
const passwordConfirmation = ref('')
const success = ref(false)
const error = ref('')

async function submit() {
  error.value = ''
  try {
    await auth.resetPassword(token.value, email.value, password.value, passwordConfirmation.value)
    success.value = true
  } catch (e) {
    error.value = e instanceof Error ? e.message : t('common.error')
  }
}
</script>

<template>
  <div class="auth-screen">
    <div class="auth-locale"><LanguageSwitcher tone="glass" /></div>
    <div class="w-full max-w-md rounded-2xl bg-white p-8 shadow-xl">
      <h1 class="mb-6 text-2xl font-bold text-slate-900">{{ t('auth.resetTitle') }}</h1>

      <form v-if="!success" class="space-y-4" @submit.prevent="submit">
        <div>
          <FieldLabel icon="mail">{{ t('auth.email') }}</FieldLabel>
          <input v-model="email" type="email" required class="field" />
        </div>
        <div>
          <FieldLabel icon="lock">{{ t('auth.newPassword') }}</FieldLabel>
          <input v-model="password" type="password" required minlength="8" class="field" />
        </div>
        <div>
          <FieldLabel icon="lock">{{ t('auth.confirmPassword') }}</FieldLabel>
          <input v-model="passwordConfirmation" type="password" required class="field" />
        </div>
        <p v-if="error" class="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>
        <button type="submit" class="btn-primary w-full">{{ t('auth.resetPassword') }}</button>
      </form>

      <div v-else class="space-y-4">
        <p class="rounded-lg bg-green-50 px-4 py-3 text-sm text-green-800">{{ t('auth.resetSuccess') }}</p>
        <button class="btn-primary w-full" @click="router.push({ name: 'login' })">{{ t('auth.login') }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.auth-screen {
  position: relative;
  display: flex;
  min-height: 100vh;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background: #0c0e14;
}
.auth-locale { position: absolute; top: 1.25rem; right: 1.25rem; }


</style>
