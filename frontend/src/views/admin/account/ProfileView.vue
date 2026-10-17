<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useAuthStore } from '../../../stores/auth'
import { useContextStore } from '../../../stores/context'
import type { User, UserRoleAssignment } from '../../../types'
import { formatDate } from '../../../utils/format'

const { t } = useI18n()
const auth = useAuthStore()
const context = useContextStore()

const name = ref('')
const phone = ref('')
const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const message = ref('')
const error = ref('')
const savingIdentity = ref(false)
const savingPassword = ref(false)
const ready = ref(false)

const identityDirty = computed(() => {
  const user = auth.user
  if (!user) return false
  return name.value.trim() !== user.name || phone.value.trim() !== (user.phone ?? '')
})

const passwordReady = computed(() =>
  currentPassword.value.length > 0
  && newPassword.value.length >= 8
  && confirmPassword.value.length > 0,
)

const roleNames = computed(() => {
  const user = auth.user as (User & { role_assignments?: { name?: string; slug?: string }[] }) | null
  if (!user) return []
  if (user.role_assignments?.length) {
    return user.role_assignments.map(role => role.name || role.slug || '').filter(Boolean)
  }
  return (user.roles ?? []).map(role => typeof role === 'string' ? role : (role as UserRoleAssignment).name)
})

const storeNames = computed(() => {
  const ids = auth.user?.store_ids ?? []
  if (!ids.length) return []
  return ids.map(id => {
    const store = context.stores.find(item => item.id === id)
    return store ? context.storeLabel(store) : id
  })
})

function initials(value: string) {
  return value.trim().split(/\s+/).slice(0, 2).map(part => part[0]?.toUpperCase() ?? '').join('') || '?'
}

function fillForm(user: User) {
  name.value = user.name
  phone.value = user.phone ?? ''
}

onMounted(async () => {
  if (auth.user) fillForm(auth.user)
  await Promise.all([
    auth.fetchMe().catch(() => undefined),
    context.stores.length ? Promise.resolve() : context.loadStores(),
    auth.loadSessions().catch(() => undefined),
  ])
  if (auth.user) fillForm(auth.user)
  ready.value = true
})

async function saveIdentity() {
  if (!identityDirty.value || !name.value.trim()) return
  savingIdentity.value = true
  error.value = ''
  message.value = ''
  try {
    const saved = await auth.updateProfile({
      name: name.value.trim(),
      phone: phone.value.trim() || null,
    })
    fillForm(saved)
    message.value = t('profile.saved')
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('common.error'))
  } finally {
    savingIdentity.value = false
  }
}

async function savePassword() {
  error.value = ''
  message.value = ''
  if (newPassword.value !== confirmPassword.value) {
    error.value = t('profile.passwordMismatch')
    return
  }
  savingPassword.value = true
  try {
    const res = await auth.changePassword(currentPassword.value, newPassword.value, confirmPassword.value)
    currentPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''
    message.value = res.message || t('account.passwordChanged')
    await auth.loadSessions().catch(() => undefined)
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('common.error'))
  } finally {
    savingPassword.value = false
  }
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('auth.profile') }}</template>
    <template #subtitle>{{ t('profile.subtitle') }}</template>

    <p v-if="error" class="profile-note profile-note--error" role="alert">{{ error }}</p>
    <p v-else-if="message" class="profile-note" role="status">{{ message }}</p>

    <div v-if="!ready && !auth.user" class="profile-skeleton" aria-hidden="true">
      <span /><span />
    </div>

    <div v-else-if="auth.user" class="profile">
      <section class="ui-card profile-card">
        <header class="profile-hero">
          <span class="profile-avatar" aria-hidden="true">{{ initials(auth.user.name) }}</span>
          <div class="profile-hero__id">
            <h2>{{ auth.user.name }}</h2>
            <p>{{ auth.user.email }}</p>
          </div>
          <div class="profile-chips">
            <span class="profile-chip" :class="{ 'is-on': auth.user.email_verified }">
              {{ auth.user.email_verified ? t('profile.verified') : t('profile.unverified') }}
            </span>
            <span class="profile-chip" :class="{ 'is-on': auth.user.two_factor_enabled }">
              {{ auth.user.two_factor_enabled ? t('profile.twoFactorOn') : t('profile.twoFactorOff') }}
            </span>
          </div>
        </header>

        <form class="profile-form" @submit.prevent="saveIdentity">
          <h3>{{ t('profile.identity') }}</h3>
          <label class="profile-field" :class="{ 'is-changed': name.trim() !== auth.user.name }">
            <FieldLabel icon="account">{{ t('profile.name') }}</FieldLabel>
            <input v-model="name" class="field" required autocomplete="name" />
          </label>
          <label class="profile-field" :class="{ 'is-changed': phone.trim() !== (auth.user.phone ?? '') }">
            <FieldLabel icon="phone">{{ t('profile.phone') }}</FieldLabel>
            <input v-model="phone" class="field" autocomplete="tel" />
          </label>
          <label class="profile-field">
            <FieldLabel icon="mail">{{ t('auth.email') }}</FieldLabel>
            <input class="field" :value="auth.user.email" disabled />
            <small>{{ t('profile.emailHint') }}</small>
          </label>
          <button
            type="submit"
            class="profile-save"
            :class="{ 'is-dirty': identityDirty, 'is-busy': savingIdentity }"
            :disabled="savingIdentity || !identityDirty"
          >
            <AppIcon name="check" :size="15" />
            {{ savingIdentity ? t('common.saving') : t('profile.save') }}
          </button>
        </form>
      </section>

      <div class="profile-side">
        <section class="ui-card profile-card">
          <h3>{{ t('profile.roles') }}</h3>
          <div v-if="roleNames.length" class="profile-pills">
            <span v-for="role in roleNames" :key="role" class="profile-pill">{{ role }}</span>
          </div>
          <p v-else class="profile-muted">{{ t('profile.noRole') }}</p>

          <h3>{{ t('profile.stores') }}</h3>
          <ul v-if="storeNames.length" class="profile-list">
            <li v-for="store in storeNames" :key="store">{{ store }}</li>
          </ul>
          <p v-else class="profile-muted">{{ t('org.allStores') }}</p>
        </section>

        <section class="ui-card profile-card">
          <h3>{{ t('profile.security') }}</h3>
          <p class="profile-muted">{{ t('account.passwordHint') }}</p>
          <form class="profile-form" @submit.prevent="savePassword">
            <label class="profile-field" :class="{ 'is-changed': currentPassword.length > 0 }">
              <FieldLabel icon="lock">{{ t('profile.currentPassword') }}</FieldLabel>
              <input v-model="currentPassword" class="field" type="password" autocomplete="current-password" />
            </label>
            <label class="profile-field" :class="{ 'is-changed': newPassword.length > 0 }">
              <FieldLabel icon="lock">{{ t('profile.newPassword') }}</FieldLabel>
              <input v-model="newPassword" class="field" type="password" minlength="8" autocomplete="new-password" />
            </label>
            <label class="profile-field" :class="{ 'is-changed': confirmPassword.length > 0 }">
              <FieldLabel icon="lock">{{ t('profile.confirmPassword') }}</FieldLabel>
              <input v-model="confirmPassword" class="field" type="password" minlength="8" autocomplete="new-password" />
            </label>
            <button
              type="submit"
              class="profile-save"
              :class="{ 'is-dirty': passwordReady, 'is-busy': savingPassword }"
              :disabled="savingPassword || !passwordReady"
            >{{ savingPassword ? t('common.saving') : t('account.changePassword') }}</button>
          </form>
        </section>

        <section class="ui-card profile-card profile-sessions">
          <div class="profile-card__head">
            <h3>{{ t('account.sessions') }}</h3>
            <RouterLink to="/admin/account">{{ t('profile.openSecurity') }}</RouterLink>
          </div>
          <p v-if="!auth.sessions.length" class="profile-muted">{{ t('org.neverSeen') }}</p>
          <div v-for="session in auth.sessions" :key="session.id" class="profile-session">
            <span>
              {{ session.device_name || t('account.unknownDevice') }}
              <em v-if="session.is_current">{{ t('account.current') }}</em>
            </span>
            <small>{{ session.ip_address || '—' }} · {{ session.last_used_at ? formatDate(session.last_used_at) : '—' }}</small>
          </div>
        </section>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.profile-note {
  margin: 0 0 var(--space-4);
  border: 1px solid var(--color-border);
  border-left: 3px solid var(--color-brand-600);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  padding: var(--space-3) var(--space-4);
  font-size: var(--text-sm);
}
.profile-note--error { border-left-color: var(--color-danger, #b42318); color: var(--color-danger, #b42318); }
.profile-skeleton { display: grid; grid-template-columns: 1.2fr 0.8fr; gap: var(--space-4); }
.profile-skeleton span {
  display: block;
  height: 18rem;
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
}
.profile {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(18rem, 0.85fr);
  gap: var(--space-4);
  align-items: start;
}
.profile-side { display: grid; gap: var(--space-4); }
.profile-card { padding: var(--space-5); display: flex; flex-direction: column; gap: var(--space-3); }
.profile-card h3 {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.profile-card__head { display: flex; align-items: center; justify-content: space-between; gap: var(--space-3); }
.profile-card__head a { color: var(--color-ink-brand, var(--color-brand-600)); font-size: var(--text-sm); font-weight: 600; text-decoration: none; }
.profile-hero { display: flex; align-items: flex-start; gap: var(--space-3); flex-wrap: wrap; }
.profile-hero__id { flex: 1; min-width: 10rem; }
.profile-hero h2 { margin: 0; font-size: var(--text-xl); letter-spacing: -0.02em; }
.profile-hero p, .profile-muted { margin: 0.15rem 0 0; color: var(--color-text-muted); font-size: var(--text-sm); }
.profile-avatar {
  display: grid;
  place-items: center;
  width: 3rem;
  height: 3rem;
  border-radius: 999px;
  background: var(--color-sidebar);
  color: var(--color-sidebar-mark);
  font-weight: 700;
  flex: none;
}
.profile-chips { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.profile-chip, .profile-pill {
  border-radius: 999px;
  background: var(--color-canvas);
  border: 1px solid var(--color-border);
  color: var(--color-text-muted);
  padding: 0.15rem 0.55rem;
  font-size: 0.75rem;
  font-weight: 600;
}
.profile-chip.is-on {
  border-color: transparent;
  background: color-mix(in srgb, var(--color-brand-600) 12%, var(--color-surface));
  color: var(--color-brand-700, var(--color-brand-600));
}
.profile-pills, .profile-list { display: flex; flex-wrap: wrap; gap: 0.35rem; margin: 0; padding: 0; list-style: none; }
.profile-list { flex-direction: column; gap: 0.35rem; }
.profile-list li {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  padding: 0.45rem 0.7rem;
  font-size: var(--text-sm);
}
.profile-form { display: grid; gap: var(--space-3); }
.profile-field { display: grid; gap: 0.35rem; }
.profile-field small { color: var(--color-text-faint); font-size: 0.75rem; }
.profile-field.is-changed .field {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: color-mix(in srgb, var(--color-sidebar-mark, #e39b2b) 14%, var(--color-surface));
}
.profile-save {
  justify-self: start;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
  color: var(--color-text-faint);
  border-radius: var(--radius-md);
  min-height: var(--control-lg);
  padding: var(--btn-pad-y) var(--btn-pad-x);
  font-size: var(--text-sm);
  font-weight: 600;
  cursor: pointer;
}
.profile-save.is-dirty {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: var(--color-sidebar-mark, #e39b2b);
  color: var(--color-brand-800, #12243c);
}
.profile-save:disabled { opacity: 0.55; cursor: default; }
.profile-save.is-dirty:disabled { opacity: 1; }
.profile-sessions { max-height: 18rem; overflow: auto; }
.profile-session {
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding-top: var(--space-2);
  border-top: 1px solid var(--color-border);
  font-size: var(--text-sm);
}
.profile-session span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.profile-session em {
  margin-left: 0.4rem;
  font-style: normal;
  font-size: 0.68rem;
  font-weight: 700;
  color: var(--color-brand-700, var(--color-brand-600));
}
.profile-session small { color: var(--color-text-faint); }
@media (max-width: 960px) {
  .profile, .profile-skeleton { grid-template-columns: 1fr; }
}
</style>
