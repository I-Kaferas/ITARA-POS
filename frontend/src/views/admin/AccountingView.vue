<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppModal from '../../components/ui/AppModal.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import { api } from '../../api/client'
import type { AccountingSummary } from '../../types'
import { formatDate, formatMoney } from '../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const summary = ref<AccountingSummary | null>(null)
const from = ref('')
const to = ref('')
const showModal = ref(false)
const saving = ref(false)
const selected = ref<string[]>([])
const accounts = ref<{ id: string; code: string; name: string }[]>([])
const periodFrom = ref('')
const periodTo = ref('')
const form = ref({
  entry_type: 'sale_revenue',
  reference_type: 'manual',
  reference_id: crypto.randomUUID(),
  debit: 0,
  credit: 0,
  account_code: '4000',
  description: '',
})

async function load() {
  const params: Record<string, string> = {}
  if (from.value) params.from = from.value
  if (to.value) params.to = to.value
  await store.loadAccountingEntries(params)
  summary.value = await store.loadAccountingSummary(from.value || undefined, to.value || undefined)
}

async function save() {
  saving.value = true
  try {
    await store.createAccountingEntry({
      ...form.value,
      debit: Number(form.value.debit) || 0,
      credit: Number(form.value.credit) || 0,
    })
    showModal.value = false
    form.value.reference_id = crypto.randomUUID()
    await load()
  } finally {
    saving.value = false
  }
}

async function loadAccounts() {
  accounts.value = (await api.get<{ data: { id: string; code: string; name: string }[] }>('/accounting/accounts')).data
}

async function letter() {
  await api.post('/accounting/letter', { entry_ids: selected.value })
  selected.value = []
  await load()
}

async function closePeriod() {
  await api.post('/accounting/periods/close', { starts_on: periodFrom.value, ends_on: periodTo.value })
}

onMounted(load)
watchLiveSearch([from, to], load, 0)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.accounting') }}</template>
    <template #subtitle>{{ t('accounting.subtitle') }}</template>

    <div class="mb-4 flex flex-wrap items-end justify-between gap-3">
      <div class="flex flex-wrap items-end gap-3">
        <div>
          <FieldLabel icon="calendar">{{ t('reports.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" />
        </div>
      </div>
      <button class="btn-primary" @click="showModal = true">+ {{ t('accounting.addEntry') }}</button>
    </div>

    <div class="mb-4 flex flex-wrap items-end gap-2">
      <button class="btn-secondary" @click="loadAccounts">{{ t('accounting.chart') }}</button>
      <button class="btn-secondary" :disabled="selected.length < 2" @click="letter">{{ t('accounting.letter') }}</button>
      <input v-model="periodFrom" type="date" class="field" />
      <input v-model="periodTo" type="date" class="field" />
      <button class="btn-secondary" @click="closePeriod">{{ t('accounting.closePeriod') }}</button>
    </div>
    <div v-if="accounts.length" class="mb-4 flex flex-wrap gap-2">
      <span v-for="account in accounts" :key="account.id" class="rounded-full bg-white px-3 py-1 text-xs ring-1 ring-slate-200">{{ account.code }} {{ account.name }}</span>
    </div>

    <div v-if="summary?.books?.length" class="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div v-for="book in summary.books" :key="book.code" class="stat">
        <p class="label">{{ t(`accounting.books.${book.code}`) }}</p>
        <p class="value">{{ formatMoney(book.balance) }}</p>
      </div>
    </div>

    <div v-if="summary" class="mb-6 grid gap-4 sm:grid-cols-3">
      <div class="stat"><p class="label">{{ t('payables.debit') }}</p><p class="value">{{ formatMoney(summary.totals.total_debit) }}</p></div>
      <div class="stat"><p class="label">{{ t('payables.creditCol') }}</p><p class="value">{{ formatMoney(summary.totals.total_credit) }}</p></div>
      <div class="stat"><p class="label">{{ t('accounting.entries') }}</p><p class="value">{{ summary.totals.entries_count }}</p></div>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3"></th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('accounting.type') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('accounting.account') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('payables.debit') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('payables.creditCol') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in store.accountingEntries" :key="row.id">
            <td class="px-4 py-3"><input type="checkbox" :value="row.id" v-model="selected" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.occurred_at) }}</td>
            <td class="px-4 py-3 font-mono text-xs">{{ row.entry_type }}</td>
            <td class="px-4 py-3 font-mono">{{ row.account_code ?? '—' }}</td>
            <td class="px-4 py-3 text-right">{{ row.debit ? formatMoney(row.debit) : '—' }}</td>
            <td class="px-4 py-3 text-right">{{ row.credit ? formatMoney(row.credit) : '—' }}</td>
            <td class="px-4 py-3">{{ row.recorded_by_user?.name ?? '—' }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.accountingEntries.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('accounting.addEntry')"
      icon="note"
      tone="info"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="layers">{{ t('accounting.type') }}</FieldLabel>
          <select v-model="form.entry_type" class="field w-full">
            <option value="sale_revenue">sale_revenue</option>
            <option value="sale_cash">sale_cash</option>
            <option value="sale_tax">sale_tax</option>
            <option value="sale_cogs">sale_cogs</option>
            <option value="purchase_receipt_inventory">purchase_receipt_inventory</option>
            <option value="purchase_receipt_payable">purchase_receipt_payable</option>
          </select>
        </div>
        <div><FieldLabel icon="tag">{{ t('accounting.account') }}</FieldLabel><input v-model="form.account_code" class="field w-full" /></div>
        <div class="grid grid-cols-2 gap-3">
          <div><FieldLabel icon="coins">{{ t('payables.debit') }}</FieldLabel><input v-model.number="form.debit" type="number" min="0" class="field w-full" /></div>
          <div><FieldLabel icon="coins">{{ t('payables.creditCol') }}</FieldLabel><input v-model.number="form.credit" type="number" min="0" class="field w-full" /></div>
        </div>
        <div><FieldLabel icon="note">{{ t('common.description') }}</FieldLabel><input v-model="form.description" class="field w-full" /></div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.stat { border-radius: 0.75rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); }
.label { margin: 0; font-size: 0.75rem; color: #64748b; }
.value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; }
</style>
