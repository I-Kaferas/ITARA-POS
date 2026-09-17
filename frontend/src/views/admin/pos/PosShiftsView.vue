<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const loading = ref(false)
const error = ref('')
const showOpen = ref(false)
const showClose = ref(false)
const selectedRegisterId = ref('')
const openingBalance = ref('0')
const openingNotes = ref('')
const actualCash = ref('')
const closingNotes = ref('')
const varianceReason = ref('')
const saving = ref(false)
const statusFilter = ref<'all' | 'open' | 'closed'>('all')

const filteredShifts = computed(() => {
  if (statusFilter.value === 'all') return store.cashierShifts
  return store.cashierShifts.filter(s => s.status === statusFilter.value)
})

const activeRegisters = computed(() => store.cashRegisters.filter(r => r.is_active !== false))

async function load() {
  if (!storeId.value) return
  loading.value = true
  error.value = ''
  try {
    await Promise.all([
      store.loadCashRegisters(storeId.value),
      store.loadStoreCashierShifts(storeId.value),
      store.loadCurrentCashierShift(),
    ])
    if (!selectedRegisterId.value && activeRegisters.value.length) {
      selectedRegisterId.value = activeRegisters.value[0].id
    }
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.loadError'))
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(storeId, load)

function openModal() {
  openingBalance.value = '0'
  openingNotes.value = ''
  if (!selectedRegisterId.value && activeRegisters.value.length) {
    selectedRegisterId.value = activeRegisters.value[0].id
  }
  showOpen.value = true
}

function closeModal() {
  const shift = store.currentCashierShift
  actualCash.value = shift ? String((shift.expected_cash ?? 0) / 100) : ''
  closingNotes.value = ''
  varianceReason.value = ''
  showClose.value = true
}

async function confirmOpen() {
  if (!selectedRegisterId.value) return
  saving.value = true
  error.value = ''
  try {
    await store.openCashierShift(selectedRegisterId.value, {
      opening_balance: Number(openingBalance.value.replace(',', '.')) || 0,
      opening_notes: openingNotes.value || undefined,
    })
    showOpen.value = false
    await load()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.shifts.openError'))
  } finally {
    saving.value = false
  }
}

async function confirmClose() {
  const registerId = store.currentCashierShift?.cash_register_id
  if (!registerId) return
  saving.value = true
  error.value = ''
  try {
    const expected = store.currentCashierShift?.expected_cash ?? 0
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

function goDetail(id: string) {
  router.push({ name: 'pos-shift-detail', params: { id } })
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posShifts') }}</template>
    <template #subtitle>{{ t('pointOfSale.shifts.subtitle') }}</template>

    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('pos.selectStore') }}
    </div>

    <template v-else>
      <!-- Current shift -->
      <div class="mb-4 rounded-xl border border-slate-200 bg-white p-4">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="m-0 text-xs font-medium uppercase tracking-wide text-slate-500">
              {{ t('pointOfSale.shifts.myShift') }}
            </p>
            <div class="mt-2 flex flex-wrap items-center gap-2">
              <StatusBadge
                :active="Boolean(store.currentCashierShift)"
                :label="store.currentCashierShift ? t('pointOfSale.shifts.open') : t('pointOfSale.shifts.noCurrent')"
              />
            </div>
            <template v-if="store.currentCashierShift">
              <p class="m-0 mt-2 text-sm text-slate-700">
                <strong>{{ t('pointOfSale.shifts.register') }}:</strong>
                {{ store.currentCashierShift.cash_register?.name ?? store.currentCashierShift.cash_register_id }}
              </p>
              <p class="m-0 mt-1 text-sm text-slate-500">
                {{ t('pointOfSale.shifts.openedAt') }} {{ formatDate(store.currentCashierShift.opened_at) }}
                · {{ t('pointOfSale.shifts.expected') }} {{ formatMoney(store.currentCashierShift.expected_cash) }}
                · {{ t('pointOfSale.shifts.sales') }} {{ formatMoney(store.currentCashierShift.sales_total) }}
              </p>
            </template>
            <p v-else class="m-0 mt-2 text-sm text-slate-500">
              {{ t('pointOfSale.shifts.noCurrentHint') }}
            </p>
          </div>

          <div class="flex flex-wrap gap-2">
            <button
              v-if="store.currentCashierShift"
              type="button"
              class="ui-btn ui-btn--secondary"
              @click="goDetail(store.currentCashierShift.id)"
            >
              {{ t('pointOfSale.shifts.viewDetails') }}
            </button>
            <button
              v-if="!store.currentCashierShift"
              type="button"
              class="ui-btn ui-btn--primary"
              :disabled="!activeRegisters.length"
              @click="openModal"
            >
              {{ t('pointOfSale.shifts.openAction') }}
            </button>
            <button
              v-else
              type="button"
              class="ui-btn ui-btn--primary"
              @click="closeModal"
            >
              {{ t('pointOfSale.shifts.closeAction') }}
            </button>
          </div>
        </div>
        <p v-if="!activeRegisters.length" class="mt-3 m-0 text-xs text-amber-700">
          {{ t('pointOfSale.shifts.noRegisterHint') }}
        </p>
      </div>

      <p v-if="error" class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>

      <!-- History -->
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('pointOfSale.shifts.history') }}</h3>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in ([
              ['all', t('pointOfSale.shifts.filterAll')],
              ['open', t('pointOfSale.shifts.open')],
              ['closed', t('pointOfSale.shifts.closed')],
            ] as const)"
            :key="opt[0]"
            type="button"
            class="ui-btn ui-btn--sm"
            :class="statusFilter === opt[0] ? 'ui-btn--primary' : 'ui-btn--secondary'"
            @click="statusFilter = opt[0]"
          >
            {{ opt[1] }}
          </button>
        </div>
      </div>

      <div v-if="loading" class="py-10 text-center text-sm text-slate-500">{{ t('common.loading') }}</div>

      <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table v-if="filteredShifts.length" class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.shifts.cashier') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.shifts.register') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.shifts.sales') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.shifts.expected') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              <th class="px-4 py-3 text-right font-medium" />
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="shift in filteredShifts"
              :key="shift.id"
              class="cursor-pointer hover:bg-slate-50"
              @click="goDetail(shift.id)"
            >
              <td class="px-4 py-3">{{ shift.cashier?.name ?? '—' }}</td>
              <td class="px-4 py-3">{{ shift.cash_register?.name ?? shift.cash_register_id }}</td>
              <td class="px-4 py-3">
                <StatusBadge
                  :active="shift.status === 'open'"
                  :label="shift.status === 'open' ? t('pointOfSale.shifts.open') : t('pointOfSale.shifts.closed')"
                />
              </td>
              <td class="px-4 py-3 text-right">{{ formatMoney(shift.sales_total) }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(shift.expected_cash) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(shift.opened_at) }}</td>
              <td class="px-4 py-3 text-right">
                <button
                  type="button"
                  class="ui-btn ui-btn--ghost ui-btn--sm"
                  @click.stop="goDetail(shift.id)"
                >
                  {{ t('common.view') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <EmptyState
          v-else
          icon="account"
          :title="t('pointOfSale.shifts.empty')"
          :description="t('pointOfSale.shifts.emptyHint')"
        >
          <button
            v-if="!store.currentCashierShift && activeRegisters.length"
            type="button"
            class="ui-btn ui-btn--primary mt-4"
            @click="openModal"
          >
            {{ t('pointOfSale.shifts.openAction') }}
          </button>
        </EmptyState>
      </div>
    </template>

    <AppModal :open="showOpen" :title="t('pointOfSale.shifts.openAction')" @close="showOpen = false">
      <div class="space-y-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.shifts.openHint') }}</p>
        <div>
          <FieldLabel icon="shift">{{ t('pointOfSale.shifts.register') }}</FieldLabel>
          <select v-model="selectedRegisterId" class="ui-select w-full">
            <option v-for="reg in activeRegisters" :key="reg.id" :value="reg.id">
              {{ reg.name }} ({{ reg.code }})
            </option>
          </select>
        </div>
        <div>
          <FieldLabel icon="coins">{{ t('pointOfSale.shifts.openingBalance') }}</FieldLabel>
          <input v-model="openingBalance" type="text" class="ui-input w-full" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('pointOfSale.shifts.notes') }}</FieldLabel>
          <textarea v-model="openingNotes" rows="2" class="ui-input w-full" />
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="showOpen = false">{{ t('common.cancel') }}</button>
          <button type="button" class="ui-btn ui-btn--primary" :disabled="saving || !selectedRegisterId" @click="confirmOpen">
            {{ saving ? t('common.loading') : t('pointOfSale.shifts.openAction') }}
          </button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showClose" :title="t('pointOfSale.shifts.closeAction')" @close="showClose = false">
      <div class="space-y-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.shifts.closeHint') }}</p>
        <div v-if="store.currentCashierShift" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          <div class="flex justify-between gap-3">
            <span>{{ t('pointOfSale.shifts.expected') }}</span>
            <strong>{{ formatMoney(store.currentCashierShift.expected_cash) }}</strong>
          </div>
          <div class="mt-1 flex justify-between gap-3">
            <span>{{ t('pointOfSale.shifts.sales') }}</span>
            <strong>{{ formatMoney(store.currentCashierShift.sales_total) }}</strong>
          </div>
        </div>
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
            {{ saving ? t('common.loading') : t('pointOfSale.shifts.closeAction') }}
          </button>
        </div>
      </div>
    </AppModal>
  </PageFrame>
</template>
