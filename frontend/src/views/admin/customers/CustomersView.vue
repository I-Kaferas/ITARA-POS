<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Customer } from '../../../types'

type CustomerType = 'individual' | 'company'
type CustomerOrigin = 'local' | 'foreign'
type FormTab = 'general' | 'financial' | 'notes'

const PAYMENT_TERMS = [0, 7, 15, 30, 60, 90]

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const search = ref('')
const showModal = ref(false)
const editing = ref<Customer | null>(null)
const saving = ref(false)
const saveError = ref('')
const activeTab = ref<FormTab>('general')
const form = ref(emptyForm())

function emptyForm() {
  return {
    name: '',
    customer_type: 'individual' as CustomerType,
    origin: 'local' as CustomerOrigin,
    contact_person: '',
    tax_id: '',
    email: '',
    phone: '',
    mobile: '',
    street: '',
    city: '',
    country: 'Burundi',
    credit_limit: 0,
    discount_percent: 0,
    payment_terms_days: 0,
    notes: '',
    address_id: '' as string,
    is_active: true,
  }
}

function metaString(item: Customer, key: string) {
  const value = item.metadata?.[key]
  return typeof value === 'string' ? value : ''
}

function metaNumber(item: Customer, key: string) {
  const value = item.metadata?.[key]
  return typeof value === 'number' ? value : Number(value ?? 0) || 0
}

onMounted(() => store.loadCustomers())

async function applySearch() {
  await store.loadCustomers(search.value)
}

function openCreate() {
  editing.value = null
  saveError.value = ''
  activeTab.value = 'general'
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(item: Customer) {
  editing.value = item
  saveError.value = ''
  activeTab.value = 'general'
  const address = item.addresses?.find(row => row.is_primary) ?? item.addresses?.[0]
  form.value = {
    name: item.name,
    customer_type: (metaString(item, 'customer_type') || 'individual') as CustomerType,
    origin: (metaString(item, 'origin') || 'local') as CustomerOrigin,
    contact_person: metaString(item, 'contact_person'),
    tax_id: item.tax_id ?? metaString(item, 'nif'),
    email: item.email ?? '',
    phone: item.phone ?? '',
    mobile: metaString(item, 'mobile'),
    street: address?.line1 ?? metaString(item, 'street'),
    city: address?.city ?? metaString(item, 'city'),
    country: metaString(item, 'country') || address?.country_code || 'Burundi',
    credit_limit: (item.credit_limit ?? 0) / 100,
    discount_percent: metaNumber(item, 'discount_percent'),
    payment_terms_days: item.payment_terms_days ?? 0,
    notes: item.notes ?? '',
    address_id: address?.id ?? '',
    is_active: item.is_active,
  }
  showModal.value = true
}

async function save() {
  saveError.value = ''
    if (!form.value.name.trim()) {
    activeTab.value = 'general'
    saveError.value = t('customers.saveFailed')
    return
  }
  if (form.value.customer_type === 'company' && !form.value.tax_id.trim()) {
    activeTab.value = 'general'
    saveError.value = t('customers.nifRequired')
    return
  }

  saving.value = true
  try {
    const saved = await store.saveCustomer({
      name: form.value.name.trim(),
      tax_id: form.value.customer_type === 'company' ? form.value.tax_id.trim() : null,
      email: form.value.email.trim() || null,
      phone: form.value.phone.trim() || null,
      credit_limit: Math.max(0, Math.round(Number(form.value.credit_limit) * 100) || 0),
      payment_terms_days: Number(form.value.payment_terms_days) || 0,
      notes: form.value.notes.trim() || null,
      is_active: form.value.is_active,
      metadata: {
        customer_type: form.value.customer_type,
        origin: form.value.origin,
        contact_person: form.value.contact_person.trim() || null,
        nif: form.value.customer_type === 'company' ? form.value.tax_id.trim() : null,
        mobile: form.value.mobile.trim() || null,
        discount_percent: Math.max(0, Math.min(100, Number(form.value.discount_percent) || 0)),
        street: form.value.street.trim() || null,
        city: form.value.city.trim() || null,
        country: form.value.country.trim() || null,
      },
    }, editing.value?.id)

    if (form.value.street.trim()) {
      await store.saveCustomerAddress(saved.id, {
        label: 'primary',
        line1: form.value.street.trim(),
        city: form.value.city.trim() || null,
        country_code: form.value.country.trim().length === 2 ? form.value.country.trim().toUpperCase() : 'BI',
        is_primary: true,
        is_billing: true,
        is_shipping: true,
      }, form.value.address_id || undefined)
    }

    await store.loadCustomers(search.value)
    showModal.value = false
  } catch (error) {
    saveError.value = extractApiErrorMessage(error, t('customers.saveFailed'))
  } finally {
    saving.value = false
  }
}

async function remove(item: Customer) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCustomer(item.id)
  await store.loadCustomers(search.value)
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.customers') }}</template>
    <template #subtitle>{{ t('customers.subtitle') }}</template>

    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <form class="flex gap-2" @submit.prevent="applySearch">
          <input v-model="search" type="search" :placeholder="t('common.search')" class="field max-w-xs" />
          <button type="submit" class="btn-secondary">{{ t('common.search') }}</button>
        </form>
        <button class="btn-primary" @click="openCreate">+ {{ t('customers.add') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('auth.email') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in store.customers" :key="item.id" class="hover:bg-slate-50 cursor-pointer" @click="$router.push({ name: 'customer-detail', params: { id: item.id } })">
              <td class="px-4 py-3 font-mono text-slate-500">{{ item.code ?? '—' }}</td>
              <td class="px-4 py-3 font-medium">{{ item.name }}</td>
              <td class="px-4 py-3 text-slate-600">{{ item.email ?? '—' }}</td>
              <td class="px-4 py-3"><StatusBadge :active="item.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2" @click.stop>
                <button class="text-brand-600" @click="openEdit(item)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(item)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.customers.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      size="xl"
      :title="editing ? t('customers.edit') : t('customers.add')"
      icon="customers"
      tone="brand"
      @close="showModal = false"
    >
      <form class="customer-form" novalidate @submit.prevent="save">
        <div class="customer-tabs">
          <button
            v-for="tab in (['general', 'financial', 'notes'] as const)"
            :key="tab"
            type="button"
            class="customer-tabs__btn"
            :class="{ 'customer-tabs__btn--active': activeTab === tab }"
            @click="activeTab = tab"
          >
            {{ t(`customers.tabs.${tab}`) }}
          </button>
        </div>

        <div v-show="activeTab === 'general'" class="customer-pane">
          <div>
            <label class="label">{{ t('customers.name') }} *</label>
            <input v-model="form.name" class="field" :placeholder="t('customers.namePlaceholder')" />
          </div>

          <div>
            <label class="label">{{ t('customers.type') }} *</label>
            <div class="choice-row">
              <button
                type="button"
                class="choice"
                :class="{ 'choice--active': form.customer_type === 'individual' }"
                @click="form.customer_type = 'individual'"
              >
                <span class="choice__icon">👤</span>
                <span>{{ t('customers.types.individual') }}</span>
              </button>
              <button
                type="button"
                class="choice"
                :class="{ 'choice--active': form.customer_type === 'company' }"
                @click="form.customer_type = 'company'"
              >
                <span class="choice__icon">🏢</span>
                <span>{{ t('customers.types.company') }}</span>
              </button>
            </div>
          </div>

          <div v-if="form.customer_type === 'company'">
            <label class="label">{{ t('customers.nif') }} *</label>
            <input v-model="form.tax_id" class="field" :placeholder="t('customers.nifPlaceholder')" />
          </div>

          <div>
            <label class="label">{{ t('customers.origin') }}</label>
            <div class="choice-row">
              <button
                type="button"
                class="choice"
                :class="{ 'choice--active': form.origin === 'local' }"
                @click="form.origin = 'local'"
              >
                <span class="choice__icon">🏠</span>
                <span>{{ t('customers.origins.local') }}</span>
              </button>
              <button
                type="button"
                class="choice"
                :class="{ 'choice--active': form.origin === 'foreign' }"
                @click="form.origin = 'foreign'"
              >
                <span class="choice__icon">🌍</span>
                <span>{{ t('customers.origins.foreign') }}</span>
              </button>
            </div>
          </div>

          <div>
            <label class="label">{{ t('customers.contactPerson') }}</label>
            <input v-model="form.contact_person" class="field" :placeholder="t('customers.contactPlaceholder')" />
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="label">{{ t('customers.email') }}</label>
              <input v-model="form.email" type="email" class="field" :placeholder="t('customers.emailPlaceholder')" />
            </div>
            <div>
              <label class="label">{{ t('customers.phone') }}</label>
              <input v-model="form.phone" class="field" :placeholder="t('customers.phonePlaceholder')" />
            </div>
            <div>
              <label class="label">{{ t('customers.mobile') }}</label>
              <input v-model="form.mobile" class="field" :placeholder="t('customers.mobilePlaceholder')" />
            </div>
          </div>

          <div>
            <label class="label">{{ t('customers.address') }}</label>
            <input v-model="form.street" class="field" :placeholder="t('customers.addressPlaceholder')" />
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="label">{{ t('customers.city') }}</label>
              <input v-model="form.city" class="field" :placeholder="t('customers.cityPlaceholder')" />
            </div>
            <div>
              <label class="label">{{ t('customers.country') }}</label>
              <input v-model="form.country" class="field" :placeholder="t('customers.countryPlaceholder')" />
            </div>
          </div>
        </div>

        <div v-show="activeTab === 'financial'" class="customer-pane">
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <label class="label">{{ t('customers.creditLimit') }}</label>
              <input v-model.number="form.credit_limit" type="number" min="0" step="0.01" class="field" />
              <p class="hint">{{ t('customers.creditLimitHint') }}</p>
            </div>
            <div>
              <label class="label">{{ t('customers.discount') }}</label>
              <input v-model.number="form.discount_percent" type="number" min="0" max="100" step="0.01" class="field" />
              <p class="hint">{{ t('customers.discountHint') }}</p>
            </div>
          </div>
          <div>
            <label class="label">{{ t('customers.paymentTerms') }}</label>
            <select v-model.number="form.payment_terms_days" class="field">
              <option v-for="days in PAYMENT_TERMS" :key="days" :value="days">{{ t(`customers.terms.${days}`) }}</option>
            </select>
          </div>
        </div>

        <div v-show="activeTab === 'notes'" class="customer-pane">
          <div>
            <label class="label">{{ t('customers.internalNotes') }}</label>
            <textarea v-model="form.notes" rows="6" class="field" :placeholder="t('customers.notesPlaceholder')" />
          </div>
        </div>

        <p v-if="saveError" class="save-error">{{ saveError }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ saving ? t('common.loading') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.label { display: block; margin-bottom: 0.3rem; font-size: 0.8125rem; font-weight: 600; color: #334155; }
.hint { margin: 0.3rem 0 0; font-size: 0.75rem; color: #94a3b8; }
.customer-form { display: flex; flex-direction: column; gap: 1rem; }
.customer-tabs { display: flex; gap: 0.4rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.35rem; }
.customer-tabs__btn {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 650;
  padding: 0.45rem 0.8rem;
  border-radius: 0.55rem;
  cursor: pointer;
}
.customer-tabs__btn--active {
  background: color-mix(in srgb, var(--color-brand-500) 12%, white);
  color: var(--color-brand-700, #3d5c73);
}
.customer-pane { display: flex; flex-direction: column; gap: 0.85rem; }
.choice-row { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.55rem; }
.choice {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  min-height: 2.8rem;
  padding: 0.55rem 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  color: #334155;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  text-align: left;
}
.choice--active {
  border-color: var(--color-brand-600);
  background: color-mix(in srgb, var(--color-brand-500) 8%, white);
  box-shadow: 0 0 0 1px var(--color-brand-600);
}
.choice__icon { font-size: 1.05rem; }
.save-error { margin: 0; border-radius: 0.65rem; background: #fef2f2; color: #b91c1c; padding: 0.65rem 0.75rem; font-size: 0.8125rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
