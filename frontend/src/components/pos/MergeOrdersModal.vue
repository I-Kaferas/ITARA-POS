<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppModal from '../ui/AppModal.vue'
import LoadingBlock from '../ui/LoadingBlock.vue'
import { api, extractApiErrorMessage } from '../../api/client'
import { formatMoney } from '../../utils/money'

export interface MergeableSaleSummary {
  id: string
  reference: string
  total: number
  currency?: string
  customer?: { id: string; name: string } | null
  table?: { id: string; name: string; code?: string } | null
  item_count?: number
}

const props = defineProps<{
  open: boolean
  sale: MergeableSaleSummary | null
}>()

const emit = defineEmits<{
  close: []
  merged: [saleId: string]
}>()

const { t } = useI18n()

type Step = 'pick' | 'preview'

const step = ref<Step>('pick')
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const candidates = ref<MergeableSaleSummary[]>([])
const sourceId = ref('')
const finalTableId = ref<string>('')
const keepCustomerId = ref<string>('')
const confirmDifferentCustomers = ref(false)

const preview = ref<{
  source: MergeableSaleSummary
  target: MergeableSaleSummary
  customers_differ: boolean
  tables: { id: string; name: string; code?: string }[]
  final_table_id?: string | null
  customer_id?: string | null
  customer?: { id: string; name: string } | null
  items: { product_name?: string | null; quantity: number; unit_price: number }[]
  totals: { total: number; currency?: string; subtotal: number; tax_total: number; discount_total: number }
} | null>(null)

const canContinue = computed(() => Boolean(sourceId.value))
const needsCustomerConfirm = computed(() => Boolean(preview.value?.customers_differ) && !confirmDifferentCustomers.value)

watch(
  () => [props.open, props.sale?.id] as const,
  async ([open]) => {
    if (!open || !props.sale) return
    step.value = 'pick'
    sourceId.value = ''
    finalTableId.value = ''
    keepCustomerId.value = ''
    confirmDifferentCustomers.value = false
    preview.value = null
    error.value = ''
    await loadCandidates()
  },
)

async function loadCandidates() {
  if (!props.sale) return
  loading.value = true
  error.value = ''
  try {
    const res = await api.get<{ data: MergeableSaleSummary[] }>(`/sales/${props.sale.id}/merge-candidates`)
    candidates.value = res.data ?? []
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.merge.loadError'))
  } finally {
    loading.value = false
  }
}

async function loadPreview() {
  if (!props.sale || !sourceId.value) return
  saving.value = true
  error.value = ''
  try {
    const res = await api.post<{ data: NonNullable<typeof preview.value> }>(`/sales/${props.sale.id}/merge/preview`, {
      source_sale_id: sourceId.value,
      table_id: finalTableId.value || undefined,
      customer_id: keepCustomerId.value || undefined,
      confirm_different_customers: confirmDifferentCustomers.value || undefined,
    })
    preview.value = res.data
    finalTableId.value = res.data.final_table_id ?? ''
    keepCustomerId.value = res.data.customer_id ?? ''
    step.value = 'preview'
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.merge.previewError'))
  } finally {
    saving.value = false
  }
}

async function confirmMerge() {
  if (!props.sale || !sourceId.value || needsCustomerConfirm.value) return
  saving.value = true
  error.value = ''
  try {
    const res = await api.post<{ data: { id: string } }>(`/sales/${props.sale.id}/merge`, {
      source_sale_id: sourceId.value,
      table_id: finalTableId.value || null,
      customer_id: keepCustomerId.value || undefined,
      confirm_different_customers: confirmDifferentCustomers.value || undefined,
    })
    emit('merged', res.data.id)
    emit('close')
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.merge.saveError'))
  } finally {
    saving.value = false
  }
}

function close() {
  emit('close')
}
</script>

<template>
  <AppModal
    :open="open"
    :title="t('pointOfSale.merge.title')"
    size="md"
    icon="layers"
    @close="close"
  >
    <div class="merge-modal">
      <p v-if="error" class="merge-error">{{ error }}</p>

      <template v-if="step === 'pick'">
        <div v-if="sale" class="merge-card">
          <span>{{ t('pointOfSale.merge.current') }}</span>
          <strong>{{ sale.reference }}</strong>
          <small>
            {{ sale.table?.name || t('pointOfSale.merge.counter') }}
            · {{ formatMoney(sale.total, sale.currency) }}
          </small>
        </div>

        <p class="merge-hint">{{ t('pointOfSale.merge.pickHint') }}</p>
        <LoadingBlock v-if="loading" variant="list" :rows="4" :label="t('common.loading')" />
        <div v-else-if="!candidates.length" class="merge-empty">{{ t('pointOfSale.merge.noCandidates') }}</div>
        <label v-for="candidate in candidates" :key="candidate.id" class="merge-choice">
          <input v-model="sourceId" type="radio" :value="candidate.id">
          <span>
            <strong>{{ candidate.reference }}</strong>
            <small>
              {{ candidate.table?.name || t('pointOfSale.merge.counter') }}
              · {{ formatMoney(candidate.total, candidate.currency) }}
              <template v-if="candidate.customer"> · {{ candidate.customer.name }}</template>
            </small>
          </span>
        </label>
      </template>

      <template v-else-if="preview">
        <div class="merge-stack">
          <div class="merge-card">
            <strong>{{ preview.target.reference }}</strong>
            <small>{{ preview.target.table?.name || t('pointOfSale.merge.counter') }} · {{ formatMoney(preview.target.total) }}</small>
          </div>
          <div class="merge-plus">+</div>
          <div class="merge-card">
            <strong>{{ preview.source.reference }}</strong>
            <small>{{ preview.source.table?.name || t('pointOfSale.merge.counter') }} · {{ formatMoney(preview.source.total) }}</small>
          </div>
        </div>

        <div class="merge-result">
          <h4>{{ t('pointOfSale.merge.result') }}</h4>
          <ul>
            <li v-for="(line, index) in preview.items" :key="index">
              <span>{{ line.product_name || t('pointOfSale.merge.item') }}</span>
              <strong>× {{ line.quantity }}</strong>
            </li>
          </ul>
          <p class="merge-total">{{ t('pointOfSale.merge.total') }} : {{ formatMoney(preview.totals.total, preview.totals.currency) }}</p>
        </div>

        <div v-if="preview.tables.length" class="merge-section">
          <p class="merge-label">{{ t('pointOfSale.merge.finalTable') }}</p>
          <label v-for="table in preview.tables" :key="table.id" class="merge-choice">
            <input v-model="finalTableId" type="radio" :value="table.id">
            <span>{{ table.name }}</span>
          </label>
        </div>

        <div v-if="preview.customers_differ" class="merge-warning">
          <p>{{ t('pointOfSale.merge.customersDiffer') }}</p>
          <label class="merge-choice">
            <input v-model="keepCustomerId" type="radio" :value="preview.target.customer?.id || ''">
            <span>{{ preview.target.customer?.name || '—' }} ({{ preview.target.reference }})</span>
          </label>
          <label class="merge-choice">
            <input v-model="keepCustomerId" type="radio" :value="preview.source.customer?.id || ''">
            <span>{{ preview.source.customer?.name || '—' }} ({{ preview.source.reference }})</span>
          </label>
          <label class="merge-choice">
            <input v-model="confirmDifferentCustomers" type="checkbox">
            <span>{{ t('pointOfSale.merge.confirmCustomers') }}</span>
          </label>
        </div>
      </template>

      <div class="app-modal__actions">
        <button type="button" class="btn-secondary" @click="step === 'preview' ? (step = 'pick') : close()">
          {{ step === 'preview' ? t('common.back') : t('common.cancel') }}
        </button>
        <button
          v-if="step === 'pick'"
          type="button"
          class="btn-primary"
          :disabled="!canContinue || saving || loading"
          @click="loadPreview"
        >
          {{ t('common.continue') }}
        </button>
        <button
          v-else
          type="button"
          class="btn-primary"
          :disabled="saving || needsCustomerConfirm"
          @click="confirmMerge"
        >
          {{ t('pointOfSale.merge.confirm') }}
        </button>
      </div>
    </div>
  </AppModal>
</template>

<style scoped>
.merge-modal { display: grid; gap: 12px; }
.merge-error {
  margin: 0;
  padding: 10px 12px;
  border-radius: 8px;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 13px;
}
.merge-card {
  display: grid;
  gap: 2px;
  padding: 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #f8fafc;
}
.merge-card span,
.merge-card small,
.merge-choice small {
  color: #64748b;
  font-size: 12px;
}
.merge-hint, .merge-label { margin: 0; font-size: 13px; color: #475569; }
.merge-choice {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  min-height: 40px;
  padding: 8px 10px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.merge-choice span { display: grid; gap: 2px; }
.merge-empty { color: #64748b; font-size: 13px; padding: 8px 0; }
.merge-stack { display: grid; gap: 8px; }
.merge-plus { text-align: center; font-weight: 700; color: #64748b; }
.merge-result {
  border: 1px solid #dbeafe;
  background: #eff6ff;
  border-radius: 8px;
  padding: 12px;
}
.merge-result h4 { margin: 0 0 8px; font-size: 13px; }
.merge-result ul { margin: 0; padding: 0; list-style: none; display: grid; gap: 6px; }
.merge-result li { display: flex; justify-content: space-between; gap: 8px; font-size: 13px; }
.merge-total { margin: 10px 0 0; font-weight: 700; }
.merge-section { display: grid; gap: 8px; }
.merge-warning {
  display: grid;
  gap: 8px;
  padding: 12px;
  border-radius: 8px;
  background: #fffbeb;
  border: 1px solid #fde68a;
}
.merge-warning p { margin: 0; font-size: 13px; color: #92400e; }
</style>
