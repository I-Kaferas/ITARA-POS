<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PayableSupplierRow, Supplier } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const router = useRouter()
const store = useBackofficeStore()
const search = ref('')
const showModal = ref(false)
const editing = ref<Supplier | null>(null)
const saving = ref(false)
const debtBySupplier = ref<Record<string, PayableSupplierRow>>({})
const form = ref({
  name: '',
  code: '',
  email: '',
  phone: '',
  contact_person: '',
  address_line: '',
  city: '',
  country: '',
  is_active: true,
})

onMounted(async () => {
  await Promise.all([store.loadSuppliers(), store.loadPayablesSummary()])
  for (const row of store.payablesSummary?.suppliers ?? []) {
    debtBySupplier.value[row.supplier_id] = row
  }
})

async function applySearch() {
  await store.loadSuppliers(search.value)
}

watchLiveSearch(search, applySearch)

function openDetail(item: Supplier) {
  router.push({ name: 'supplier-detail', params: { id: item.id } })
}

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', email: '', phone: '', contact_person: '', address_line: '', city: '', country: '', is_active: true }
  showModal.value = true
}

function openEdit(item: Supplier) {
  editing.value = item
  form.value = {
    name: item.name,
    code: item.code,
    email: item.email ?? '',
    phone: item.phone ?? '',
    contact_person: item.contact_person ?? '',
    address_line: item.address?.line1 ?? '',
    city: item.address?.city ?? '',
    country: item.address?.country ?? '',
    is_active: item.is_active,
  }
  showModal.value = true
}

async function save() {
  saving.value = true
  try {
    await store.saveSupplier({
      name: form.value.name,
      code: form.value.code,
      email: form.value.email || null,
      phone: form.value.phone || null,
      contact_person: form.value.contact_person || null,
      address: {
        line1: form.value.address_line || null,
        city: form.value.city || null,
        country: form.value.country || null,
      },
      is_active: form.value.is_active,
    }, editing.value?.id)
    await store.loadSuppliers(search.value)
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(item: Supplier) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteSupplier(item.id)
  await store.loadSuppliers(search.value)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.suppliers') }}</template>
    <template #subtitle>{{ t('suppliers.subtitle') }}</template>

    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <input v-model="search" type="search" :placeholder="t('common.search')" class="field max-w-xs" />
        <button class="btn-primary" @click="openCreate">+ {{ t('suppliers.add') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('suppliers.phone') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('auth.email') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.outstanding') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in store.suppliers" :key="item.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono text-slate-500">{{ item.code }}</td>
              <td class="px-4 py-3">
                <button class="font-medium text-brand-600" @click="openDetail(item)">{{ item.name }}</button>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ item.phone || '—' }}</td>
              <td class="px-4 py-3 text-slate-600">{{ item.email ?? '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">
                {{ formatMoney(debtBySupplier[item.id]?.debt ?? 0) }}
              </td>
              <td class="px-4 py-3"><StatusBadge :active="item.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(item)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(item)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.suppliers.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('suppliers.edit') : t('suppliers.add')"
      icon="suppliers"
      tone="brand"
      size="xl"
      @close="showModal = false"
    >
      <form class="supplier-form" @submit.prevent="save">
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="suppliers" :size="14" /></span>{{ t('org.name') }}</label>
          <input v-model="form.name" required class="field" />
        </div>
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="tag" :size="14" /></span>{{ t('org.code') }}</label>
          <input v-model="form.code" required class="field" />
        </div>
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="account" :size="14" /></span>{{ t('suppliers.contactPerson') }}</label>
          <input v-model="form.contact_person" class="field" />
        </div>
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="phone" :size="14" /></span>{{ t('common.phone') }}</label>
          <input v-model="form.phone" class="field" />
        </div>
        <div class="supplier-form__wide">
          <label class="field-label"><span class="field-icon"><AppIcon name="mail" :size="14" /></span>{{ t('auth.email') }}</label>
          <input v-model="form.email" type="email" class="field" />
        </div>
        <div class="supplier-form__wide">
          <label class="field-label"><span class="field-icon"><AppIcon name="pin" :size="14" /></span>{{ t('suppliers.street') }}</label>
          <input v-model="form.address_line" class="field" />
        </div>
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="building" :size="14" /></span>{{ t('suppliers.city') }}</label>
          <input v-model="form.city" class="field" />
        </div>
        <div>
          <label class="field-label"><span class="field-icon"><AppIcon name="store-pin" :size="14" /></span>{{ t('suppliers.country') }}</label>
          <input v-model="form.country" class="field" />
        </div>
        <label class="supplier-form__wide flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>
        <div class="app-modal__actions supplier-form__wide">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">
            <AppIcon name="check" :size="15" />
            {{ t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>

.field-label { display: flex; align-items: center; gap: 0.4rem; margin-bottom: 0.25rem; font-size: 0.875rem; font-weight: 500; }
.field-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.45rem;
  height: 1.45rem;
  flex-shrink: 0;
  border-radius: 0.4rem;
  background: #eef2ff;
  color: var(--color-brand-600);
}
.supplier-form { display: grid; grid-template-columns: 1fr 1fr; gap: 0.85rem 1rem; }
.supplier-form__wide { grid-column: 1 / -1; }
@media (max-width: 640px) {
  .supplier-form { grid-template-columns: 1fr; }
}

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
