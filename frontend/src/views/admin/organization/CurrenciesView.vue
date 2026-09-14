<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Currency } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog, notify } = useConfirm()
const store = useBackofficeStore()
const showModal = ref(false)
const editing = ref<Currency | null>(null)
const saving = ref(false)
const form = ref({
  code: 'FBU',
  name: '',
  symbol: 'FBu',
  decimal_places: 0,
  exchange_rate: 1,
  is_default: false,
  is_active: true,
})

onMounted(() => store.loadCurrencies())

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
    await store.saveCurrency({
      ...form.value,
      code: form.value.code.toUpperCase(),
      symbol: form.value.symbol || form.value.code.toUpperCase(),
    }, editing.value?.id)
    await store.loadCurrencies()
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
      <div class="flex justify-end">
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">
          + {{ t('org.addCurrency') }}
        </button>
      </div>
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
            <tr v-for="currency in store.currencies" :key="currency.id" class="hover:bg-slate-50">
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
        <p v-if="!store.currencies.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
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
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.45rem 0.95rem;
  font-size: 0.875rem;
  background: white;
}

.bg-brand-600 {
  background-color: var(--color-brand-600);
}

.uppercase {
  text-transform: uppercase;
}
</style>
