<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { CompanyPaymentMethod } from '../../../types'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const savingId = ref<string | null>(null)
const message = ref('')

const companyId = computed(() => store.companies[0]?.id ?? null)

const methods = computed(() => store.paymentMethods)

function methodLabel(row: CompanyPaymentMethod) {
  return locale.value === 'fr' ? (row.label_fr || row.label) : row.label
}

onMounted(async () => {
  if (!store.companies.length) await store.loadCompanies()
  if (companyId.value) await store.loadPaymentMethods(companyId.value)
})

async function toggle(row: CompanyPaymentMethod, field: 'is_enabled' | 'available_on_pos', value: boolean) {
  if (!companyId.value) return
  savingId.value = row.id
  message.value = ''
  try {
    const payload: Partial<CompanyPaymentMethod> = { [field]: value }
    if (field === 'available_on_pos' && value) payload.is_enabled = true
    if (field === 'is_enabled' && !value) payload.available_on_pos = false
    await store.updatePaymentMethod(companyId.value, row.id, payload)
    await store.loadPaymentMethods(companyId.value)
    message.value = t('org.paymentMethodsSaved')
  } catch (e) {
    message.value = e instanceof Error ? e.message : 'Erreur'
  } finally {
    savingId.value = null
  }
}

async function saveLabel(row: CompanyPaymentMethod, event: Event) {
  if (!companyId.value) return
  const input = event.target as HTMLInputElement
  const next = input.value.trim()
  if (!next || next === row.label_fr) return
  savingId.value = row.id
  try {
    await store.updatePaymentMethod(companyId.value, row.id, { label_fr: next, label: next })
    await store.loadPaymentMethods(companyId.value)
    message.value = t('org.paymentMethodsSaved')
  } finally {
    savingId.value = null
  }
}

async function move(row: CompanyPaymentMethod, direction: -1 | 1) {
  if (!companyId.value) return
  const list = [...methods.value]
  const index = list.findIndex(m => m.id === row.id)
  const target = index + direction
  if (index < 0 || target < 0 || target >= list.length) return
  const order = list.map(m => m.id)
  ;[order[index], order[target]] = [order[target], order[index]]
  savingId.value = row.id
  try {
    await store.reorderPaymentMethods(companyId.value, order)
    await store.loadPaymentMethods(companyId.value)
  } finally {
    savingId.value = null
  }
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200">
        <h2 class="m-0 text-base font-semibold text-slate-800">{{ t('org.paymentMethodsTitle') }}</h2>
        <p class="mt-1 mb-0 text-sm text-slate-500">{{ t('org.paymentMethodsHint') }}</p>
        <p v-if="message" class="mt-2 mb-0 text-sm text-brand-700">{{ message }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.paymentMethodCode') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-center font-medium">{{ t('org.enabled') }}</th>
              <th class="px-4 py-3 text-center font-medium">{{ t('org.availableOnPos') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('org.sortOrder') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in methods" :key="row.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono text-xs uppercase text-slate-600">{{ row.code }}</td>
              <td class="px-4 py-3">
                <input
                  class="w-full rounded-lg border border-slate-200 px-3 py-1.5"
                  :value="methodLabel(row)"
                  :disabled="savingId === row.id"
                  @change="saveLabel(row, $event)"
                />
                <p v-if="row.requires_customer" class="mt-1 mb-0 text-xs text-amber-600">
                  {{ t('org.requiresCustomer') }}
                </p>
              </td>
              <td class="px-4 py-3 text-center">
                <input
                  type="checkbox"
                  class="h-4 w-4"
                  :checked="row.is_enabled"
                  :disabled="savingId === row.id"
                  @change="toggle(row, 'is_enabled', ($event.target as HTMLInputElement).checked)"
                />
              </td>
              <td class="px-4 py-3 text-center">
                <input
                  type="checkbox"
                  class="h-4 w-4"
                  :checked="row.available_on_pos"
                  :disabled="savingId === row.id || !row.is_enabled"
                  @change="toggle(row, 'available_on_pos', ($event.target as HTMLInputElement).checked)"
                />
              </td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-slate-500 hover:text-brand-600" :disabled="savingId === row.id" @click="move(row, -1)">↑</button>
                <button class="text-slate-500 hover:text-brand-600" :disabled="savingId === row.id" @click="move(row, 1)">↓</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!methods.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>
  </OrganizationLayout>
</template>
