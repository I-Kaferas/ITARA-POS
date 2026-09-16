<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Currency } from '../../../types'
import { getAppCurrency, setAppCurrency } from '../../../utils/currency'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const { confirm: confirmDialog, notify } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()
const showModal = ref(false)
const editing = ref<Currency | null>(null)
const saving = ref(false)
const applyingAppCurrency = ref(false)
const appCurrencyCode = ref(getAppCurrency())
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.currencies.filter(currency =>
  matchesSearch(`${currency.code} ${currency.name} ${currency.symbol}`, filters.value.search)
  && matchesActive(currency.is_active, filters.value.active),
))
const form = ref({
  code: 'FBU',
  name: '',
  symbol: 'FBu',
  decimal_places: 0,
  exchange_rate: 1,
  is_default: false,
  is_active: true,
})

const activeCurrencies = computed(() =>
  store.currencies.filter(c => c.is_active).sort((a, b) => {
    if (a.is_default !== b.is_default) return a.is_default ? -1 : 1
    return a.code.localeCompare(b.code)
  }),
)

const currentAppCurrency = computed(() =>
  store.currencies.find(c => c.code === appCurrencyCode.value)
  ?? store.currencies.find(c => c.is_default)
  ?? null,
)

const companyCurrencyCode = computed(() => {
  const company = store.companies.find(c => c.is_active) ?? store.companies[0]
  return (company?.currency_code || '').toUpperCase()
})

const appCurrencyDirty = computed(() =>
  !!appCurrencyCode.value && appCurrencyCode.value !== companyCurrencyCode.value,
)

onMounted(async () => {
  await Promise.all([store.loadCurrencies(), store.loadCompanies()])
  syncAppCurrencyFromCompany()
})

function syncAppCurrencyFromCompany() {
  const company = store.companies.find(c => c.is_active) ?? store.companies[0]
  const code = (company?.currency_code || store.currencies.find(c => c.is_default)?.code || getAppCurrency()).toUpperCase()
  appCurrencyCode.value = code
  setAppCurrency(code)
}

async function applyAppCurrency() {
  const code = appCurrencyCode.value.trim().toUpperCase()
  if (!code) return
  const company = store.companies.find(c => c.is_active) ?? store.companies[0]
  if (!company) {
    await notify(t('org.appCurrencyNoCompany'))
    return
  }
  applyingAppCurrency.value = true
  try {
    await store.saveCompany({ currency_code: code }, company.id)
    const existing = store.currencies.find(c => c.code === code)
    if (existing && !existing.is_default) {
      await store.saveCurrency({ is_default: true, is_active: true }, existing.id)
    }
    await Promise.all([store.loadCurrencies(), store.loadCompanies()])
    setAppCurrency(code)
    await context.loadStores()
    syncAppCurrencyFromCompany()
  } finally {
    applyingAppCurrency.value = false
  }
}

function openCreate() {
  editing.value = null
  form.value = {
    code: 'FBU',
    name: 'Franc Burundais',
    symbol: 'FBu',
    decimal_places: 0,
    exchange_rate: 1,
    is_default: !store.currencies.some(c => c.is_default),
    is_active: true,
  }
  showModal.value = true
}

function openEdit(currency: Currency) {
  editing.value = currency
  form.value = {
    code: currency.code,
    name: currency.name,
    symbol: currency.symbol ?? '',
    decimal_places: currency.decimal_places,
    exchange_rate: Number(currency.exchange_rate),
    is_default: currency.is_default,
    is_active: currency.is_active,
  }
  showModal.value = true
}

async function save() {
  saving.value = true
  try {
    const saved = await store.saveCurrency({
      ...form.value,
      code: form.value.code.toUpperCase(),
      symbol: form.value.symbol || form.value.code.toUpperCase(),
    }, editing.value?.id)
    await store.loadCurrencies()
    if (saved.is_default) {
      await store.loadCompanies()
      setAppCurrency(saved.code)
      appCurrencyCode.value = saved.code
      await context.loadStores()
    }
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(currency: Currency) {
  if (currency.is_default) {
    await notify(t('org.cannotDeleteDefaultCurrency'))
    return
  }
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCurrency(currency.id)
  await store.loadCurrencies()
}

function closeModal() {
  if (saving.value) return
  showModal.value = false
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <section class="app-currency rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200 sm:p-5">
        <div class="app-currency__head">
          <span class="app-currency__icon" aria-hidden="true">
            <AppIcon name="coins" :size="18" />
          </span>
          <div>
            <h2 class="app-currency__title">{{ t('org.appCurrency') }}</h2>
            <p class="app-currency__hint">{{ t('org.appCurrencyHint') }}</p>
          </div>
        </div>

        <div class="app-currency__row">
          <div class="app-currency__field">
            <FieldLabel icon="coins">{{ t('org.appCurrency') }}</FieldLabel>
            <select v-model="appCurrencyCode" class="field" :disabled="!activeCurrencies.length || applyingAppCurrency">
              <option v-for="currency in activeCurrencies" :key="currency.id" :value="currency.code">
                {{ currency.code }} — {{ currency.name }}{{ currency.is_default ? ` (${t('org.default')})` : '' }}
              </option>
            </select>
          </div>
          <button
            type="button"
            class="btn-primary app-currency__apply"
            :disabled="!activeCurrencies.length || applyingAppCurrency || !appCurrencyDirty"
            @click="applyAppCurrency"
          >
            {{ applyingAppCurrency ? t('common.save') : t('org.appCurrencyApply') }}
          </button>
        </div>

        <p v-if="currentAppCurrency" class="app-currency__current">
          {{ t('org.appCurrencyCurrent', { code: currentAppCurrency.code, name: currentAppCurrency.name }) }}
        </p>
        <p v-else-if="!store.currencies.length" class="app-currency__current app-currency__current--warn">
          {{ t('org.appCurrencyEmpty') }}
        </p>
      </section>

      <div class="flex justify-end">
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">
          + {{ t('org.addCurrency') }}
        </button>
      </div>
      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.symbol') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.decimalPlaces') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.default') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="currency in filtered" :key="currency.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono font-medium">{{ currency.code }}</td>
              <td class="px-4 py-3">{{ currency.name }}</td>
              <td class="px-4 py-3">{{ currency.symbol }}</td>
              <td class="px-4 py-3">{{ currency.decimal_places }}</td>
              <td class="px-4 py-3">{{ currency.is_default ? '✓' : '—' }}</td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(currency)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(currency)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('org.editCurrency') : t('org.addCurrency')"
      icon="coins"
      tone="accent"
      :close-on-backdrop="!saving"
      @close="closeModal"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <FieldLabel icon="tag">{{ t('org.code') }}</FieldLabel>
            <input v-model="form.code" required maxlength="3" class="field uppercase" />
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('org.symbol') }}</FieldLabel>
            <input v-model="form.symbol" class="field" />
          </div>
          <div class="col-span-2">
            <FieldLabel icon="account">{{ t('org.name') }}</FieldLabel>
            <input v-model="form.name" required class="field" />
          </div>
          <div>
            <FieldLabel icon="calculator">{{ t('org.decimalPlaces') }}</FieldLabel>
            <input v-model.number="form.decimal_places" type="number" min="0" max="6" required class="field" />
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('org.exchangeRate') }}</FieldLabel>
            <input v-model.number="form.exchange_rate" type="number" min="0" step="0.00000001" required class="field" />
            <p class="mt-1 text-xs text-slate-500">{{ t('org.exchangeRateHint') }}</p>
          </div>
        </div>

        <div class="flex flex-wrap gap-x-5 gap-y-2">
          <label class="flex items-center gap-2 text-sm text-slate-700">
            <span class="field-icon"><AppIcon name="coins" :size="14" /></span>
            <input v-model="form.is_default" type="checkbox" class="rounded" />
            {{ t('org.defaultCurrency') }}
          </label>
          <label class="flex items-center gap-2 text-sm text-slate-700">
            <span class="field-icon"><AppIcon name="check" :size="14" /></span>
            <input v-model="form.is_active" type="checkbox" class="rounded" />
            {{ t('products.active') }}
          </label>
        </div>
        <p class="text-xs text-slate-500">{{ t('org.defaultCurrencyHint') }}</p>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="closeModal">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.field {
  width: 100%;
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.45rem 0.7rem;
  font-size: 0.875rem;
  background: white;
}

.btn-primary {
  border-radius: 0.5rem;
  padding: 0.45rem 0.95rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: white;
  background-color: var(--color-brand-600);
}

.btn-primary:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.btn-secondary {
  border-radius: 0.5rem;
  padding: 0.45rem 0.95rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #334155;
  background: #f1f5f9;
}

.field-icon {
  display: inline-flex;
  color: #64748b;
}

.app-currency__head {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
  margin-bottom: 1rem;
}

.app-currency__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 0.65rem;
  background: color-mix(in srgb, var(--color-brand-500, #2f6fed) 12%, #fff);
  color: var(--color-brand-700, #1d4ed8);
  flex-shrink: 0;
}

.app-currency__title {
  margin: 0;
  font-size: 1rem;
  font-weight: 650;
  color: #0f172a;
}

.app-currency__hint {
  margin: 0.2rem 0 0;
  font-size: 0.82rem;
  line-height: 1.4;
  color: #64748b;
}

.app-currency__row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  align-items: flex-end;
}

.app-currency__field {
  flex: 1 1 16rem;
  min-width: 12rem;
}

.app-currency__apply {
  flex: 0 0 auto;
  height: 2.35rem;
}

.app-currency__current {
  margin: 0.75rem 0 0;
  font-size: 0.8rem;
  color: #475569;
}

.app-currency__current--warn {
  color: #b45309;
}
</style>
