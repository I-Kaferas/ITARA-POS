<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useAuthStore } from '../../../stores/auth'
import type { ModuleCatalogItem, ModuleManifest, ModuleSettingField } from '../../../modules/registry'

const { t } = useI18n()
const auth = useAuthStore()

const catalog = ref<ModuleCatalogItem[]>([])
const manifests = ref<ModuleManifest[]>([])
const drafts = ref<Record<string, Record<string, boolean | string | number>>>({})
const loading = ref(true)
const busy = ref<string | null>(null)
const error = ref('')
const notice = ref('')
const status = ref<'all' | 'on' | 'off'>('all')

const rows = computed(() => catalog.value.map(item => ({
  ...item,
  manifest: manifests.value.find(module => module.code === item.code) ?? null,
})))

const visibleRows = computed(() => rows.value.filter(item => {
  if (status.value === 'on') return item.enabled
  if (status.value === 'off') return !item.enabled
  return true
}))

const activeCount = computed(() => catalog.value.filter(item => item.enabled).length)
const inactiveCount = computed(() => catalog.value.length - activeCount.value)

function draftFor(code: string) {
  return drafts.value[code] ?? {}
}

function settingsDirty(code: string) {
  const module = manifests.value.find(item => item.code === code)
  if (!module) return false
  const draft = draftFor(code)
  return module.settings.some(field => draft[field.key] !== field.value)
}

function fieldDirty(code: string, field: ModuleSettingField) {
  return draftFor(code)[field.key] !== field.value
}

function applyManifests(list: ModuleManifest[]) {
  manifests.value = list
  const next: Record<string, Record<string, boolean | string | number>> = {}
  for (const module of list) {
    next[module.code] = Object.fromEntries(module.settings.map(field => [field.key, field.value]))
  }
  drafts.value = next
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const response = await api.get<{ data: ModuleManifest[]; catalog: ModuleCatalogItem[] }>('/modules')
    catalog.value = response.catalog
    applyManifests(response.data)
  } catch (cause) {
    error.value = extractApiErrorMessage(cause)
  } finally {
    loading.value = false
  }
}

async function toggle(item: ModuleCatalogItem) {
  if (busy.value) return
  busy.value = item.code
  error.value = ''
  notice.value = ''
  try {
    const response = await api.put<{ data: { catalog: ModuleCatalogItem[] } }>(`/modules/${item.code}`, {
      enabled: !item.enabled,
    })
    catalog.value = response.data.catalog
    await auth.fetchMe()
    const refreshed = await api.get<{ data: ModuleManifest[] }>('/modules')
    applyManifests(refreshed.data)
  } catch (cause) {
    error.value = extractApiErrorMessage(cause, t('modules.lastOne'))
  } finally {
    busy.value = null
  }
}

async function save(code: string) {
  busy.value = code
  error.value = ''
  notice.value = ''
  try {
    await api.put(`/modules/${code}/settings`, draftFor(code))
    const saved = draftFor(code)
    manifests.value = manifests.value.map(module => module.code === code
      ? { ...module, settings: module.settings.map(field => ({ ...field, value: saved[field.key] ?? field.value })) }
      : module)
    notice.value = t('modules.saved')
  } catch (cause) {
    error.value = extractApiErrorMessage(cause)
  } finally {
    busy.value = null
  }
}

function setField(code: string, field: ModuleSettingField, value: boolean | string | number) {
  drafts.value = {
    ...drafts.value,
    [code]: { ...draftFor(code), [field.key]: value },
  }
}

onMounted(load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('modules.title') }}</template>
    <template #subtitle>{{ t('modules.subtitle') }}</template>

    <p v-if="error" class="modules-note modules-note--error" role="alert">{{ error }}</p>
    <p v-else-if="notice" class="modules-note" role="status">{{ notice }}</p>

    <div v-if="loading" class="module-list" aria-hidden="true">
      <span class="module-skeleton" /><span class="module-skeleton" /><span class="module-skeleton" />
    </div>

    <template v-else>
      <div class="module-stats">
        <button type="button" class="kpi-card module-kpi" :class="{ 'is-on': status === 'all' }" @click="status = 'all'">
          <span class="module-kpi__value">{{ catalog.length }}</span>
          <span class="module-kpi__label">{{ t('modules.title') }}</span>
        </button>
        <button type="button" class="kpi-card module-kpi" :class="{ 'is-on': status === 'on' }" @click="status = status === 'on' ? 'all' : 'on'">
          <span class="module-kpi__value">{{ activeCount }}</span>
          <span class="module-kpi__label">{{ t('modules.activeCount') }}</span>
        </button>
        <button type="button" class="kpi-card module-kpi" :class="{ 'is-on': status === 'off' }" @click="status = status === 'off' ? 'all' : 'off'">
          <span class="module-kpi__value">{{ inactiveCount }}</span>
          <span class="module-kpi__label">{{ t('modules.inactiveCount') }}</span>
        </button>
      </div>

      <EmptyState
        v-if="!visibleRows.length"
        icon="layers"
        :title="t('common.noResults')"
        :description="t('modules.emptyFilter')"
      />

      <div v-else class="module-list">
        <article v-for="item in visibleRows" :key="item.code" class="ui-card module-row" :class="{ 'is-off': !item.enabled }">
          <div class="module-row__head">
            <span class="module-row__icon" :class="{ 'is-on': item.enabled }" aria-hidden="true">
              <AppIcon :name="item.icon" :size="18" />
            </span>
            <div class="min-w-0">
              <h2 class="module-row__title">{{ t(`modules.names.${item.code}`) }}</h2>
              <p class="module-row__text">{{ t(`modules.descriptions.${item.code}`) }}</p>
            </div>
            <div class="module-row__switch">
              <span>{{ item.enabled ? t('modules.enabled') : t('modules.disabled') }}</span>
              <button
                type="button"
                class="switch"
                :class="{ 'switch--on': item.enabled }"
                role="switch"
                :aria-checked="item.enabled"
                :aria-label="t(`modules.names.${item.code}`)"
                :disabled="busy === item.code"
                @click="toggle(item)"
              />
            </div>
          </div>

          <form v-if="item.enabled && item.manifest" class="module-row__settings" @submit.prevent="save(item.code)">
            <h3>{{ t('modules.settings') }}</h3>
            <label
              v-for="field in item.manifest.settings"
              :key="field.key"
              class="module-field"
              :class="{ 'is-changed': fieldDirty(item.code, field) }"
            >
              <span>{{ t(`modules.fields.${field.key}`) }}</span>
              <button
                v-if="field.type === 'boolean'"
                type="button"
                class="switch switch--sm"
                :class="{ 'switch--on': draftFor(item.code)[field.key] === true }"
                role="switch"
                :aria-checked="draftFor(item.code)[field.key] === true"
                :aria-label="t(`modules.fields.${field.key}`)"
                @click="setField(item.code, field, draftFor(item.code)[field.key] !== true)"
              />
              <select
                v-else-if="field.options?.length"
                class="field"
                :value="String(draftFor(item.code)[field.key] ?? '')"
                @change="setField(item.code, field, ($event.target as HTMLSelectElement).value)"
              >
                <option v-for="option in field.options" :key="option" :value="option">{{ option }}</option>
              </select>
              <input
                v-else-if="field.type === 'integer'"
                class="field"
                type="number"
                min="1"
                max="3650"
                :value="Number(draftFor(item.code)[field.key] ?? 0)"
                @input="setField(item.code, field, Number(($event.target as HTMLInputElement).value))"
              >
              <input
                v-else
                class="field"
                type="text"
                :value="String(draftFor(item.code)[field.key] ?? '')"
                @input="setField(item.code, field, ($event.target as HTMLInputElement).value)"
              >
            </label>
            <div class="module-row__actions">
              <button
                type="submit"
                class="module-save"
                :class="{ 'is-dirty': settingsDirty(item.code), 'is-busy': busy === item.code }"
                :disabled="busy === item.code || !settingsDirty(item.code)"
              >{{ t('modules.save') }}</button>
              <RouterLink v-if="item.manifest.navigation[0]" class="btn-secondary" :to="item.manifest.navigation[0].to">
                <AppIcon name="eye" :size="16" />
                {{ t('modules.open') }}
              </RouterLink>
            </div>
          </form>
        </article>
      </div>
    </template>
  </PageFrame>
</template>

<style scoped>
.modules-note {
  margin: 0 0 var(--space-4);
  border: 1px solid var(--color-border);
  border-left: 3px solid var(--color-brand-600);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-primary);
  padding: var(--space-3) var(--space-4);
  font-size: var(--text-sm);
}
.modules-note--error {
  border-left-color: var(--color-danger, #b42318);
  color: var(--color-danger, #b42318);
}
.module-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-3);
  margin-bottom: var(--space-4);
}
.module-kpi {
  width: 100%;
  text-align: left;
  cursor: pointer;
  font: inherit;
  color: inherit;
}
.module-kpi.is-on {
  --kpi-accent: var(--color-sidebar-mark, #e39b2b);
  border-color: var(--color-brand-600);
}
.module-kpi__value {
  font-family: var(--font-display);
  font-size: var(--text-2xl);
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.module-kpi__label { color: var(--color-text-muted); font-size: var(--text-sm); }
.module-list { display: grid; gap: var(--space-3); }
.module-skeleton {
  display: block;
  height: 7.5rem;
  border-radius: var(--radius-lg);
  background: linear-gradient(90deg, var(--color-canvas), var(--color-surface), var(--color-canvas));
  background-size: 200% 100%;
  animation: module-shimmer 1.2s ease-in-out infinite;
}
@keyframes module-shimmer {
  from { background-position: 100% 0; }
  to { background-position: -100% 0; }
}
.module-row.is-off { opacity: 0.72; }
.module-row__head,
.module-row__actions,
.module-field {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}
.module-row__head { padding: var(--space-4) var(--space-5); }
.module-row__icon {
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  color: var(--color-text-muted);
  border: 1px solid var(--color-border);
  flex: none;
}
.module-row__icon.is-on {
  background: var(--color-brand-600);
  border-color: transparent;
  color: #fff;
}
.module-row__title { margin: 0; font-size: var(--text-md); letter-spacing: -0.02em; }
.module-row__text { margin: 0.15rem 0 0; color: var(--color-text-muted); font-size: var(--text-sm); }
.module-row__switch {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: var(--space-3);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 600;
  flex: none;
}
.switch {
  position: relative;
  width: 2.75rem;
  height: 1.55rem;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: var(--color-border-strong);
  cursor: pointer;
  flex: none;
}
.switch::after {
  content: "";
  position: absolute;
  top: 0.18rem;
  left: 0.18rem;
  width: 1.18rem;
  height: 1.18rem;
  border-radius: 999px;
  background: #fff;
  transition: transform var(--motion-fast) var(--ease-out);
}
.switch--on { background: var(--color-brand-600); }
.switch--on::after { transform: translateX(1.18rem); }
.switch:disabled { opacity: 0.5; cursor: default; }
.switch--sm { width: 2.4rem; height: 1.35rem; }
.switch--sm::after { width: 1rem; height: 1rem; }
.switch--sm.switch--on::after { transform: translateX(1.02rem); }
.module-row__settings {
  display: grid;
  gap: var(--space-2);
  margin: 0 var(--space-5) var(--space-4);
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-canvas);
}
.module-row__settings h3 {
  margin: 0 0 var(--space-1);
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.module-field {
  justify-content: space-between;
  min-height: 2.5rem;
  padding: 0.35rem 0.65rem;
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  background: var(--color-surface);
}
.module-field.is-changed {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: color-mix(in srgb, var(--color-sidebar-mark, #e39b2b) 16%, var(--color-surface));
}
.module-field span { color: var(--color-text-primary); font-size: var(--text-sm); }
.module-field .field { width: min(14rem, 46%); }
.module-row__actions { justify-content: flex-start; margin-top: var(--space-2); }
.module-save {
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-faint);
  border-radius: var(--radius-md);
  min-height: var(--control-lg);
  padding: var(--btn-pad-y) var(--btn-pad-x);
  font-size: var(--text-sm);
  font-weight: 600;
  cursor: pointer;
}
.module-save.is-dirty {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: var(--color-sidebar-mark, #e39b2b);
  color: var(--color-brand-800, #12243c);
}
.module-save:disabled { opacity: 0.55; cursor: default; }
.module-save.is-dirty:disabled { opacity: 1; }
@media (max-width: 800px) {
  .module-stats { grid-template-columns: 1fr; }
  .module-row__head { align-items: flex-start; }
}
</style>
