<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import type { Catalog, ImportResult } from '../../types'

const { t } = useI18n()
const store = useBackofficeStore()

const catalogs = ref<Catalog[]>([])
const catalogId = ref('')
const updateExisting = ref(true)
const file = ref<File | null>(null)
const result = ref<ImportResult | null>(null)
const saving = ref(false)

onMounted(async () => {
  await store.loadCompanies()
  const all: Catalog[] = []
  for (const company of store.companies) {
    all.push(...(await store.loadCatalogs(company.id)))
  }
  catalogs.value = all
  catalogId.value = all[0]?.id ?? ''
})

function onFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  file.value = input.files?.[0] ?? null
}

async function importFile() {
  if (!catalogId.value || !file.value) return
  saving.value = true
  try {
    result.value = await store.importProducts(catalogId.value, file.value, updateExisting.value)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.importExport') }}</template>
    <template #subtitle>{{ t('importExport.subtitle') }}</template>

    <div class="grid gap-6 lg:grid-cols-2">
      <div class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h3 class="mb-4 text-base font-semibold">{{ t('importExport.exportTitle') }}</h3>
        <p class="mb-4 text-sm text-slate-600">{{ t('importExport.exportHint') }}</p>
        <div class="mb-4">
          <label class="mb-1 block text-sm font-medium">{{ t('nav.catalogs') }}</label>
          <select v-model="catalogId" class="field w-full">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="c in catalogs" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <div class="flex flex-wrap gap-2">
          <button class="btn-primary" @click="store.exportProducts(catalogId || undefined)">{{ t('importExport.exportCsv') }}</button>
          <button class="btn-secondary" @click="store.downloadProductTemplate()">{{ t('importExport.template') }}</button>
        </div>
      </div>

      <div class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h3 class="mb-4 text-base font-semibold">{{ t('importExport.importTitle') }}</h3>
        <p class="mb-4 text-sm text-slate-600">{{ t('importExport.importHint') }}</p>
        <div class="mb-4 space-y-3">
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('nav.catalogs') }}</label>
            <select v-model="catalogId" required class="field w-full">
              <option v-for="c in catalogs" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">CSV</label>
            <input type="file" accept=".csv,text/csv" class="field w-full" @change="onFileChange" />
          </div>
          <label class="flex items-center gap-2 text-sm">
            <input v-model="updateExisting" type="checkbox" class="rounded" />
            {{ t('importExport.updateExisting') }}
          </label>
        </div>
        <button class="btn-primary" :disabled="saving || !file || !catalogId" @click="importFile">
          {{ t('importExport.importCsv') }}
        </button>

        <div v-if="result" class="mt-4 rounded-lg bg-slate-50 p-4 text-sm">
          <p>{{ t('importExport.created') }}: <strong>{{ result.created }}</strong></p>
          <p>{{ t('importExport.updated') }}: <strong>{{ result.updated }}</strong></p>
          <p>{{ t('importExport.skipped') }}: <strong>{{ result.skipped }}</strong></p>
          <ul v-if="result.errors.length" class="mt-2 list-disc pl-5 text-red-600">
            <li v-for="(err, i) in result.errors" :key="i">{{ err }}</li>
          </ul>
        </div>
      </div>
    </div>
  </AdminLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
</style>
