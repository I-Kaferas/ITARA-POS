<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Catalog, Company, Currency } from '../../../types'
import { formatMoney, parseMoneyInput } from '../../../utils/money'

type Tier = { amount: number; currency_code: string; price_id?: string | null; quote: { ht: number; tva: number; ttc: number }; in_default: number }
type Row = {
  id: string
  sku: string
  name: string
  tax: { code?: string; name: string; rate: number; is_inclusive: boolean } | null
  prices: Record<string, Tier>
}

const TYPES = ['retail', 'wholesale', 'vip', 'special'] as const

const { t } = useI18n()
const store = useBackofficeStore()
const company = ref<Company | null>(null)
const catalog = ref<Catalog | null>(null)
const rows = ref<Row[]>([])
const currencies = ref<Currency[]>([])
const defaultCurrency = ref('FBU')
const drafts = ref<Record<string, Record<string, string>>>({})
const currenciesByRow = ref<Record<string, string>>({})
const savingId = ref('')

const catalogs = computed(() => store.catalogs)

onMounted(async () => {
  await store.loadCompanies()
  company.value = store.companies[0] ?? null
  if (company.value) await selectCompany(company.value.id)
})

async function selectCompany(id: string) {
  company.value = store.companies.find(item => item.id === id) ?? null
  const loaded = await store.loadCatalogs(id)
  catalog.value = loaded.find(item => item.is_default) ?? loaded[0] ?? null
  if (catalog.value) await load()
}

async function load() {
  if (!catalog.value) return
  const payload = await store.loadPriceList(catalog.value.id)
  rows.value = payload.data
  currencies.value = payload.currencies
  defaultCurrency.value = payload.default_currency
  drafts.value = Object.fromEntries(payload.data.map(row => [
    row.id,
    Object.fromEntries(TYPES.map(type => [type, (row.prices[type].amount / 100).toFixed(2)])),
  ]))
  currenciesByRow.value = Object.fromEntries(payload.data.map(row => [row.id, row.prices.retail?.currency_code || payload.default_currency]))
}

async function save(row: Row) {
  savingId.value = row.id
  try {
    const currency = (currenciesByRow.value[row.id] || defaultCurrency.value).toUpperCase()
    await store.saveProduct('', {
      prices: TYPES.map(type => ({
        ...(row.prices[type]?.price_id ? { id: row.prices[type].price_id } : {}),
        price_type: type,
        amount: parseMoneyInput(drafts.value[row.id]?.[type] ?? '0'),
        currency_code: currency,
        min_quantity: 1,
        is_active: true,
      })),
    }, row.id)
    await load()
  } finally {
    savingId.value = ''
  }
}

function money(amount: number, currency?: string) {
  return formatMoney(amount, currency || defaultCurrency.value)
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-end justify-between gap-3">
        <p class="m-0 max-w-3xl text-sm text-slate-500">{{ t('catalog.priceList.hint') }}</p>
        <div class="flex flex-wrap gap-3">
          <label class="text-sm">
            <span class="mb-1 block font-medium">{{ t('org.company') }}</span>
            <select class="field" :value="company?.id" @change="selectCompany(($event.target as HTMLSelectElement).value)">
              <option v-for="item in store.companies" :key="item.id" :value="item.id">{{ item.name }}</option>
            </select>
          </label>
          <label class="text-sm">
            <span class="mb-1 block font-medium">{{ t('nav.catalogs') }}</span>
            <select class="field" :value="catalog?.id" @change="catalog = catalogs.find(item => item.id === ($event.target as HTMLSelectElement).value) ?? null; load()">
              <option v-for="item in catalogs" :key="item.id" :value="item.id">{{ item.name }}</option>
            </select>
          </label>
        </div>
      </div>

      <p class="m-0 text-sm text-slate-500">
        {{ t('catalog.priceList.currencyHint', { currency: defaultCurrency }) }}
        <RouterLink class="text-brand-600" to="/admin/organization/currencies">{{ t('org.tabs.currencies') }}</RouterLink>
      </p>

      <div class="overflow-x-auto rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.currency') }}</th>
              <th v-for="type in TYPES" :key="type" class="px-4 py-3 text-left font-medium">{{ t(`products.priceTypes.${type}`) }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.priceList.breakdown') }}</th>
              <th />
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in rows" :key="row.id">
              <td class="px-4 py-3">
                <span class="block font-medium">{{ row.name }}</span>
                <span class="font-mono text-xs text-slate-400">{{ row.sku }}</span>
                <span v-if="row.tax" class="block text-xs text-slate-400">{{ row.tax.code || row.tax.name }} {{ row.tax.rate }}%</span>
              </td>
              <td class="px-4 py-3">
                <select v-model="currenciesByRow[row.id]" class="field w-24">
                  <option v-for="currency in currencies" :key="currency.id" :value="currency.code">{{ currency.code }}</option>
                  <option v-if="!currencies.length" :value="defaultCurrency">{{ defaultCurrency }}</option>
                </select>
              </td>
              <td v-for="type in TYPES" :key="type" class="px-4 py-3">
                <input v-model="drafts[row.id][type]" type="number" min="0" step="0.01" class="field w-28" />
                <p v-if="row.prices[type]?.currency_code !== defaultCurrency" class="m-0 mt-1 text-xs text-slate-400">
                  {{ money(row.prices[type].in_default, defaultCurrency) }}
                </p>
              </td>
              <td class="px-4 py-3 text-xs text-slate-600">
                <div>HT {{ money(row.prices.retail.quote.ht, row.prices.retail.currency_code) }}</div>
                <div>TVA {{ money(row.prices.retail.quote.tva, row.prices.retail.currency_code) }}</div>
                <div>TTC {{ money(row.prices.retail.quote.ttc, row.prices.retail.currency_code) }}</div>
              </td>
              <td class="px-4 py-3 text-right">
                <button class="text-brand-600" :disabled="savingId === row.id" @click="save(row)">{{ t('common.save') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!rows.length" class="px-4 py-8 text-center text-slate-500">{{ t('products.empty') }}</p>
      </div>
    </div>
  </CatalogLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.4rem 0.6rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
