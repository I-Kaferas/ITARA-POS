<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
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

    <div class="modules-page">
      <p v-if="error" class="modules-note modules-note--error" role="alert">{{ error }}</p>
      <p v-else-if="notice" class="modules-note" role="status">{{ notice }}</p>

      <div v-if="loading" class="module-list" aria-hidden="true">
        <span class="module-skeleton" /><span class="module-skeleton" /><span class="module-skeleton" />
      </div>

      <template v-else>
        <div class="module-stats">
          <button type="button" class="module-kpi" :class="{ 'is-on': status === 'all' }" @click="status = 'all'">
            <span class="module-kpi__value"><CountUp :value="Number(catalog.length ?? 0)" /></span>
            <span class="module-kpi__label">{{ t('modules.title') }}</span>
          </button>
          <button type="button" class="module-kpi" :class="{ 'is-on': status === 'on' }" @click="status = status === 'on' ? 'all' : 'on'">
            <span class="module-kpi__value"><CountUp :value="Number(activeCount ?? 0)" /></span>
            <span class="module-kpi__label">{{ t('modules.activeCount') }}</span>
          </button>
          <button type="button" class="module-kpi" :class="{ 'is-on': status === 'off' }" @click="status = status === 'off' ? 'all' : 'off'">
            <span class="module-kpi__value"><CountUp :value="Number(inactiveCount ?? 0)" /></span>
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
          <article v-for="item in visibleRows" :key="item.code" class="module-card" :class="{ 'is-off': !item.enabled }">
            <header class="module-card__head">
              <span class="module-card__icon" :class="{ 'is-on': item.enabled }" aria-hidden="true">
                <AppIcon :name="item.icon" :size="18" />
              </span>
              <div class="module-card__copy">
                <h2>{{ t(`modules.names.${item.code}`) }}</h2>
                <p>{{ t(`modules.descriptions.${item.code}`) }}</p>
              </div>
              <div class="module-card__switch">
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
            </header>

            <form v-if="item.enabled && item.manifest" class="module-card__settings" @submit.prevent="save(item.code)">
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
              <div class="module-card__actions">
                <button
                  type="submit"
                  class="ui-btn ui-btn--sm"
                  :class="settingsDirty(item.code) ? 'ui-btn--primary' : 'ui-btn--secondary'"
                  :disabled="busy === item.code || !settingsDirty(item.code)"
                >{{ t('modules.save') }}</button>
                <RouterLink v-if="item.manifest.navigation[0]" class="ui-btn ui-btn--secondary ui-btn--sm" :to="item.manifest.navigation[0].to">
                  <AppIcon name="eye" :size="15" />
                  {{ t('modules.open') }}
                </RouterLink>
              </div>
            </form>
          </article>
        </div>
      </template>
    </div>
  </PageFrame>
</template>

<style scoped>
.modules-page {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  min-width: 0;
}
.modules-note {
  margin: 0;
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
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}
.module-kpi {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 0.2rem;
  width: 9.5rem;
  min-height: 4.4rem;
  padding: 0.75rem 0.95rem;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  text-align: left;
  cursor: pointer;
  font: inherit;
  color: inherit;
}
.module-kpi.is-on {
  border-color: var(--color-brand-600);
  background: var(--color-brand-50, #f4f7fb);
}
.module-kpi__value {
  font-size: 1.45rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.module-kpi__label {
  color: var(--color-text-muted);
  font-size: 0.78rem;
  font-weight: 600;
}
.module-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 28rem), 1fr));
  gap: 1rem;
  align-items: start;
}
.module-skeleton {
  display: block;
  height: 11rem;
  border-radius: 22px;
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
}
.module-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  border: 1px solid var(--color-border);
  border-radius: 22px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  overflow: hidden;
}
.module-card.is-off { opacity: 0.78; }
.module-card__head {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.85rem;
  padding: 1rem 1.05rem 0.9rem;
}
.module-card__icon {
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 12px;
  background: var(--color-canvas);
  color: var(--color-text-muted);
  border: 1px solid var(--color-border);
}
.module-card__icon.is-on {
  background: var(--color-brand-600);
  border-color: transparent;
  color: #fff;
}
.module-card__copy { min-width: 0; }
.module-card__copy h2 {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.module-card__copy p {
  margin: 0.2rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.84rem;
  line-height: 1.4;
}
.module-card__switch {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  color: var(--color-text-muted);
  font-size: 0.78rem;
  font-weight: 700;
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
.module-card__settings {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  margin: 0 0.85rem 0.9rem;
  padding: 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-canvas);
}
.module-card__settings h3 {
  margin: 0 0 0.15rem;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.module-field {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  min-height: 2.45rem;
  padding: 0.4rem 0.65rem;
  border: 1px solid transparent;
  border-radius: 12px;
  background: var(--color-surface);
}
.module-field.is-changed {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: color-mix(in srgb, var(--color-sidebar-mark, #e39b2b) 16%, var(--color-surface));
}
.module-field span {
  min-width: 0;
  color: var(--color-text-primary);
  font-size: 0.84rem;
  line-height: 1.35;
}
.module-field .field { width: min(11rem, 46%); flex: none; }
.module-card__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 0.35rem;
}
@media (max-width: 720px) {
  .module-kpi { flex: 1 1 8rem; }
  .module-list { grid-template-columns: 1fr; }
  .module-card__head { grid-template-columns: auto minmax(0, 1fr); }
  .module-card__switch { grid-column: 1 / -1; justify-content: flex-end; }
}
</style>
