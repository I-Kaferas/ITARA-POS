<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PurchaseOrder, Supplier } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

type ReturnRow = {
  id: string
  number: string
  supplier: string
  orderNumber: string
  type: string
  total: number
  status: string
  date: string
}

const STATUSES = ['draft', 'submitted', 'approved', 'completed', 'rejected', 'cancelled'] as const
const TYPES = ['refund', 'replacement', 'credit_note'] as const

const { t } = useI18n()
const store = useBackofficeStore()

const rows = ref<ReturnRow[]>([])
const suppliers = ref<Supplier[]>([])
const orders = ref<PurchaseOrder[]>([])
const status = ref('')
const type = ref('')
const search = ref('')
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const showCreate = ref(false)
const form = ref(emptyForm())

const filteredRows = computed(() => {
  const query = search.value.trim().toLowerCase()
  return rows.value.filter((row) => {
    if (status.value && row.status !== status.value) return false
    if (type.value && row.type !== type.value) return false
    if (!query) return true
    return [row.number, row.supplier, row.orderNumber, row.type, row.status].join(' ').toLowerCase().includes(query)
  })
})

function emptyForm() {
  return { supplier_id: '', purchase_order_id: '', type: 'refund' as (typeof TYPES)[number], notes: '' }
}

function textOf(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function mapRow(raw: Record<string, unknown>): ReturnRow {
  const supplier = raw.supplier as { name?: string } | null | undefined
  const order = raw.purchase_order as { order_number?: string; number?: string } | null | undefined
  const total = raw.total ?? raw.total_amount ?? raw.amount
  return {
    id: textOf(raw.id),
    number: textOf(raw.number ?? raw.return_number),
    supplier: supplier?.name || textOf(raw.supplier_name),
    orderNumber: order?.order_number || order?.number || textOf(raw.order_number ?? raw.po_number),
    type: textOf(raw.type ?? raw.return_type),
    total: typeof total === 'number' ? total : Number(total ?? 0),
    status: textOf(raw.status),
    date: textOf(raw.created_at ?? raw.returned_at ?? raw.date),
  }
}

function statusVariant(value: string): 'success' | 'warning' | 'neutral' | 'brand' {
  if (value === 'approved' || value === 'completed') return 'success'
  if (value === 'submitted') return 'brand'
  if (value === 'rejected' || value === 'cancelled') return 'neutral'
  return 'warning'
}

onMounted(async () => {
  await store.loadSuppliers()
  suppliers.value = store.suppliers
  await store.loadPurchaseOrders()
  orders.value = store.purchaseOrders
  await load()
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params: Record<string, string> = {}
    if (status.value) params.status = status.value
    if (type.value) params.type = type.value
    if (search.value.trim()) params.search = search.value.trim()
    rows.value = (await store.loadPurchaseReturns(params)).map(mapRow)
  } catch (err) {
    rows.value = []
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  form.value = {
    ...emptyForm(),
    supplier_id: suppliers.value[0]?.id ?? '',
    purchase_order_id: '',
  }
  error.value = ''
  showCreate.value = true
}

async function submitCreate() {
  saving.value = true
  error.value = ''
  try {
    await store.createPurchaseReturn({
      supplier_id: form.value.supplier_id || undefined,
      purchase_order_id: form.value.purchase_order_id || undefined,
      type: form.value.type,
      notes: form.value.notes || undefined,
    })
    showCreate.value = false
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function act(row: ReturnRow, action: 'submit' | 'approve' | 'reject') {
  saving.value = true
  error.value = ''
  try {
    await store.actPurchaseReturn(row.id, action)
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <PurchasingLayout>
    <p v-if="error && !showCreate" class="mb-3 text-sm text-red-600">{{ error }}</p>

    <section class="returns">
      <div class="returns__toolbar">
        <h2>{{ t('purchases.hub.returnsPage.title') }}</h2>
        <button type="button" class="btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('purchases.hub.returnsPage.new') }}
        </button>
      </div>

      <div class="returns__filters">
        <select v-model="status" class="field" @change="load">
          <option value="">{{ t('purchases.hub.returnsPage.allStatuses') }}</option>
          <option v-for="key in STATUSES" :key="key" :value="key">{{ t(`purchases.hub.returnsPage.statuses.${key}`) }}</option>
        </select>
        <select v-model="type" class="field" @change="load">
          <option value="">{{ t('purchases.hub.returnsPage.allTypes') }}</option>
          <option v-for="key in TYPES" :key="key" :value="key">{{ t(`purchases.hub.returnsPage.types.${key}`) }}</option>
        </select>
        <input
          v-model="search"
          class="field returns__search"
          type="search"
          :placeholder="t('purchases.hub.returnsPage.search')"
        />
      </div>

      <div class="returns__table">
        <table>
          <thead>
            <tr>
              <th>{{ t('purchases.hub.returnsPage.number') }}</th>
              <th>{{ t('purchases.hub.returnsPage.supplier') }}</th>
              <th>{{ t('purchases.hub.returnsPage.poNumber') }}</th>
              <th>{{ t('purchases.hub.returnsPage.type') }}</th>
              <th class="is-right">{{ t('purchases.hub.returnsPage.total') }}</th>
              <th>{{ t('purchases.hub.returnsPage.status') }}</th>
              <th>{{ t('purchases.hub.returnsPage.date') }}</th>
              <th>{{ t('purchases.hub.returnsPage.actions') }}</th>
            </tr>
          </thead>
          <tbody v-if="filteredRows.length">
            <tr v-for="row in filteredRows" :key="row.id">
              <td class="returns__number">{{ row.number || '—' }}</td>
              <td>{{ row.supplier || '—' }}</td>
              <td>{{ row.orderNumber || '—' }}</td>
              <td>{{ row.type ? t(`purchases.hub.returnsPage.types.${row.type}`) : '—' }}</td>
              <td class="is-right">{{ formatMoney(row.total) }}</td>
              <td>
                <Badge v-if="row.status" :variant="statusVariant(row.status)">
                  {{ t(`purchases.hub.returnsPage.statuses.${row.status}`) }}
                </Badge>
                <span v-else>—</span>
              </td>
              <td>{{ row.date ? formatDate(row.date) : '—' }}</td>
              <td class="returns__actions">
                <button v-if="row.status === 'draft'" type="button" class="link" :disabled="saving" @click="act(row, 'submit')">{{ t('purchases.submit') }}</button>
                <button v-if="row.status === 'submitted'" type="button" class="link" :disabled="saving" @click="act(row, 'approve')">{{ t('purchases.approve') }}</button>
                <button v-if="row.status === 'submitted'" type="button" class="link-danger" :disabled="saving" @click="act(row, 'reject')">{{ t('purchases.hub.reject') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!loading && !filteredRows.length" class="returns__empty">{{ t('purchases.hub.returnsPage.empty') }}</p>
      </div>
    </section>

    <AppModal
      :open="showCreate"
      :title="t('purchases.hub.returnsPage.new')"
      icon="transfer"
      @close="showCreate = false"
    >
      <form class="space-y-3" @submit.prevent="submitCreate">
        <div>
          <FieldLabel icon="suppliers">{{ t('purchases.hub.returnsPage.supplier') }}</FieldLabel>
          <select v-model="form.supplier_id" class="field" required>
            <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="note">{{ t('purchases.hub.returnsPage.poNumber') }}</FieldLabel>
          <select v-model="form.purchase_order_id" class="field">
            <option value="">{{ t('common.optional') }}</option>
            <option v-for="order in orders" :key="order.id" :value="order.id">{{ order.order_number }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('purchases.hub.returnsPage.type') }}</FieldLabel>
          <select v-model="form.type" class="field">
            <option v-for="key in TYPES" :key="key" :value="key">{{ t(`purchases.hub.returnsPage.types.${key}`) }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="note">{{ t('purchases.hub.reason') }}</FieldLabel>
          <input v-model="form.notes" class="field" />
        </div>
        <p v-if="error" class="form-error">{{ error }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showCreate = false">
            <AppIcon name="close" :size="16" /> {{ t('common.cancel') }}
          </button>
          <button type="submit" class="btn-primary" :disabled="saving">
            <AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </PurchasingLayout>
</template>

<style scoped>
.returns {
  overflow: hidden;
  border-radius: 12px;
  background: #fff;
  border: 1px solid var(--color-border, #e2e8f0);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
}

.returns__toolbar,
.returns__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
  padding: 0.9rem 1rem;
}

.returns__toolbar {
  justify-content: space-between;
  border-bottom: 1px solid var(--color-border, #e2e8f0);
}

.returns__toolbar h2 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.returns__toolbar .btn-primary {
  min-height: 2.4rem;
}

.returns__filters .field {
  min-width: 11rem;
  min-height: 2.5rem;
}

.returns__search {
  flex: 1 1 16rem;
}

.returns__table {
  overflow-x: auto;
}

.returns table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.returns th,
.returns td {
  padding: 0.8rem 1rem;
  text-align: left;
  border-top: 1px solid var(--color-border, #e2e8f0);
}

.returns th {
  font-weight: 650;
  color: var(--color-text-secondary, #475569);
  background: var(--color-canvas, #f8fafc);
}

.returns td.is-right,
.returns th.is-right {
  text-align: right;
}

.returns__number {
  font-variant-numeric: tabular-nums;
  font-weight: 650;
}

.returns__actions {
  display: flex;
  gap: 0.6rem;
  white-space: nowrap;
}

.returns__empty {
  margin: 0;
  padding: 2.5rem 1rem;
  text-align: center;
  color: var(--color-text-muted, #64748b);
}
</style>
