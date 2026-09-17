<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage, getStoreId } from '../../api/client'
import PageFrame from '../../components/layout/PageFrame.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'

type Hit = { id?: string; barcode: string; type?: string; product_id?: string; label?: string }
const { t } = useI18n()
const code = ref('')
const query = ref('')
const type = ref('internal')
const lookup = ref<Record<string, any> | null>(null)
const results = ref<Hit[]>([])
const catalog = ref<Hit[]>([])
const generated = ref('')
const error = ref('')

onMounted(loadCatalog)
watchLiveSearch(code, find)
watchLiveSearch(query, search)

async function loadCatalog() {
  const storeId = getStoreId()
  if (!storeId) return
  catalog.value = (await api.get<{ data: Hit[] }>(`/stores/${storeId}/barcodes`)).data
}

async function find() {
  error.value = ''
  lookup.value = null
  if (!code.value.trim()) return
  try {
    const res = await api.get<{ found: boolean; data: Record<string, any> | null }>(`/barcodes/lookup?code=${encodeURIComponent(code.value)}`)
    lookup.value = res.data
  } catch (err) {
    error.value = extractApiErrorMessage(err, t('desk.notFound'))
  }
}

async function search() {
  error.value = ''
  if (!query.value.trim()) {
    results.value = []
    return
  }
  results.value = (await api.get<{ data: Hit[] }>(`/barcodes/search?q=${encodeURIComponent(query.value)}`)).data
}

async function generate() {
  const data = (await api.post<{ data: { barcode: string } }>('/barcodes/generate', { type: type.value })).data
  generated.value = data.barcode
}

function printCode(value: string, label = '') {
  const win = window.open('', '_blank', 'noopener,width=420,height=280')
  if (!win) return
  win.document.write(`<title>${label || value}</title><body style="font-family:sans-serif;text-align:center;padding:24px"><p>${label}</p><p style="font:700 28px/1.2 monospace;letter-spacing:.12em">${value}</p></body>`)
  win.document.close()
  win.focus()
  win.print()
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('desk.barcodes') }}</template>
    <template #subtitle>{{ t('desk.barcodesHint') }}</template>

    <div class="grid gap-4 lg:grid-cols-2">
      <section class="rounded-2xl border border-slate-200 bg-white p-4">
        <h3 class="mt-0">{{ t('desk.lookup') }}</h3>
        <div class="flex gap-2">
          <input v-model="code" type="search" class="field" :placeholder="t('desk.scan')" />
        </div>
        <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
        <div v-if="lookup" class="mt-3 rounded-xl bg-slate-50 p-3 text-sm">
          <strong>{{ lookup.product?.name || lookup.variant?.name || lookup.barcode?.barcode }}</strong>
          <p class="m-0 font-mono">{{ lookup.barcode?.barcode }}</p>
        </div>
      </section>

      <section class="rounded-2xl border border-slate-200 bg-white p-4">
        <h3 class="mt-0">{{ t('desk.generate') }}</h3>
        <FieldLabel icon="tag">{{ t('desk.type') }}</FieldLabel>
        <div class="flex gap-2">
          <select v-model="type" class="field">
            <option value="internal">{{ t('desk.internal') }}</option>
            <option value="ean13">EAN-13</option>
            <option value="code128">Code 128</option>
            <option value="qr">QR</option>
          </select>
          <button class="btn-primary" @click="generate">{{ t('desk.generate') }}</button>
        </div>
        <p v-if="generated" class="mt-3 font-mono text-lg">{{ generated }} <button class="btn-secondary" @click="printCode(generated)">{{ t('desk.print') }}</button></p>
      </section>

      <section class="rounded-2xl border border-slate-200 bg-white p-4 lg:col-span-2">
        <div class="flex gap-2">
          <input v-model="query" type="search" class="field" :placeholder="t('desk.searchCodes')" />
        </div>
        <table class="mt-3 min-w-full text-sm">
          <tbody>
            <tr v-for="item in (results.length ? results : catalog)" :key="item.barcode">
              <td class="px-2 py-2 font-mono">{{ item.barcode }}</td>
              <td class="px-2 py-2 text-slate-500">{{ item.type }}</td>
              <td class="px-2 py-2 text-right"><button class="text-brand-600" @click="printCode(item.barcode)">{{ t('desk.print') }}</button></td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </PageFrame>
</template>
