<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import { LOCALE_META, SUPPORTED_LOCALES, persistLocale, type AppLocale } from '../../../i18n/locales'
import LanguageFlag from '../../../components/ui/LanguageFlag.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { getRefreshToken, getTenantId, getToken } from '../../../api/client'
import { useContextStore } from '../../../stores/context'

const { t, locale } = useI18n()
const context = useContextStore()

const language = ref<AppLocale>('fr')
const storeId = ref('')
const sidebarOpen = ref(true)
const message = ref('')
const showToken = ref(false)
const showRefreshToken = ref(false)
const copiedKey = ref('')
const accessToken = ref(getToken() ?? '')
const refreshToken = ref(getRefreshToken() ?? '')
const tenantId = ref(getTenantId() ?? '')

/** Direct Laravel URL for Windows/mobile terminals (not the Vite proxy). */
const apiUrl = computed(() => {
  const terminal = String(import.meta.env.VITE_TERMINAL_API_URL || '').trim()
  if (terminal) return terminal.replace(/\/$/, '')
  const base = import.meta.env.VITE_API_BASE_URL ?? '/api/v1'
  if (/^https?:\/\//i.test(base)) return String(base).replace(/\/$/, '')
  return 'http://127.0.0.1:8000/api/v1'
})

const hub = computed(() => [
  { to: '/admin/organization/company', label: t('settings.domains.company'), hint: t('settings.companyHint') },
  { to: '/admin/organization/stores', label: t('settings.domains.store'), hint: t('settings.storeHint') },
  { to: '/admin/organization/terminals', label: t('settings.domains.pos'), hint: t('settings.domains.posHint') },
  { to: '/admin/catalog/taxes', label: t('settings.domains.taxes'), hint: t('settings.domains.taxesHint') },
  { to: '/admin/organization/currencies', label: t('settings.domains.currency'), hint: t('settings.domains.currencyHint') },
  { to: '/admin/organization/company', label: t('settings.domains.print'), hint: t('settings.domains.printHint') },
  { to: '/admin/inventory/stock', label: t('settings.domains.stock'), hint: t('settings.domains.stockHint') },
  { to: '/admin/sync', label: t('settings.domains.sync'), hint: t('settings.domains.syncHint') },
  { to: '/admin/hospitality', label: t('settings.domains.restaurant'), hint: t('settings.domains.restaurantHint') },
  { to: '/admin/hotel/settings', label: t('settings.domains.hotel'), hint: t('settings.domains.hotelHint') },
])

onMounted(async () => {
  language.value = (locale.value as AppLocale) in LOCALE_META ? locale.value as AppLocale : 'fr'
  sidebarOpen.value = localStorage.getItem('pos_sidebar_open') !== '0'
  if (!context.stores.length) await context.loadStores()
  storeId.value = context.currentStoreId ?? ''
  accessToken.value = getToken() ?? ''
  refreshToken.value = getRefreshToken() ?? ''
  tenantId.value = getTenantId() ?? ''
})

function maskToken(value: string) {
  if (value.length <= 12) return '••••••••'
  return `${value.slice(0, 6)}…${value.slice(-4)}`
}

async function copyValue(key: string, value: string) {
  if (!value) return
  try {
    await navigator.clipboard.writeText(value)
    copiedKey.value = key
    window.setTimeout(() => {
      if (copiedKey.value === key) copiedKey.value = ''
    }, 1800)
  } catch {
    // Clipboard may be blocked; user can still select the value.
  }
}

function save() {
  locale.value = language.value
  persistLocale(language.value)
  context.selectStore(storeId.value || null)
  localStorage.setItem('pos_sidebar_open', sidebarOpen.value ? '1' : '0')
  window.dispatchEvent(new CustomEvent('pos-sidebar-pref', { detail: sidebarOpen.value }))
  message.value = t('settings.saved')
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('auth.settings') }}</template>
    <template #subtitle>{{ t('settings.subtitle') }}</template>

    <div class="settings">
      <p v-if="message" class="banner">{{ message }}</p>

      <form class="settings-grid" @submit.prevent="save">
        <section class="card">
          <h3>{{ t('settings.language') }}</h3>
          <p class="hint">{{ t('settings.languageHint') }}</p>
          <div class="locale-list">
            <button
              v-for="code in SUPPORTED_LOCALES"
              :key="code"
              type="button"
              class="locale-card"
              :class="{ 'locale-card--active': language === code }"
              @click="language = code"
            >
              <span class="locale-card__flag" aria-hidden="true">
                <LanguageFlag :locale="code" />
              </span>
              <strong>{{ LOCALE_META[code].native }}</strong>
            </button>
          </div>
        </section>

        <section class="card">
          <h3>{{ t('settings.store') }}</h3>
          <p class="hint">{{ t('settings.storeHint') }}</p>
          <select v-if="context.activeStores.length" v-model="storeId" class="field">
            <option v-for="store in context.activeStores" :key="store.id" :value="store.id">
              {{ context.storeLabel(store) }}
            </option>
          </select>
          <p v-else class="hint">{{ t('settings.noStore') }}</p>
        </section>

        <section class="card terminal-card">
          <h3>{{ t('settings.terminal') }}</h3>
          <p class="hint">{{ t('settings.terminalHint') }}</p>

          <div class="cred">
            <span class="cred__label">{{ t('settings.tenantId') }}</span>
            <code class="cred__value">{{ tenantId || '—' }}</code>
            <button type="button" class="cred__btn" :disabled="!tenantId" @click="copyValue('tenant', tenantId)">
              {{ copiedKey === 'tenant' ? t('settings.copied') : t('settings.copy') }}
            </button>
          </div>

          <div class="cred">
            <span class="cred__label">{{ t('settings.storeId') }}</span>
            <code class="cred__value">{{ storeId || '—' }}</code>
            <button type="button" class="cred__btn" :disabled="!storeId" @click="copyValue('store', storeId)">
              {{ copiedKey === 'store' ? t('settings.copied') : t('settings.copy') }}
            </button>
          </div>

          <div class="cred">
            <span class="cred__label">{{ t('settings.accessToken') }}</span>
            <code class="cred__value">
              <template v-if="accessToken">{{ showToken ? accessToken : maskToken(accessToken) }}</template>
              <template v-else>{{ t('settings.noToken') }}</template>
            </code>
            <button type="button" class="cred__btn" :disabled="!accessToken" @click="showToken = !showToken">
              {{ showToken ? t('settings.hide') : t('settings.show') }}
            </button>
            <button type="button" class="cred__btn" :disabled="!accessToken" @click="copyValue('token', accessToken)">
              {{ copiedKey === 'token' ? t('settings.copied') : t('settings.copy') }}
            </button>
          </div>

          <div class="cred">
            <span class="cred__label">{{ t('settings.refreshToken') }}</span>
            <code class="cred__value">
              <template v-if="refreshToken">{{ showRefreshToken ? refreshToken : maskToken(refreshToken) }}</template>
              <template v-else>—</template>
            </code>
            <button type="button" class="cred__btn" :disabled="!refreshToken" @click="showRefreshToken = !showRefreshToken">
              {{ showRefreshToken ? t('settings.hide') : t('settings.show') }}
            </button>
            <button type="button" class="cred__btn" :disabled="!refreshToken" @click="copyValue('refresh', refreshToken)">
              {{ copiedKey === 'refresh' ? t('settings.copied') : t('settings.copy') }}
            </button>
          </div>

          <div class="cred">
            <span class="cred__label">{{ t('settings.apiUrl') }}</span>
            <code class="cred__value">{{ apiUrl }}</code>
            <button type="button" class="cred__btn" @click="copyValue('api', apiUrl)">
              {{ copiedKey === 'api' ? t('settings.copied') : t('settings.copy') }}
            </button>
          </div>
          <p class="hint">{{ t('settings.terminalApiHint') }}</p>
        </section>

        <section class="card">
          <h3>{{ t('settings.interface') }}</h3>
          <label class="check">
            <span class="field-icon"><AppIcon name="check" :size="14" /></span>
            <input v-model="sidebarOpen" type="checkbox" />
            <span>{{ t('settings.sidebarOpen') }}</span>
          </label>
        </section>

        <section class="card hub">
          <h3>{{ t('settings.hub') }}</h3>
          <RouterLink v-for="item in hub" :key="item.to" :to="item.to" class="shortcut">
            <strong>{{ item.label }}</strong>
            <span>{{ item.hint }}</span>
          </RouterLink>
        </section>

        <div class="settings-actions">
          <button type="submit" class="btn-primary gap-1.5">
            <AppIcon name="check" :size="15" />
            {{ t('profile.save') }}
          </button>
        </div>
      </form>
    </div>
  </PageFrame>
</template>

<style scoped>
.settings { display: flex; flex-direction: column; gap: 1rem; max-width: 52rem; }
.banner { margin: 0; border-radius: 0.75rem; background: #ecfdf5; color: #047857; padding: 0.7rem 0.9rem; font-size: 0.85rem; }
.settings-grid { display: grid; gap: 1rem; }
.card {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  padding: 1.1rem 1.15rem;
  border: 1px solid #e4e8ec;
  border-radius: 1rem;
  background: #fff;
}
.card h3 { margin: 0; color: #1c2830; font-size: 0.95rem; }
.hint { margin: 0; color: #94a3b8; font-size: 0.75rem; }
.locale-list { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.5rem; }
.locale-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.4rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.8rem;
  background: #f7f9fb;
  padding: 0.7rem 0.75rem;
  color: #1c2830;
  text-align: left;
  cursor: pointer;
}
.locale-card__flag {
  display: block;
  width: 1.7rem;
  height: 1.15rem;
  overflow: hidden;
  border-radius: 0.22rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
}
.locale-card--active {
  border-color: #e39b2b;
  background: #f8efdc;
  box-shadow: inset 0 0 0 1px var(--color-brand-600);
}
.check { display: flex; align-items: center; gap: 0.55rem; color: #1c2830; font-size: 0.86rem; font-weight: 600; }
.shortcut {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.75rem;
  padding: 0.7rem 0.8rem;
  color: #1c2830;
  text-decoration: none;
}
.shortcut:hover { border-color: var(--color-brand-600); background: #f3f6f8; }
.shortcut span { color: #64748b; font-size: 0.75rem; }
.hub { display: flex; flex-direction: column; gap: 0.5rem; grid-column: 1 / -1; }
.terminal-card { grid-column: 1 / -1; }
.cred {
  display: grid;
  grid-template-columns: 7.5rem minmax(0, 1fr) auto auto;
  gap: 0.45rem 0.55rem;
  align-items: center;
  padding: 0.55rem 0.65rem;
  border: 1px solid #e8edf2;
  border-radius: 0.75rem;
  background: #f8fafc;
}
.cred__label {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #64748b;
}
.cred__value {
  margin: 0;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.78rem;
  color: #0f172a;
}
.cred__btn {
  border: 1px solid #dbe3ea;
  border-radius: 0.55rem;
  background: #fff;
  color: #334155;
  font-size: 0.72rem;
  font-weight: 650;
  padding: 0.28rem 0.55rem;
  cursor: pointer;
}
.cred__btn:disabled { opacity: 0.45; cursor: not-allowed; }
.cred__btn:not(:disabled):hover { border-color: var(--color-brand-600); color: #1c2830; }
.settings-actions { display: flex; justify-content: flex-end; }
@media (min-width: 860px) {
  .settings-grid { grid-template-columns: 1fr 1fr; }
  .settings-actions { grid-column: 1 / -1; }
}
@media (max-width: 720px) {
  .cred {
    grid-template-columns: 1fr auto auto;
  }
  .cred__label { grid-column: 1 / -1; }
  .cred__value { grid-column: 1 / -1; white-space: normal; word-break: break-all; }
}
</style>
