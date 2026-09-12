<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { intlLocale } from '../../../i18n/locales'
import type { CashRegister, RegisterSummary } from '../../../types'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { openPrintWindow } from '../../../utils/printSaleDocument'
import { printZReport } from '../../../utils/printZReport'

const { t, locale } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = ref('')
const showRegisterModal = ref(false)
const showSessionModal = ref(false)
const showMovementModal = ref(false)
const showCloseModal = ref(false)
const editing = ref<CashRegister | null>(null)
const activeRegister = ref<CashRegister | null>(null)
const sessionSummary = ref<RegisterSummary | null>(null)
const saving = ref(false)
const sessionBusy = ref(false)

const registerForm = ref({
  name: '',
  code: '',
  is_active: true,
})

const openForm = ref({
  opening_balance: '0',
  opening_notes: '',
})

const movementForm = ref({
  movement_type: 'cash_in' as 'cash_in' | 'cash_out' | 'expense',
  amount: '',
  description: '',
})

const closeForm = ref({
  actual_cash: '',
  closing_notes: '',
})

const currency = computed(() => {
  const s = context.activeStores.find(st => st.id === storeId.value)
  return s?.branch?.company?.currency_code ?? 'FBU'
})

const movementTypes = [
  { value: 'cash_in', labelKey: 'registers.cashIn' },
  { value: 'cash_out', labelKey: 'registers.cashOut' },
  { value: 'expense', labelKey: 'registers.expense' },
] as const

onMounted(async () => {
  await context.loadStores()
  storeId.value = context.currentStoreId ?? context.activeStores[0]?.id ?? ''
})

watch(storeId, async (id) => {
  if (id) await store.loadCashRegisters(id)
})

function format(amount: number) {
  return formatMoney(amount, currency.value, intlLocale(locale.value))
}

function nextRegisterDefaults() {
  const used = new Set(store.cashRegisters.map(register => register.code.toUpperCase()))
  let next = 1
  for (const register of store.cashRegisters) {
    const match = register.code.match(/(\d+)$/)
    const value = match ? Number(match[1]) : 0
    if (value >= next) next = value + 1
  }
  let code = `REG-${String(next).padStart(2, '0')}`
  while (used.has(code)) {
    next += 1
    code = `REG-${String(next).padStart(2, '0')}`
  }
  const name = next === 1 && store.cashRegisters.length === 0
    ? 'Caisse principale'
    : `Caisse ${String(next).padStart(2, '0')}`
  return { name, code }
}

function openCreate() {
  editing.value = null
  registerForm.value = { ...nextRegisterDefaults(), is_active: true }
  showRegisterModal.value = true
}

function openEdit(register: CashRegister) {
  editing.value = register
  registerForm.value = {
    name: register.name,
    code: register.code,
    is_active: register.is_active,
  }
  showRegisterModal.value = true
}

async function saveRegister() {
  if (!storeId.value) return
  saving.value = true
  try {
    await store.saveCashRegister(storeId.value, registerForm.value, editing.value?.id)
    await store.loadCashRegisters(storeId.value)
    showRegisterModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(register: CashRegister) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCashRegister(register.id)
  await store.loadCashRegisters(storeId.value)
}

async function refreshSessionSummary(register: CashRegister) {
  const { summary } = await store.getCurrentRegisterSession(register.id)
  sessionSummary.value = summary
}

async function openSessionPanel(register: CashRegister) {
  activeRegister.value = register
  showSessionModal.value = true
  sessionBusy.value = true
  try {
    await refreshSessionSummary(register)
  } finally {
    sessionBusy.value = false
  }
}

async function submitOpenSession() {
  if (!activeRegister.value) return
  sessionBusy.value = true
  try {
    const res = await store.openRegisterSession(activeRegister.value.id, {
      opening_balance: parseMoneyInput(openForm.value.opening_balance),
      opening_notes: openForm.value.opening_notes || undefined,
    })
    sessionSummary.value = res.summary
    openForm.value = { opening_balance: '0', opening_notes: '' }
    await store.loadCashRegisters(storeId.value)
  } finally {
    sessionBusy.value = false
  }
}

function openMovementDialog() {
  movementForm.value = { movement_type: 'cash_in', amount: '', description: '' }
  showMovementModal.value = true
}

async function submitMovement() {
  if (!activeRegister.value) return
  const amount = parseMoneyInput(movementForm.value.amount)
  if (amount <= 0) return
  sessionBusy.value = true
  try {
    const res = await store.recordRegisterMovement(activeRegister.value.id, {
      movement_type: movementForm.value.movement_type,
      amount,
      description: movementForm.value.description || undefined,
    })
    sessionSummary.value = res.summary
    showMovementModal.value = false
    await store.loadCashRegisters(storeId.value)
  } finally {
    sessionBusy.value = false
  }
}

function openCloseDialog() {
  closeForm.value = {
    actual_cash: sessionSummary.value ? String(sessionSummary.value.expected_cash / 100) : '',
    closing_notes: '',
  }
  showCloseModal.value = true
}

async function submitCloseSession() {
  if (!activeRegister.value) return
  sessionBusy.value = true
  try {
    const res = await store.closeRegisterSession(activeRegister.value.id, {
      actual_cash: parseMoneyInput(closeForm.value.actual_cash),
      closing_notes: closeForm.value.closing_notes || undefined,
    })
    sessionSummary.value = res.summary
    showCloseModal.value = false
    await store.loadCashRegisters(storeId.value)

    const report = res.z_report ?? res.summary
    if (report) {
      const popup = openPrintWindow()
      printZReport({
        register: { name: activeRegister.value.name, code: activeRegister.value.code },
        opened_at: report.opened_at,
        closed_at: report.closed_at,
        opening_balance: report.opening_balance,
        sales_total: report.sales_total,
        cash_in_total: report.cash_in_total,
        cash_out_total: report.cash_out_total,
        expenses_total: report.expenses_total,
        expected_cash: report.expected_cash,
        actual_cash: report.actual_cash,
        variance: report.variance,
        invoices_count: report.invoices_count,
        invoices_total: report.invoices_total,
        invoices: report.invoices,
        payment_methods: report.payment_methods,
        currency: currency.value,
      }, t('pos.zReport'), popup)
    }
  } finally {
    sessionBusy.value = false
  }
}

const isSessionOpen = computed(() => sessionSummary.value?.status === 'open')
const varianceClass = computed(() => {
  const v = sessionSummary.value?.variance ?? 0
  if (v === 0) return 'text-slate-600'
  return v > 0 ? 'text-emerald-600' : 'text-red-600'
})
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('stores.select') }}</label>
          <select v-model="storeId" class="field w-auto min-w-[240px]">
            <option v-for="s in context.activeStores" :key="s.id" :value="s.id">
              {{ context.storeLabel(s) }}
            </option>
          </select>
        </div>
        <button class="btn-primary" :disabled="!storeId" @click="openCreate">
          + {{ t('registers.add') }}
        </button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('registers.session') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="register in store.cashRegisters" :key="register.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ register.name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ register.code }}</td>
              <td class="px-4 py-3">
                <span
                  v-if="register.open_session"
                  class="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-700"
                >
                  {{ t('registers.open') }}
                </span>
                <span v-else class="text-slate-400">{{ t('registers.closed') }}</span>
              </td>
              <td class="px-4 py-3"><StatusBadge :active="register.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openSessionPanel(register)">{{ t('registers.manage') }}</button>
                <button class="text-brand-600" @click="openEdit(register)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(register)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.cashRegisters.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <!-- Register CRUD -->
    <AppModal
      :open="showRegisterModal"
      :title="editing ? t('registers.edit') : t('registers.add')"
      icon="device-pos"
      tone="brand"
      @close="showRegisterModal = false"
    >
      <form class="space-y-3" @submit.prevent="saveRegister">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('org.name') }}</label>
            <input v-model="registerForm.name" required class="field w-full" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('org.code') }}</label>
            <input v-model="registerForm.code" required class="field w-full font-mono" />
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="registerForm.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showRegisterModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <!-- Session workflow -->
    <AppModal
      :open="showSessionModal && !!activeRegister"
      :title="activeRegister?.name ?? ''"
      icon="shift"
      tone="info"
      size="lg"
      @close="showSessionModal = false"
    >
      <p class="mb-3 text-sm text-slate-500">{{ t('registers.workflow') }}</p>

      <div v-if="sessionBusy && !sessionSummary" class="py-8 text-center text-slate-500">{{ t('common.loading') }}</div>

      <template v-else>
        <!-- Session closed: show closure result -->
        <div v-if="sessionSummary && sessionSummary.status === 'closed'" class="space-y-3">
          <div class="rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            {{ t('registers.closureResult') }}
          </div>
          <div class="grid grid-cols-3 gap-3 text-sm">
            <div class="rounded-lg bg-slate-50 p-3">
              <p class="text-slate-500">{{ t('registers.expectedCash') }}</p>
              <p class="font-semibold">{{ format(sessionSummary.expected_cash) }}</p>
            </div>
            <div class="rounded-lg bg-slate-50 p-3">
              <p class="text-slate-500">{{ t('registers.actualCash') }}</p>
              <p class="font-semibold">{{ format(sessionSummary.actual_cash ?? 0) }}</p>
            </div>
            <div class="rounded-lg bg-slate-50 p-3">
              <p class="text-slate-500">{{ t('registers.variance') }}</p>
              <p class="font-semibold" :class="varianceClass">{{ format(sessionSummary.variance ?? 0) }}</p>
            </div>
          </div>
          <button type="button" class="btn-secondary w-full" @click="showSessionModal = false">{{ t('common.cancel') }}</button>
        </div>

        <!-- Closed register: open session -->
        <div v-else-if="!isSessionOpen" class="space-y-3">
          <div class="rounded-lg border border-dashed border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
            {{ t('registers.openHint') }}
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('registers.openingBalance') }}</label>
            <input v-model="openForm.opening_balance" type="text" class="field w-full" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium">{{ t('registers.notes') }} ({{ t('common.optional') }})</label>
            <textarea v-model="openForm.opening_notes" rows="2" class="field w-full" />
          </div>
          <button class="btn-primary w-full" :disabled="sessionBusy" @click="submitOpenSession">
            {{ t('registers.openSession') }}
          </button>
        </div>

        <!-- Open session -->
        <div v-else class="space-y-5">
          <div class="grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">
            <div class="rounded-lg bg-slate-50 p-3">
              <p class="text-slate-500">{{ t('registers.openingBalance') }}</p>
              <p class="font-semibold">{{ format(sessionSummary!.opening_balance) }}</p>
            </div>
            <div class="rounded-lg bg-emerald-50 p-3">
              <p class="text-emerald-700">{{ t('registers.sales') }}</p>
              <p class="font-semibold text-emerald-800">+ {{ format(sessionSummary!.sales_total) }}</p>
            </div>
            <div class="rounded-lg bg-emerald-50 p-3">
              <p class="text-emerald-700">{{ t('registers.cashIn') }}</p>
              <p class="font-semibold text-emerald-800">+ {{ format(sessionSummary!.cash_in_total) }}</p>
            </div>
            <div class="rounded-lg bg-red-50 p-3">
              <p class="text-red-700">{{ t('registers.cashOut') }}</p>
              <p class="font-semibold text-red-800">− {{ format(sessionSummary!.cash_out_total) }}</p>
            </div>
            <div class="rounded-lg bg-red-50 p-3">
              <p class="text-red-700">{{ t('registers.expenses') }}</p>
              <p class="font-semibold text-red-800">− {{ format(sessionSummary!.expenses_total) }}</p>
            </div>
            <div class="rounded-lg bg-brand-50 p-3 ring-1 ring-brand-200">
              <p class="text-brand-700">{{ t('registers.expectedCash') }}</p>
              <p class="text-lg font-bold text-brand-800">{{ format(sessionSummary!.expected_cash) }}</p>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <button class="btn-secondary" :disabled="sessionBusy" @click="openMovementDialog">
              + {{ t('registers.recordMovement') }}
            </button>
            <button class="btn-primary" :disabled="sessionBusy" @click="openCloseDialog">
              {{ t('registers.closeSession') }}
            </button>
          </div>

          <p class="text-xs text-slate-400">
            {{ t('registers.formula') }}
          </p>
        </div>
      </template>
    </AppModal>

    <!-- Movement -->
    <AppModal
      :open="showMovementModal"
      :title="t('registers.recordMovement')"
      icon="coins"
      tone="accent"
      @close="showMovementModal = false"
    >
      <form class="space-y-3" @submit.prevent="submitMovement">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('registers.movementType') }}</label>
          <select v-model="movementForm.movement_type" class="field w-full">
            <option v-for="mt in movementTypes" :key="mt.value" :value="mt.value">{{ t(mt.labelKey) }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('pos.amount') }}</label>
          <input v-model="movementForm.amount" required type="text" class="field w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('registers.description') }}</label>
          <input v-model="movementForm.description" class="field w-full" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showMovementModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="sessionBusy">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <!-- Close -->
    <AppModal
      :open="showCloseModal"
      :title="t('registers.closeSession')"
      icon="lock"
      tone="warning"
      @close="showCloseModal = false"
    >
      <form class="space-y-3" @submit.prevent="submitCloseSession">
        <div class="rounded-lg bg-slate-50 p-3 text-sm">
          <p class="text-slate-500">{{ t('registers.expectedCash') }}</p>
          <p class="text-lg font-bold">{{ format(sessionSummary?.expected_cash ?? 0) }}</p>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('registers.actualCash') }}</label>
          <input v-model="closeForm.actual_cash" required type="text" class="field w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('registers.notes') }}</label>
          <textarea v-model="closeForm.closing_notes" rows="2" class="field w-full" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showCloseModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="sessionBusy">{{ t('registers.closeSession') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; background: white; }
.text-brand-600 { color: var(--color-brand-600); }
.bg-brand-50 { background-color: color-mix(in srgb, var(--color-brand-600) 8%, white); }
.text-brand-700 { color: var(--color-brand-600); }
.text-brand-800 { color: color-mix(in srgb, var(--color-brand-600) 80%, black); }
.ring-brand-200 { --tw-ring-color: color-mix(in srgb, var(--color-brand-600) 25%, white); }
</style>
