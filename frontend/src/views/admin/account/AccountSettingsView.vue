<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import { useAuthStore } from '../../../stores/auth'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const auth = useAuthStore()

const emailVerified = ref(true)
const twoFactorSecret = ref('')
const twoFactorQr = ref('')
const confirmCode = ref('')
const disablePassword = ref('')
const message = ref('')
const loading = ref(false)

onMounted(async () => {
  await auth.loadSessions()
  await auth.loadTwoFactorStatus()
  const status = await auth.emailVerificationStatus()
  emailVerified.value = status.email_verified
})

async function resendEmail() {
  const res = await auth.resendEmailVerification()
  message.value = res.message
}

async function startTwoFactor() {
  loading.value = true
  try {
    const setup = await auth.setupTwoFactor()
    twoFactorSecret.value = setup.secret
    twoFactorQr.value = setup.qr_code_url
  } finally {
    loading.value = false
  }
}

async function confirmTwoFactor() {
  loading.value = true
  try {
    await auth.confirmTwoFactor(confirmCode.value)
    message.value = t('account.twoFactorEnabled')
    twoFactorSecret.value = ''
    confirmCode.value = ''
  } finally {
    loading.value = false
  }
}

async function disableTwoFactor() {
  loading.value = true
  try {
    await auth.disableTwoFactor(disablePassword.value)
    message.value = t('account.twoFactorDisabled')
    disablePassword.value = ''
  } finally {
    loading.value = false
  }
}

async function revokeSession(id: string) {
  await auth.revokeSession(id)
}

async function revokeOthers() {
  await auth.revokeOtherSessions()
}

async function logoutAll() {
  if (!(await confirmDialog(t('account.confirmLogoutAll'), { danger: true, confirmLabel: t('account.logoutAll') }))) return
  await auth.logoutAll()
  window.location.href = '/login'
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('account.title') }}</template>

    <p v-if="message" class="mb-6 rounded-lg bg-green-50 px-4 py-3 text-sm text-green-800">{{ message }}</p>

    <div class="grid gap-6 lg:grid-cols-2">
      <!-- Email -->
      <section class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h2 class="mb-4 font-semibold">{{ t('account.email') }}</h2>
        <p class="mb-4 text-sm text-slate-600">
          {{ emailVerified ? t('account.emailVerified') : t('account.emailNotVerified') }}
        </p>
        <button v-if="!emailVerified" class="btn-secondary" @click="resendEmail">{{ t('account.resendEmail') }}</button>
      </section>

      <!-- 2FA -->
      <section class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h2 class="mb-4 font-semibold">{{ t('account.twoFactor') }}</h2>
        <p class="mb-4 text-sm text-slate-600">
          {{ auth.twoFactorStatus?.enabled ? t('account.twoFactorOn') : t('account.twoFactorOff') }}
        </p>

        <template v-if="!auth.twoFactorStatus?.enabled">
          <button v-if="!twoFactorSecret" class="btn-primary" :disabled="loading" @click="startTwoFactor">
            {{ t('account.enable2fa') }}
          </button>
          <div v-else class="space-y-3">
            <p class="text-xs font-mono break-all">{{ twoFactorSecret }}</p>
            <a :href="twoFactorQr" class="text-sm text-brand-600" target="_blank">{{ t('account.openAuthenticator') }}</a>
            <input v-model="confirmCode" class="field" :placeholder="t('account.enterCode')" maxlength="6" />
            <button class="btn-primary" :disabled="loading" @click="confirmTwoFactor">{{ t('account.confirm2fa') }}</button>
          </div>
        </template>

        <div v-else class="space-y-3">
          <input v-model="disablePassword" type="password" class="field" :placeholder="t('auth.password')" />
          <button class="btn-danger" :disabled="loading" @click="disableTwoFactor">{{ t('account.disable2fa') }}</button>
        </div>

        <div v-if="auth.recoveryCodes?.length" class="mt-4 rounded-lg bg-amber-50 p-4">
          <p class="mb-2 text-sm font-medium text-amber-900">{{ t('account.recoveryCodes') }}</p>
          <ul class="font-mono text-xs text-amber-800">
            <li v-for="code in auth.recoveryCodes" :key="code">{{ code }}</li>
          </ul>
        </div>
      </section>

      <!-- Sessions -->
      <section class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 lg:col-span-2">
        <div class="mb-4 flex items-center justify-between">
          <h2 class="font-semibold">{{ t('account.sessions') }}</h2>
          <div class="flex gap-2">
            <button class="btn-secondary text-sm" @click="revokeOthers">{{ t('account.revokeOthers') }}</button>
            <button class="btn-danger text-sm" @click="logoutAll">{{ t('account.logoutAll') }}</button>
          </div>
        </div>
        <div class="space-y-2">
          <div
            v-for="session in auth.sessions"
            :key="session.id"
            class="flex items-center justify-between rounded-lg border border-slate-200 px-4 py-3 text-sm"
          >
            <div>
              <p class="font-medium">{{ session.device_name || t('account.unknownDevice') }}</p>
              <p class="text-xs text-slate-500">{{ session.ip_address }} — {{ session.last_used_at }}</p>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="session.is_current" class="rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-700">{{ t('account.current') }}</span>
              <button v-else class="text-red-600 hover:text-red-700" @click="revokeSession(session.id)">{{ t('common.delete') }}</button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; font-weight: 500; }
.btn-danger { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: #dc2626; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
