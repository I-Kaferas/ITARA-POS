<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../composables/useConfirm'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import type { Promotion, PromotionType } from '../../types'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../utils/listFilters'
import { parseMoneyInput } from '../../utils/money'

const { t, locale } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const showModal = ref(false)
const editing = ref<Promotion | null>(null)
const saving = ref(false)

const defaultForm = () => ({
  name: '',
  code: '',
  type: 'percentage_discount' as PromotionType,
  description: '',
  store_id: '',
  category_id: '',
  starts_at: '',
  ends_at: '',
  min_quantity: 1,
  max_uses: null as number | null,
  priority: 0,
  discount_percent: null as number | null,
  discount_amount: '',
  buy_quantity: 2,
  get_quantity: 1,
  bundle_price: '',
  schedule_days: [] as number[],
  schedule_time_start: '18:00',
  schedule_time_end: '20:00',
  customer_ids: [] as string[],
  product_id: '',
  is_active: true,
})

const form = ref(defaultForm())
const filters = ref<ListFilters>(emptyListFilters('all'))
const typeOptions = computed(() =>
  store.promotionTypes.map(type => ({
    value: type.value,
    label: locale.value === 'fr' ? type.label_fr : type.label,
  })),
)
const filtered = computed(() => store.promotions.filter(promotion =>
  matchesSearch(`${promotion.name} ${promotion.code ?? ''} ${typeLabel(promotion.type)}`, filters.value.search)
  && matchesActive(promotion.is_active, filters.value.active)
  && (!filters.value.status || promotion.type === filters.value.status),
))

const weekDays = [
  { value: 1, label: t('promotions.days.mon') },
  { value: 2, label: t('promotions.days.tue') },
  { value: 3, label: t('promotions.days.wed') },
  { value: 4, label: t('promotions.days.thu') },
  { value: 5, label: t('promotions.days.fri') },
  { value: 6, label: t('promotions.days.sat') },
  { value: 7, label: t('promotions.days.sun') },
]

onMounted(async () => {
  await Promise.all([
    store.loadPromotions(),
    store.loadPromotionTypes(),
    store.loadCustomers(),
    store.companies.length ? Promise.resolve() : store.loadCompanies(),
  ])
  if (store.companies[0]) {
    await store.loadBranches(store.companies[0].id)
    if (store.branches[0]) {
      await store.loadStores(store.branches[0].id)
    }
    await store.loadCatalogs(store.companies[0].id)
  }
  if (store.catalogs[0]) {
    await Promise.all([
      store.loadCategories(store.catalogs[0].id),
      store.loadProducts(store.catalogs[0].id),
    ])
  }
})

function typeLabel(type: string) {
  const meta = store.promotionTypes.find(t => t.value === type)
  if (!meta) return type
  return locale.value === 'fr' ? meta.label_fr : meta.label
}

const needsPercent = computed(() =>
  ['percentage_discount', 'quantity_discount', 'category_discount', 'customer_discount', 'buy_x_get_y'].includes(form.value.type),
)
const needsAmount = computed(() => ['fixed_discount', 'time_based'].includes(form.value.type))
const needsCategory = computed(() => form.value.type === 'category_discount')
const needsBuyGet = computed(() => form.value.type === 'buy_x_get_y')
const needsBundle = computed(() => form.value.type === 'bundle')
const needsCustomers = computed(() => form.value.type === 'customer_discount')
const needsSchedule = computed(() => form.value.type === 'time_based')
const needsProduct = computed(() =>
  ['percentage_discount', 'fixed_discount', 'buy_x_get_y', 'bundle', 'quantity_discount', 'time_based'].includes(form.value.type),
)

function openCreate() {
  editing.value = null
  form.value = defaultForm()
  showModal.value = true
}

function openEdit(promotion: Promotion) {
  editing.value = promotion
  form.value = {
    ...defaultForm(),
    name: promotion.name,
    code: promotion.code ?? '',
    type: promotion.type,
    description: promotion.description ?? '',
    store_id: promotion.store_id ?? '',
    category_id: promotion.category_id ?? '',
    starts_at: promotion.starts_at?.slice(0, 16) ?? '',
    ends_at: promotion.ends_at?.slice(0, 16) ?? '',
    min_quantity: promotion.min_quantity,
    max_uses: promotion.max_uses ?? null,
    priority: promotion.priority,
    discount_percent: promotion.discount_percent != null ? Number(promotion.discount_percent) : null,
    discount_amount: majorMoney(promotion.discount_amount),
    buy_quantity: promotion.buy_quantity ?? 2,
    get_quantity: promotion.get_quantity ?? 1,
    bundle_price: majorMoney(promotion.bundle_price),
    schedule_days: promotion.schedule?.days_of_week ?? [],
    schedule_time_start: promotion.schedule?.time_start ?? '18:00',
    schedule_time_end: promotion.schedule?.time_end ?? '20:00',
    customer_ids: promotion.customers?.map(c => c.customer_id) ?? [],
    product_id: promotion.items?.[0]?.product_id ?? '',
    is_active: promotion.is_active,
  }
  showModal.value = true
}

function majorMoney(amount?: number | null) {
  if (amount == null) return ''
  return String(amount / 100)
}

function moneyOrNull(value: string) {
  const trimmed = value.trim()
  if (!trimmed) return null
  return parseMoneyInput(trimmed)
}

function buildPayload() {
  const payload: Record<string, unknown> = {
    name: form.value.name,
    code: form.value.code || null,
    type: form.value.type,
    description: form.value.description || null,
    store_id: form.value.store_id || null,
    category_id: form.value.category_id || null,
    starts_at: form.value.starts_at || null,
    ends_at: form.value.ends_at || null,
    min_quantity: form.value.min_quantity,
    max_uses: form.value.max_uses,
    priority: form.value.priority,
    discount_percent: form.value.type === 'time_based' ? null : form.value.discount_percent,
    discount_amount: moneyOrNull(form.value.discount_amount),
    buy_quantity: form.value.buy_quantity,
    get_quantity: form.value.get_quantity,
    bundle_price: moneyOrNull(form.value.bundle_price),
    is_active: form.value.is_active,
    customer_ids: form.value.customer_ids,
  }

  if (needsSchedule.value) {
    payload.schedule = {
      days_of_week: form.value.schedule_days,
      time_start: form.value.schedule_time_start.slice(0, 5),
      time_end: form.value.schedule_time_end.slice(0, 5),
    }
  }

  if (needsProduct.value && form.value.product_id) {
    const role = form.value.type === 'buy_x_get_y' ? 'trigger' : form.value.type === 'bundle' ? 'bundle' : 'target'
    const items = [{ product_id: form.value.product_id, role, quantity: 1 }]
    if (form.value.type === 'buy_x_get_y') {
      items.push({ product_id: form.value.product_id, role: 'reward', quantity: 1 })
    }
    payload.items = items
  } else {
    payload.items = []
  }

  return payload
}

async function save() {
  saving.value = true
  try {
    await store.savePromotion(buildPayload(), editing.value?.id)
    await store.loadPromotions()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(promotion: Promotion) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deletePromotion(promotion.id)
  await store.loadPromotions()
}

function formatDate(value?: string | null) {
  if (!value) return '—'
  return new Date(value).toLocaleDateString()
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('promotions.title') }}</template>
    <template #subtitle>{{ t('promotions.subtitle') }}</template>

    <div class="space-y-4">
      <div class="flex justify-end">
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">
          + {{ t('promotions.add') }}
        </button>
      </div>

      <ModuleFilters
        v-model="filters"
        :statuses="typeOptions"
        :show-period="false"
        show-search
        show-active
        show-status
      />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('promotions.type') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('promotions.period') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('promotions.minQty') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('promotions.maxUses') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.active') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="promotion in filtered" :key="promotion.id" class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <div class="font-medium">{{ promotion.name }}</div>
                <div v-if="promotion.code" class="text-xs text-slate-500 font-mono">{{ promotion.code }}</div>
              </td>
              <td class="px-4 py-3">{{ typeLabel(promotion.type) }}</td>
              <td class="px-4 py-3 text-xs">
                {{ formatDate(promotion.starts_at) }} → {{ formatDate(promotion.ends_at) }}
              </td>
              <td class="px-4 py-3">{{ promotion.min_quantity }}</td>
              <td class="px-4 py-3">
                {{ promotion.uses_count ?? 0 }} / {{ promotion.max_uses ?? '∞' }}
              </td>
              <td class="px-4 py-3">{{ promotion.is_active ? '✓' : '—' }}</td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(promotion)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(promotion)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('promotions.edit') : t('promotions.add')"
      icon="percent"
      tone="accent"
      size="lg"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" /></div>
          <div><FieldLabel icon="tag">{{ t('org.code') }}</FieldLabel><input v-model="form.code" class="field" /></div>
        </div>

        <div>
          <FieldLabel icon="layers">{{ t('promotions.type') }}</FieldLabel>
          <select v-model="form.type" class="field">
            <option v-for="type in store.promotionTypes" :key="type.value" :value="type.value">
              {{ locale === 'fr' ? type.label_fr : type.label }}
            </option>
          </select>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="calendar">{{ t('promotions.startDate') }}</FieldLabel>
            <input v-model="form.starts_at" type="datetime-local" class="field" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('promotions.endDate') }}</FieldLabel>
            <input v-model="form.ends_at" type="datetime-local" class="field" />
          </div>
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <div>
            <FieldLabel icon="package">{{ t('promotions.minQty') }}</FieldLabel>
            <input v-model.number="form.min_quantity" type="number" min="1" class="field" />
          </div>
          <div>
            <FieldLabel icon="calculator">{{ t('promotions.maxUses') }}</FieldLabel>
            <input v-model.number="form.max_uses" type="number" min="1" class="field" placeholder="∞" />
          </div>
          <div>
            <FieldLabel icon="layers">{{ t('promotions.priority') }}</FieldLabel>
            <input v-model.number="form.priority" type="number" class="field" />
          </div>
        </div>

        <div v-if="needsPercent" class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="percent">{{ t('promotions.discountPercent') }}</FieldLabel>
            <input v-model.number="form.discount_percent" type="number" step="0.01" min="0" max="100" class="field" :placeholder="form.type === 'buy_x_get_y' ? t('promotions.freePercentHint') : '10'" />
          </div>
        </div>

        <div v-if="needsAmount" class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="coins">{{ form.type === 'time_based' ? t('promotions.specialPrice') : t('promotions.discountAmount') }}</FieldLabel>
            <input v-model="form.discount_amount" type="text" inputmode="decimal" class="field" />
            <p v-if="form.type === 'time_based'" class="mt-1 text-xs text-slate-500">{{ t('promotions.specialPriceHint') }}</p>
          </div>
        </div>

        <div v-if="needsBuyGet" class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="package">{{ t('promotions.buyQty') }}</FieldLabel>
            <input v-model.number="form.buy_quantity" type="number" min="1" class="field" />
          </div>
          <div>
            <FieldLabel icon="package">{{ t('promotions.getQty') }}</FieldLabel>
            <input v-model.number="form.get_quantity" type="number" min="1" class="field" />
          </div>
        </div>

        <div v-if="needsBundle">
          <FieldLabel icon="coins">{{ t('promotions.bundlePrice') }}</FieldLabel>
          <input v-model="form.bundle_price" type="text" inputmode="decimal" class="field" />
        </div>

        <div v-if="needsCategory">
          <FieldLabel icon="catalog">{{ t('catalog.tabs.categories') }}</FieldLabel>
          <select v-model="form.category_id" class="field">
            <option value="">—</option>
            <option v-for="cat in store.categories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
          </select>
        </div>

        <div v-if="needsProduct">
          <FieldLabel icon="products">{{ t('nav.products') }}</FieldLabel>
          <select v-model="form.product_id" class="field">
            <option value="">—</option>
            <option v-for="product in store.products" :key="product.id" :value="product.id">{{ product.name }}</option>
          </select>
        </div>

        <div v-if="needsCustomers">
          <FieldLabel icon="customers">{{ t('promotions.eligibleCustomers') }}</FieldLabel>
          <select v-model="form.customer_ids" multiple class="field min-h-28">
            <option v-for="customer in store.customers" :key="customer.id" :value="customer.id">{{ customer.name }}</option>
          </select>
        </div>

        <div v-if="needsSchedule" class="space-y-3 rounded-lg border border-slate-200 p-3">
          <p class="text-sm font-medium">{{ t('promotions.schedule') }}</p>
          <p class="text-xs text-slate-500">{{ t('promotions.specialPriceHint') }}</p>
          <div class="flex flex-wrap gap-2">
            <label v-for="day in weekDays" :key="day.value" class="flex items-center gap-1 text-sm">
              <input v-model="form.schedule_days" type="checkbox" :value="day.value" class="rounded" />
              {{ day.label }}
            </label>
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <div>
              <FieldLabel icon="calendar">{{ t('promotions.timeStart') }}</FieldLabel>
              <input v-model="form.schedule_time_start" type="time" class="field" />
            </div>
            <div>
              <FieldLabel icon="calendar">{{ t('promotions.timeEnd') }}</FieldLabel>
              <input v-model="form.schedule_time_end" type="time" class="field" />
            </div>
          </div>
        </div>

        <div>
          <FieldLabel icon="stores">{{ t('nav.stores') }}</FieldLabel>
          <select v-model="form.store_id" class="field">
            <option value="">{{ t('promotions.allStores') }}</option>
            <option v-for="s in store.stores" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>

        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
</style>
