<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { CashierShift, ShiftSummary } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const shiftId = computed(() => route.params.id as string)
const shift = ref<CashierShift | null>(null)
const summary = ref<ShiftSummary | null>(null)
const loading = ref(true)
const error = ref('')
const showClose = ref(false)
const actualCash = ref('')
const closingNotes = ref('')
const varianceReason = ref('')
const saving = ref(false)

const isMineOpen = computed(() =>
  Boolean(shift.value && store.currentCashierShift?.id === shift.value.id && shift.value.status === 'open'),
)

const kpiCards = computed(() => {
  const s = summary.value ?? shift.value
  if (!s) return []
  return [
    { label: t('pointOfSale.shifts.openingBalance'), value: formatMoney(s.opening_balance) },
    { label: t('pointOfSale.shifts.sales'), value: formatMoney(s.sales_total) },
    { label: t('pointOfSale.shifts.refunds'), value: formatMoney(s.refunds_total) },
    { label: t('pointOfSale.shifts.cashIn'), value: formatMoney(s.cash_in_total) },
    { label: t('pointOfSale.shifts.cashOut'), value: formatMoney(s.cash_out_total) },
    { label: t('pointOfSale.shifts.expenses'), value: formatMoney(s.expenses_total) },
    { label: t('pointOfSale.shifts.expected'), value: formatMoney(s.expected_cash) },
    { label: t('pointOfSale.shifts.actualCash'), value: s.actual_cash == null ? '—' : formatMoney(s.actual_cash) },
    { label: t('pointOfSale.shifts.variance'), value: s.variance == null ? '—' : formatMoney(s.variance) },
  ]
})

async function load() {
  if (!shiftId.value) return
  loading.value = true
  error.value = ''
  try {
    await store.loadCurrentCashierShift()
    const res = await store.loadCashierShiftDetail(shiftId.value)
    shift.value = res.data
    summary.value = res.summary
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.detailError'))
    shift.value = null
    summary.value = null
  } finally {
    loading.value = false
  }
}

function openCloseModal() {
  actualCash.value = summary.value
    ? String((summary.value.expected_cash ?? 0) / 100)
    : shift.value
      ? String((shift.value.expected_cash ?? 0) / 100)
      : ''
  closingNotes.value = ''
  varianceReason.value = ''
  showClose.value = true
}

async function confirmClose() {
  const registerId = shift.value?.cash_register_id
  if (!registerId) return
  saving.value = true
  error.value = ''
  try {
    const expected = summary.value?.expected_cash ?? shift.value?.expected_cash ?? 0
    const actual = Math.round((Number(actualCash.value.replace(',', '.')) || 0) * 100)
    if (actual !== expected && !varianceReason.value.trim()) {
      error.value = t('pos.varianceReasonRequired')
      saving.value = false
      return
    }
    await store.closeCashierShift(registerId, {
      actual_cash: Number(actualCash.value.replace(',', '.')) || 0,
      closing_notes: closingNotes.value || undefined,
      variance_reason: varianceReason.value.trim() || undefined,
    })
    showClose.value = false
    await load()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.closeError'))
  } finally {
    saving.value = false
  }
}

function movementLabel(type: string) {
  const key = `pointOfSale.shifts.movements.${type}`
  const label = t(key)
  return label === key ? type : label
}

onMounted(load)
watch(shiftId, load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('pointOfSale.shifts.detailTitle') }}</template>
    <template #subtitle>{{ shift?.cash_register?.name ?? t('pointOfSale.shifts.subtitle') }}</template>

    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <button type="button" class="ui-btn ui-btn--secondary" @click="router.push({ name: 'pos-shifts' })">
        ← {{ t('nav.posShifts') }}
      </button>
      <button
        v-if="isMineOpen"
        type="button"
        class="ui-btn ui-btn--primary"
        @click="openCloseModal"
      >
        {{ t('pointOfSale.shifts.closeAction') }}
      </button>
    </div>

    <p v-if="error && shift" class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>
    <div v-if="loading" class="py-10 text-center text-sm text-slate-500">{{ t('common.loading') }}</div>

    <template v-else-if="shift">
      <div class="mb-4 rounded-xl border border-slate-200 bg-white p-4">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div class="mb-2">
              <StatusBadge
                :active="shift.status === 'open'"
                :label="shift.status === 'open' ? t('pointOfSale.shifts.open') : t('pointOfSale.shifts.closed')"
              />
            </div>
            <p class="m-0 text-sm text-slate-600">
              <strong>{{ t('pointOfSale.shifts.cashier') }}:</strong> {{ shift.cashier?.name ?? '—' }}
            </p>
            <p class="m-0 mt-1 text-sm text-slate-600">
              <strong>{{ t('pointOfSale.shifts.register') }}:</strong> {{ shift.cash_register?.name ?? shift.cash_register_id }}
              <span v-if="shift.cash_register?.store?.name"> · {{ shift.cash_register.store.name }}</span>
            </p>
            <p class="m-0 mt-1 text-sm text-slate-500">
              {{ t('pointOfSale.shifts.openedAt') }} {{ formatDate(shift.opened_at) }}
              <span v-if="shift.closed_at"> · {{ t('pointOfSale.shifts.closedAt') }} {{ formatDate(shift.closed_at) }}</span>
            </p>
          </div>
          <div v-if="shift.opening_notes || shift.closing_notes" class="max-w-md text-sm text-slate-600">
            <p v-if="shift.opening_notes" class="m-0"><strong>{{ t('pointOfSale.shifts.openingNotes') }}:</strong> {{ shift.opening_notes }}</p>
            <p v-if="shift.closing_notes" class="m-0 mt-1"><strong>{{ t('pointOfSale.shifts.closingNotes') }}:</strong> {{ shift.closing_notes }}</p>
          </div>
        </div>
      </div>

      <div class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <div v-for="card in kpiCards" :key="card.label" class="rounded-xl border border-slate-200 bg-white px-4 py-3">
          <p class="m-0 text-xs font-medium uppercase tracking-wide text-slate-500">{{ card.label }}</p>
          <p class="m-0 mt-1 text-lg font-semibold text-slate-900">{{ card.value }}</p>
        </div>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('pointOfSale.shifts.movementsTitle') }}</h3>
        </div>
        <table v-if="shift.movements?.length" class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.shifts.movementType') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.shifts.notes') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.shifts.performedBy') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="mv in shift.movements" :key="mv.id">
              <td class="px-4 py-3 text-slate-500">{{ formatDate(mv.occurred_at) }}</td>
              <td class="px-4 py-3">{{ movementLabel(mv.movement_type) }}</td>
              <td class="px-4 py-3">{{ mv.description || mv.reference || '—' }}</td>
              <td class="px-4 py-3">{{ mv.performedBy?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(mv.amount) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="px-4 py-8 text-center text-slate-500">{{ t('pointOfSale.shifts.noMovements') }}</p>
      </div>
    </template>

    <EmptyState
      v-else
      icon="shift"
      :title="t('pointOfSale.shifts.notFound')"
      :description="error || t('pointOfSale.shifts.notFoundHint')"
    >
      <button type="button" class="ui-btn ui-btn--secondary mt-4" @click="router.push({ name: 'pos-shifts' })">
        ← {{ t('nav.posShifts') }}
      </button>
    </EmptyState>

    <AppModal :open="showClose" :title="t('pointOfSale.shifts.closeAction')" @close="showClose = false">
      <div class="space-y-3">
        <div>
          <FieldLabel icon="coins">{{ t('pointOfSale.shifts.actualCash') }}</FieldLabel>
          <input v-model="actualCash" type="text" class="ui-input w-full" required />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pos.varianceReason') }}</FieldLabel>
          <textarea v-model="varianceReason" rows="2" class="ui-input w-full" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pointOfSale.shifts.notes') }}</FieldLabel>
          <textarea v-model="closingNotes" rows="2" class="ui-input w-full" />
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="showClose = false">{{ t('common.cancel') }}</button>
          <button type="button" class="ui-btn ui-btn--primary" :disabled="saving" @click="confirmClose">
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </div>
    </AppModal>
  </PageFrame>
</template>
