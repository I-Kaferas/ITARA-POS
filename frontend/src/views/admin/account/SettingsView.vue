<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import { LOCALE_META, SUPPORTED_LOCALES, persistLocale, type AppLocale } from '../../../i18n/locales'
import LanguageFlag from '../../../components/ui/LanguageFlag.vue'
import { useContextStore } from '../../../stores/context'

const { t, locale } = useI18n()
const context = useContextStore()

const language = ref<AppLocale>('fr')
const storeId = ref('')
const sidebarOpen = ref(true)
const message = ref('')

onMounted(async () => {
  language.value = (locale.value as AppLocale) in LOCALE_META ? locale.value as AppLocale : 'fr'
  sidebarOpen.value = localStorage.getItem('pos_sidebar_open') !== '0'
  if (!context.stores.length) await context.loadStores()
  storeId.value = context.currentStoreId ?? ''
})

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
  <AdminLayout>
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

        <section class="card">
          <h3>{{ t('settings.interface') }}</h3>
          <label class="check">
            <input v-model="sidebarOpen" type="checkbox" />
            <span>{{ t('settings.sidebarOpen') }}</span>
          </label>
        </section>

        <section class="card">
          <h3>{{ t('settings.shortcuts') }}</h3>
          <RouterLink to="/admin/organization/company" class="shortcut">
            <strong>{{ t('settings.company') }}</strong>
            <span>{{ t('settings.companyHint') }}</span>
          </RouterLink>
          <RouterLink to="/admin/account" class="shortcut">
            <strong>{{ t('settings.security') }}</strong>
            <span>{{ t('settings.securityHint') }}</span>
          </RouterLink>
          <RouterLink to="/admin/profile" class="shortcut">
            <strong>{{ t('auth.profile') }}</strong>
            <span>{{ t('settings.profileHint') }}</span>
          </RouterLink>
        </section>

        <div class="settings-actions">
          <button type="submit" class="btn-primary">{{ t('profile.save') }}</button>
        </div>
      </form>
    </div>
  </AdminLayout>
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
  box-shadow: inset 0 0 0 1px #4a6d86;
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
.shortcut:hover { border-color: #4a6d86; background: #f3f6f8; }
.shortcut span { color: #64748b; font-size: 0.75rem; }
.settings-actions { display: flex; justify-content: flex-end; }
@media (min-width: 860px) {
  .settings-grid { grid-template-columns: 1fr 1fr; }
  .settings-actions { grid-column: 1 / -1; }
}
</style>
