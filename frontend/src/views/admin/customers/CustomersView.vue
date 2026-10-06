<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import PageFrame from '../../../components/layout/PageFrame.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
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
    code: '',
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

watchLiveSearch(search, applySearch)

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
    code: item.code ?? '',
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
      code: editing.value
        ? (form.value.code.trim() || undefined)
        : undefined,
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
  <PageFrame>
    <template #title>{{ t('nav.customers') }}</template>
    <template #subtitle>{{ t('customers.subtitle') }}</template>

    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <input v-model="search" type="search" :placeholder="t('common.search')" class="field max-w-xs" />
        <button class="btn-primary" @click="openCreate">+ {{ t('customers.add') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('customers.phone') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('auth.email') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in store.customers" :key="item.id" class="hover:bg-slate-50 cursor-pointer" @click="$router.push({ name: 'customer-detail', params: { id: item.id } })">
              <td class="px-4 py-3 font-mono text-slate-500">{{ item.code ?? '—' }}</td>
              <td class="px-4 py-3 font-medium">{{ item.name }}</td>
              <td class="px-4 py-3 text-slate-600">{{ item.phone || '—' }}</td>
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
        <div class="form-tabs" role="tablist">
          <button
            v-for="tab in (['general', 'financial', 'notes'] as const)"
            :key="tab"
            type="button"
            role="tab"
            class="form-tabs__btn"
            :class="{ 'form-tabs__btn--active': activeTab === tab }"
            :aria-selected="activeTab === tab"
            @click="activeTab = tab"
          >
            {{ t(`customers.tabs.${tab}`) }}
          </button>
        </div>

        <div v-show="activeTab === 'general'" class="customer-pane">
          <div>
            <FieldLabel icon="tag">{{ t('customers.code') }}</FieldLabel>
            <input
              v-if="editing"
              v-model="form.code"
              class="field font-mono"
              :placeholder="t('customers.codePlaceholder')"
            />
            <p v-else class="customer-code-hint">{{ t('customers.codeAuto') }}</p>
          </div>

          <div>
            <FieldLabel icon="customers">{{ t('customers.name') }} *</FieldLabel>
            <input v-model="form.name" class="field" :placeholder="t('customers.namePlaceholder')" />
          </div>

          <div>
            <FieldLabel icon="customers">{{ t('customers.type') }} *</FieldLabel>
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
            <FieldLabel icon="tag">{{ t('customers.nif') }} *</FieldLabel>
            <input v-model="form.tax_id" class="field" :placeholder="t('customers.nifPlaceholder')" />
          </div>

          <div>
            <FieldLabel icon="store-pin">{{ t('customers.origin') }}</FieldLabel>
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
            <FieldLabel icon="account">{{ t('customers.contactPerson') }}</FieldLabel>
            <input v-model="form.contact_person" class="field" :placeholder="t('customers.contactPlaceholder')" />
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <FieldLabel icon="mail">{{ t('customers.email') }}</FieldLabel>
              <input v-model="form.email" type="email" class="field" :placeholder="t('customers.emailPlaceholder')" />
            </div>
            <div>
              <FieldLabel icon="phone">{{ t('customers.phone') }}</FieldLabel>
              <input v-model="form.phone" class="field" :placeholder="t('customers.phonePlaceholder')" />
            </div>
            <div>
              <FieldLabel icon="phone">{{ t('customers.mobile') }}</FieldLabel>
              <input v-model="form.mobile" class="field" :placeholder="t('customers.mobilePlaceholder')" />
            </div>
          </div>

          <div>
            <FieldLabel icon="pin">{{ t('customers.address') }}</FieldLabel>
            <input v-model="form.street" class="field" :placeholder="t('customers.addressPlaceholder')" />
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <FieldLabel icon="building">{{ t('customers.city') }}</FieldLabel>
              <input v-model="form.city" class="field" :placeholder="t('customers.cityPlaceholder')" />
            </div>
            <div>
              <FieldLabel icon="store-pin">{{ t('customers.country') }}</FieldLabel>
              <input v-model="form.country" class="field" :placeholder="t('customers.countryPlaceholder')" />
            </div>
          </div>
        </div>

        <div v-show="activeTab === 'financial'" class="customer-pane">
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <FieldLabel icon="coins">{{ t('customers.creditLimit') }}</FieldLabel>
              <input v-model.number="form.credit_limit" type="number" min="0" step="0.01" class="field" />
              <p class="hint">{{ t('customers.creditLimitHint') }}</p>
            </div>
            <div>
              <FieldLabel icon="coins">{{ t('customers.discount') }}</FieldLabel>
              <input v-model.number="form.discount_percent" type="number" min="0" max="100" step="0.01" class="field" />
              <p class="hint">{{ t('customers.discountHint') }}</p>
            </div>
          </div>
          <div>
            <FieldLabel icon="coins">{{ t('customers.paymentTerms') }}</FieldLabel>
            <select v-model.number="form.payment_terms_days" class="field">
              <option v-for="days in PAYMENT_TERMS" :key="days" :value="days">{{ t(`customers.terms.${days}`) }}</option>
            </select>
          </div>
        </div>

        <div v-show="activeTab === 'notes'" class="customer-pane">
          <div>
            <FieldLabel icon="note">{{ t('customers.internalNotes') }}</FieldLabel>
            <textarea v-model="form.notes" rows="6" class="field" :placeholder="t('customers.notesPlaceholder')" />
          </div>
        </div>

        <p v-if="saveError" class="save-error">{{ saveError }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving">{{ saving ? t('common.saving') : (editing ? t('common.saveChanges') : t('common.save')) }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>

.customer-form { display: flex; flex-direction: column; gap: var(--field-gap); }
.customer-pane { display: flex; flex-direction: column; gap: var(--field-gap); }
.customer-code-hint {
  margin: 0;
  padding: 0.65rem 0.8rem;
  border-radius: 0.65rem;
  border: 1px dashed var(--color-border-strong);
  background: var(--color-canvas);
  color: var(--color-text-muted);
  font-size: 0.8125rem;
  line-height: 1.45;
}
.choice__icon { font-size: 1.05rem; }
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}
</style>
