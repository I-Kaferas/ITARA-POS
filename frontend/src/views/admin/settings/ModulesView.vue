<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
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

const rows = computed(() => catalog.value.map(item => ({
  ...item,
  manifest: manifests.value.find(module => module.code === item.code) ?? null,
})))

function draftFor(code: string) {
  return drafts.value[code] ?? {}
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

    <p v-if="error" class="modules-note modules-note--error">{{ error }}</p>
    <p v-else-if="notice" class="modules-note">{{ notice }}</p>
    <p v-if="loading" class="modules-note">{{ t('common.loading') }}</p>

    <div v-else class="module-list">
      <article v-for="item in rows" :key="item.code" class="ui-card module-row">
        <div class="module-row__head">
          <span class="module-row__icon" aria-hidden="true">
            <AppIcon :name="item.icon" :size="18" />
          </span>
          <div class="min-w-0">
            <h2 class="module-row__title">{{ t(`modules.names.${item.code}`) }}</h2>
            <p class="module-row__text">{{ t(`modules.descriptions.${item.code}`) }}</p>
          </div>
          <button
            type="button"
            class="module-switch"
            :class="{ 'module-switch--on': item.enabled }"
            :aria-pressed="item.enabled"
            :disabled="busy === item.code"
            @click="toggle(item)"
          >
            {{ item.enabled ? t('modules.enabled') : t('modules.disabled') }}
          </button>
        </div>

        <form v-if="item.enabled && item.manifest" class="module-row__settings" @submit.prevent="save(item.code)">
          <h3>{{ t('modules.settings') }}</h3>
          <label v-for="field in item.manifest.settings" :key="field.key" class="module-field">
            <span>{{ t(`modules.fields.${field.key}`) }}</span>
            <input
              v-if="field.type === 'boolean'"
              type="checkbox"
              :checked="draftFor(item.code)[field.key] === true"
              @change="setField(item.code, field, ($event.target as HTMLInputElement).checked)"
            >
            <select
              v-else-if="field.options?.length"
              :value="String(draftFor(item.code)[field.key] ?? '')"
              @change="setField(item.code, field, ($event.target as HTMLSelectElement).value)"
            >
              <option v-for="option in field.options" :key="option" :value="option">{{ option }}</option>
            </select>
            <input
              v-else-if="field.type === 'integer'"
              type="number"
              min="1"
              max="3650"
              :value="Number(draftFor(item.code)[field.key] ?? 0)"
              @input="setField(item.code, field, Number(($event.target as HTMLInputElement).value))"
            >
            <input
              v-else
              type="text"
              :value="String(draftFor(item.code)[field.key] ?? '')"
              @input="setField(item.code, field, ($event.target as HTMLInputElement).value)"
            >
          </label>
          <div class="module-row__actions">
            <button type="submit" class="btn-primary" :disabled="busy === item.code">{{ t('modules.save') }}</button>
            <RouterLink v-if="item.manifest.navigation[0]" class="btn-secondary" :to="item.manifest.navigation[0].to">
              {{ t('modules.open') }}
            </RouterLink>
          </div>
        </form>
      </article>
    </div>
  </PageFrame>
</template>

<style scoped>
.modules-note {
  margin: 0 0 1rem;
  color: var(--color-text-secondary);
}
.modules-note--error {
  color: var(--color-danger, #b42318);
}
.module-list {
  display: grid;
  gap: 0.75rem;
}
.module-row__head,
.module-row__actions,
.module-field {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.module-row__head {
  padding: 1rem 1.1rem;
}
.module-row__icon {
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 0.7rem;
  background: var(--color-surface-muted, rgba(0, 0, 0, 0.04));
  flex: none;
}
.module-row__title {
  margin: 0;
  font-size: 1rem;
}
.module-row__text {
  margin: 0.15rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.875rem;
}
.module-switch {
  margin-left: auto;
  border: 1px solid var(--color-border, rgba(0, 0, 0, 0.12));
  background: transparent;
  color: var(--color-text-secondary);
  border-radius: 999px;
  padding: 0.35rem 0.8rem;
  cursor: pointer;
}
.module-switch--on {
  background: var(--color-brand-500, #0f766e);
  border-color: transparent;
  color: white;
}
.module-row__settings {
  display: grid;
  gap: 0.75rem;
  padding: 0 1.1rem 1rem;
}
.module-row__settings h3 {
  margin: 0;
  font-size: 0.85rem;
}
.module-field {
  justify-content: space-between;
}
.module-field span {
  color: var(--color-text-secondary);
}
.module-row__actions {
  justify-content: flex-start;
}
</style>
