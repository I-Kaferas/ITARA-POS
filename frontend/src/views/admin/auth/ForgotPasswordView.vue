<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import LanguageSwitcher from '../../../components/ui/LanguageSwitcher.vue'
import { useAuthStore } from '../../../stores/auth'

const { t } = useI18n()
const router = useRouter()
const auth = useAuthStore()

const email = ref('')
const sent = ref(false)
const message = ref('')

async function submit() {
  try {
    const res = await auth.forgotPassword(email.value)
    message.value = res.message
    sent.value = true
  } catch (e) {
    message.value = e instanceof Error ? e.message : t('common.error')
  }
}
</script>

<template>
  <div class="auth-screen">
    <div class="auth-locale"><LanguageSwitcher tone="glass" /></div>
    <div class="w-full max-w-md rounded-2xl bg-white p-8 shadow-xl">
      <h1 class="mb-2 text-2xl font-bold text-slate-900">{{ t('auth.forgotTitle') }}</h1>
      <p class="mb-6 text-sm text-slate-500">{{ t('auth.forgotSubtitle') }}</p>

      <form v-if="!sent" class="space-y-4" @submit.prevent="submit">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('auth.email') }}</label>
          <input v-model="email" type="email" required class="field" />
        </div>
        <button type="submit" class="btn-primary w-full" :disabled="auth.loading">
          {{ auth.loading ? t('common.loading') : t('auth.sendReset') }}
        </button>
      </form>

      <p v-else class="rounded-lg bg-green-50 px-4 py-3 text-sm text-green-800">{{ message }}</p>

      <button class="mt-6 w-full text-sm text-brand-600 hover:text-brand-700" @click="router.push({ name: 'login' })">
        ← {{ t('auth.backToLogin') }}
      </button>
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
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.625rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.from-brand-900 { --tw-gradient-from: var(--color-brand-900); }
.to-brand-700 { --tw-gradient-to: var(--color-brand-700); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
