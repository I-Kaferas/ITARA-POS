<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatDate, formatMoney } from '../../../utils/format'
import { parseMoneyInput } from '../../../utils/money'

type Category = { id: string; code: string; name: string }
type ExpenseRow = {
  id: string
  description: string
  amount: number
  occurred_on: string
  expense_category?: { name: string } | null
  branch?: { name: string } | null
  user?: { name: string } | null
  cash_register_session?: { id: string; register?: { name: string } | null } | null
}
type OpenSession = { id: string; label: string }

const { t } = useI18n()
const store = useBackofficeStore()

const rows = ref<ExpenseRow[]>([])
const categories = ref<Category[]>([])
const sessions = ref<OpenSession[]>([])
const showModal = ref(false)
const saving = ref(false)
const form = ref({
  branch_id: '',
  expense_category_id: '',
  user_id: '',
  cash_register_session_id: '',
  description: '',
  amount: '',
})

const categoryName = computed(() => (id: string) => categories.value.find(item => item.id === id)?.name ?? id)

onMounted(load)

async function load() {
  await store.loadCompanies()
  if (store.companies[0]) await store.loadBranches(store.companies[0].id)
  await store.loadUsers()
  categories.value = (await store.loadExpenseCategories()) as Category[]
  rows.value = (await store.loadExpenses()) as ExpenseRow[]
}

async function onBranchChange() {
  form.value.cash_register_session_id = ''
  sessions.value = []
  if (!form.value.branch_id) return
  const profile = await store.loadBranchProfile(form.value.branch_id)
  const found: OpenSession[] = []
  for (const register of profile.registers ?? []) {
    const current = await store.getCurrentRegisterSession(register.id)
    if (current.session?.id) {
      found.push({ id: current.session.id, label: register.name })
    }
  }
  sessions.value = found
}

function openCreate() {
  form.value = {
    branch_id: store.branches[0]?.id ?? '',
    expense_category_id: categories.value[0]?.id ?? '',
    user_id: '',
    cash_register_session_id: '',
    description: '',
    amount: '',
  }
  showModal.value = true
  if (form.value.branch_id) void onBranchChange()
}

async function save() {
  const amount = parseMoneyInput(form.value.amount)
  if (amount < 1 || !form.value.branch_id || !form.value.expense_category_id) return
  saving.value = true
  try {
    await store.createExpense({
      branch_id: form.value.branch_id,
      expense_category_id: form.value.expense_category_id,
      user_id: form.value.user_id || null,
      cash_register_session_id: form.value.cash_register_session_id || null,
      description: form.value.description,
      amount,
    })
    showModal.value = false
    rows.value = (await store.loadExpenses()) as ExpenseRow[]
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.expenses') }}</template>
    <template #subtitle>{{ t('expenses.linksHint') }}</template>

    <div class="mb-4 flex justify-end">
      <button class="btn-primary" type="button" @click="openCreate">+ {{ t('expenses.new') }}</button>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.date') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.category') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.label') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.branch') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.user') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.session') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('expenses.amount') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in rows" :key="row.id">
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.occurred_on) }}</td>
            <td class="px-4 py-3">{{ row.expense_category?.name ?? '—' }}</td>
            <td class="px-4 py-3 font-medium">{{ row.description }}</td>
            <td class="px-4 py-3">{{ row.branch?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.user?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.cash_register_session?.register?.name ?? '—' }}</td>
            <td class="px-4 py-3 text-right font-medium">{{ formatMoney(row.amount) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!rows.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal :open="showModal" :title="t('expenses.new')" icon="coins" tone="accent" @close="showModal = false">
      <form class="space-y-3" @submit.prevent="save">
        <p class="m-0 text-xs text-slate-500">{{ t('expenses.linksHint') }}</p>
        <div>
          <FieldLabel icon="building">{{ t('expenses.branch') }}</FieldLabel>
          <select v-model="form.branch_id" class="field" required @change="onBranchChange">
            <option v-for="branch in store.branches" :key="branch.id" :value="branch.id">{{ branch.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('expenses.category') }}</FieldLabel>
          <select v-model="form.expense_category_id" class="field" required>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="account">{{ t('expenses.user') }}</FieldLabel>
          <select v-model="form.user_id" class="field">
            <option value="">{{ t('expenses.currentUser') }}</option>
            <option v-for="user in store.users" :key="user.id" :value="user.id">{{ user.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="stores">{{ t('expenses.session') }}</FieldLabel>
          <select v-model="form.cash_register_session_id" class="field">
            <option value="">{{ t('expenses.noSession') }}</option>
            <option v-for="session in sessions" :key="session.id" :value="session.id">{{ session.label }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('expenses.label') }}</FieldLabel>
          <input v-model="form.description" class="field" required :placeholder="categoryName(form.expense_category_id)" />
        </div>
        <div>
          <FieldLabel icon="coins">{{ t('expenses.amount') }}</FieldLabel>
          <input v-model="form.amount" class="field" inputmode="decimal" required placeholder="15000" />
        </div>
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
.btn-secondary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; background: white; border: 1px solid #cbd5e1; }
</style>
