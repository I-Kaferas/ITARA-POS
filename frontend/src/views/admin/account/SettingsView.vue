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
  return 'http://127.0.0.1:8001/api/v1'
})

const hub = computed(() => [
  { id: 'company', icon: 'building', to: '/admin/organization/company', label: t('settings.domains.company'), hint: t('settings.companyHint') },
  { id: 'store', icon: 'stores', to: '/admin/organization/stores', label: t('settings.domains.store'), hint: t('settings.storeHint') },
  { id: 'users', icon: 'organization', to: '/admin/organization/users', label: t('org.tabs.users'), hint: t('org.assignStoresHint') },
  { id: 'pos', icon: 'device-pos', to: '/admin/organization/terminals', label: t('settings.domains.pos'), hint: t('settings.domains.posHint') },
  { id: 'taxes', icon: 'percent', to: '/admin/catalog/taxes', label: t('settings.domains.taxes'), hint: t('settings.domains.taxesHint') },
  { id: 'currency', icon: 'coins', to: '/admin/organization/currencies', label: t('settings.domains.currency'), hint: t('settings.domains.currencyHint') },
  { id: 'print', icon: 'receipt', to: '/admin/organization/company', label: t('settings.domains.print'), hint: t('settings.domains.printHint') },
  { id: 'stock', icon: 'inventory', to: '/admin/inventory/stock', label: t('settings.domains.stock'), hint: t('settings.domains.stockHint') },
  { id: 'sync', icon: 'refresh', to: '/admin/sync', label: t('settings.domains.sync'), hint: t('settings.domains.syncHint') },
  { id: 'restaurant', icon: 'restaurant', to: '/admin/hospitality', label: t('settings.domains.restaurant'), hint: t('settings.domains.restaurantHint') },
  { id: 'hotel', icon: 'bed', to: '/admin/hotel/settings', label: t('settings.domains.hotel'), hint: t('settings.domains.hotelHint') },
])

const credentials = computed(() => [
  { key: 'tenant', label: t('settings.tenantId'), value: tenantId.value, secret: false },
  { key: 'store', label: t('settings.storeId'), value: storeId.value, secret: false },
  { key: 'token', label: t('settings.accessToken'), value: accessToken.value, secret: true, empty: t('settings.noToken') },
  { key: 'refresh', label: t('settings.refreshToken'), value: refreshToken.value, secret: true },
  { key: 'api', label: t('settings.apiUrl'), value: apiUrl.value, secret: false },
])

const revealed = ref<Record<string, boolean>>({})

function displayValue(item: { key: string, value: string, secret: boolean, empty?: string }) {
  if (!item.value) return item.empty ?? '—'
  if (item.secret && !revealed.value[item.key]) return maskToken(item.value)
  return item.value
}

function toggleReveal(key: string) {
  revealed.value = { ...revealed.value, [key]: !revealed.value[key] }
}

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
  window.setTimeout(() => {
    if (message.value === t('settings.saved')) message.value = ''
  }, 3500)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('auth.settings') }}</template>
    <template #subtitle>{{ t('settings.subtitle') }}</template>

    <div class="settings">
      <div class="settings-top">
        <form class="set-card" @submit.prevent="save">
          <header class="set-card__head">
            <span class="set-card__icon"><AppIcon name="account" :size="18" /></span>
            <div>
              <h2>{{ t('settings.preferences') }}</h2>
              <p>{{ t('settings.preferencesHint') }}</p>
            </div>
          </header>

          <div class="set-row">
            <div class="set-row__label">
              <span class="set-row__icon"><AppIcon name="globe" :size="16" /></span>
              <div>
                <h3>{{ t('settings.language') }}</h3>
                <p>{{ t('settings.languageHint') }}</p>
              </div>
            </div>
            <div class="locale-list" role="radiogroup" :aria-label="t('settings.language')">
              <button
                v-for="code in SUPPORTED_LOCALES"
                :key="code"
                type="button"
                role="radio"
                class="locale-chip"
                :class="{ 'is-active': language === code }"
                :aria-checked="language === code"
                @click="language = code"
              >
                <span class="locale-chip__flag" aria-hidden="true"><LanguageFlag :locale="code" /></span>
                <span>{{ LOCALE_META[code].native }}</span>
              </button>
            </div>
          </div>

          <div class="set-row">
            <div class="set-row__label">
              <span class="set-row__icon"><AppIcon name="store-pin" :size="16" /></span>
              <div>
                <h3>{{ t('settings.store') }}</h3>
                <p>{{ t('settings.storeHint') }}</p>
              </div>
            </div>
            <select v-if="context.activeStores.length" v-model="storeId" class="field set-select">
              <option v-for="store in context.activeStores" :key="store.id" :value="store.id">
                {{ context.storeLabel(store) }}
              </option>
            </select>
            <p v-else class="set-empty">{{ t('settings.noStore') }}</p>
          </div>

          <div class="set-row">
            <div class="set-row__label">
              <span class="set-row__icon"><AppIcon name="menu" :size="16" /></span>
              <div>
                <h3>{{ t('settings.interface') }}</h3>
                <p>{{ t('settings.sidebarOpen') }}</p>
              </div>
            </div>
            <label class="switch">
              <input v-model="sidebarOpen" type="checkbox" :aria-label="t('settings.sidebarOpen')" />
              <span class="switch__track" aria-hidden="true"><span class="switch__thumb" /></span>
            </label>
          </div>

          <footer class="set-card__foot">
            <Transition name="fade">
              <p v-if="message" class="set-saved" role="status">
                <AppIcon name="check" :size="14" />
                {{ message }}
              </p>
            </Transition>
            <button type="submit" class="btn-primary gap-1.5">
              <AppIcon name="check" :size="15" />
              {{ t('profile.save') }}
            </button>
          </footer>
        </form>

        <section class="set-card">
          <header class="set-card__head">
            <span class="set-card__icon"><AppIcon name="device-pos" :size="18" /></span>
            <div>
              <h2>{{ t('settings.terminal') }}</h2>
              <p>{{ t('settings.terminalHint') }}</p>
            </div>
          </header>

          <ul class="creds">
            <li v-for="item in credentials" :key="item.key" class="cred">
              <span class="cred__label">{{ item.label }}</span>
              <code class="cred__value" :class="{ 'is-empty': !item.value }">{{ displayValue(item) }}</code>
              <div class="cred__actions">
                <button
                  v-if="item.secret"
                  type="button"
                  class="icon-btn"
                  :disabled="!item.value"
                  :title="revealed[item.key] ? t('settings.hide') : t('settings.show')"
                  :aria-label="revealed[item.key] ? t('settings.hide') : t('settings.show')"
                  @click="toggleReveal(item.key)"
                >
                  <AppIcon name="eye" :size="15" />
                </button>
                <button
                  type="button"
                  class="icon-btn"
                  :class="{ 'is-done': copiedKey === item.key }"
                  :disabled="!item.value"
                  :title="copiedKey === item.key ? t('settings.copied') : t('settings.copy')"
                  :aria-label="copiedKey === item.key ? t('settings.copied') : t('settings.copy')"
                  @click="copyValue(item.key, item.value)"
                >
                  <AppIcon v-if="copiedKey === item.key" name="check" :size="15" />
                  <svg v-else viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <rect x="9" y="9" width="11" height="11" rx="2" />
                    <path d="M5 15V6a2 2 0 0 1 2-2h9" />
                  </svg>
                </button>
              </div>
            </li>
          </ul>

          <p class="set-note">
            <AppIcon name="info" :size="15" />
            <span>{{ t('settings.terminalApiHint') }}</span>
          </p>
        </section>
      </div>

      <section class="set-card">
        <header class="set-card__head">
          <span class="set-card__icon"><AppIcon name="layers" :size="18" /></span>
          <div>
            <h2>{{ t('settings.hub') }}</h2>
            <p>{{ t('settings.hubHint') }}</p>
          </div>
        </header>
        <div class="hub">
          <RouterLink v-for="item in hub" :key="item.id" :to="item.to" class="hub-tile">
            <span class="hub-tile__icon"><AppIcon :name="item.icon" :size="18" /></span>
            <span class="hub-tile__text">
              <strong>{{ item.label }}</strong>
              <span>{{ item.hint }}</span>
            </span>
            <AppIcon name="chevron-right" :size="16" class="hub-tile__go" />
          </RouterLink>
        </div>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.settings {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  width: 100%;
  max-width: 82rem;
}

.settings-top {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr);
  gap: 1.25rem;
  align-items: start;
}

.set-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 1.25rem 1.35rem;
  border: 1px solid var(--color-border);
  border-radius: 1rem;
  background: var(--color-surface);
}

.set-card__head {
  display: flex;
  align-items: flex-start;
  gap: 0.85rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--color-border);
}

.set-card__icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 0.75rem;
  background: var(--color-brand-600);
  color: #fff;
}

.set-card__head h2 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.set-card__head p {
  margin: 0.2rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.82rem;
  line-height: 1.45;
}

.set-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.75rem 1.25rem;
  padding: 1.05rem 0;
  border-bottom: 1px solid var(--color-border);
}

.set-row__label {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  min-width: 0;
}

.set-row__icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 2rem;
  height: 2rem;
  border-radius: 0.6rem;
  background: var(--color-canvas);
  color: var(--color-text-secondary);
}

.set-row h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 0.9rem;
  font-weight: 650;
}

.set-row p {
  margin: 0.15rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.78rem;
  line-height: 1.4;
}

.locale-list {
  display: flex;
  gap: 0.4rem;
  padding: 0.25rem;
  border-radius: 0.8rem;
  background: var(--color-canvas);
}

.locale-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.45rem 0.75rem;
  border: 1px solid transparent;
  border-radius: 0.6rem;
  background: transparent;
  color: var(--color-text-secondary);
  font: inherit;
  font-size: 0.82rem;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
}

.locale-chip:hover {
  color: var(--color-text-primary);
}

.locale-chip.is-active {
  border-color: var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-primary);
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.08);
}

.locale-chip__flag {
  display: block;
  width: 1.35rem;
  height: 0.95rem;
  overflow: hidden;
  border-radius: 0.2rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
}

.set-select {
  width: min(18rem, 100%);
}

.set-empty {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 0.82rem;
}

.switch {
  position: relative;
  display: inline-flex;
  cursor: pointer;
}

.switch input {
  position: absolute;
  inset: 0;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.switch__track {
  display: flex;
  align-items: center;
  width: 2.75rem;
  height: 1.55rem;
  padding: 0.15rem;
  border-radius: 999px;
  background: var(--color-border);
  transition: background-color 160ms ease;
}

.switch__thumb {
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.25);
  transition: transform 160ms ease;
}

.switch input:checked + .switch__track {
  background: var(--color-brand-600);
}

.switch input:checked + .switch__track .switch__thumb {
  transform: translateX(1.2rem);
}

.switch input:focus-visible + .switch__track {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.set-card__foot {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  padding-top: 1rem;
}

.set-saved {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  margin: 0 auto 0 0;
  padding: 0.4rem 0.7rem;
  border-radius: 999px;
  background: var(--color-success-bg);
  color: var(--color-success);
  font-size: 0.8rem;
  font-weight: 600;
}

.creds {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}

.cred {
  display: grid;
  grid-template-columns: 8.5rem minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.8rem 0;
  border-bottom: 1px solid var(--color-border);
}

.cred__label {
  color: var(--color-text-muted);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.cred__value {
  min-width: 0;
  padding: 0.4rem 0.6rem;
  overflow: hidden;
  border-radius: 0.5rem;
  background: var(--color-canvas);
  color: var(--color-text-primary);
  font-size: 0.78rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cred__value.is-empty {
  color: var(--color-text-muted);
}

.cred__actions {
  display: flex;
  gap: 0.3rem;
}

.icon-btn {
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  border: 1px solid var(--color-border);
  border-radius: 0.55rem;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
}

.icon-btn:not(:disabled):hover {
  border-color: var(--color-brand-600);
  color: var(--color-text-primary);
}

.icon-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.icon-btn.is-done {
  border-color: var(--color-success);
  color: var(--color-success);
}

.set-note {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin: 1rem 0 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: var(--color-canvas);
  color: var(--color-text-secondary);
  font-size: 0.78rem;
  line-height: 1.45;
}

.set-note svg {
  flex-shrink: 0;
  margin-top: 1px;
}

.hub {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr));
  gap: 0.75rem;
  padding-top: 1rem;
}

.hub-tile {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  min-width: 0;
  padding: 0.85rem 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 0.85rem;
  background: var(--color-surface);
  color: var(--color-text-primary);
  text-decoration: none;
  transition: border-color 150ms ease, background-color 150ms ease;
}

.hub-tile:hover {
  border-color: var(--color-brand-600);
  background: var(--color-canvas);
}

.hub-tile__icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 2.4rem;
  height: 2.4rem;
  border-radius: 0.7rem;
  background: var(--color-accent-soft, var(--color-canvas));
  color: var(--color-accent, #e39b2b);
}

.hub-tile__text {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}

.hub-tile__text strong {
  font-size: 0.88rem;
  font-weight: 650;
}

.hub-tile__text span {
  overflow: hidden;
  color: var(--color-text-muted);
  font-size: 0.76rem;
  line-height: 1.35;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.hub-tile__go {
  flex-shrink: 0;
  color: var(--color-text-muted);
}

.hub-tile:hover .hub-tile__go {
  color: var(--color-text-primary);
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 200ms ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

html[data-theme="dark"] .set-card__icon {
  background: var(--color-accent, #e39b2b);
  color: #0f172a;
}

html[data-theme="dark"] .switch input:checked + .switch__track {
  background: var(--color-accent, #e39b2b);
}

@media (max-width: 1100px) {
  .settings-top {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (max-width: 640px) {
  .set-row {
    grid-template-columns: minmax(0, 1fr);
  }

  .locale-list {
    flex-wrap: wrap;
  }

  .set-select {
    width: 100%;
  }

  .cred {
    grid-template-columns: minmax(0, 1fr) auto;
  }

  .cred__label {
    grid-column: 1 / -1;
  }
}
</style>
