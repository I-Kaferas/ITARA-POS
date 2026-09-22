<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Branch } from '../../../types'
import { formatMoney } from '../../../utils/format'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'
import { parseMoneyInput } from '../../../utils/money'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const companyId = ref('')
const showModal = ref(false)
const editing = ref<Branch | null>(null)
const saving = ref(false)
const form = ref({ name: '', code: '', is_active: true, receipt_footer: '' })
const selected = ref<Branch | null>(null)
const expenseDescription = ref('')
const expenseAmount = ref('')
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.branches.filter(branch =>
  matchesSearch(`${branch.name} ${branch.code}`, filters.value.search)
  && matchesActive(branch.is_active, filters.value.active),
))

onMounted(async () => {
  await store.loadCompanies()
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, (id) => { if (id) store.loadBranches(id) })

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', is_active: true, receipt_footer: '' }
  showModal.value = true
}

function openEdit(branch: Branch) {
  editing.value = branch
  form.value = {
    name: branch.name,
    code: branch.code,
    is_active: branch.is_active,
    receipt_footer: branch.settings?.receipt_footer ?? '',
  }
  showModal.value = true
}

async function save() {
  if (!companyId.value) return
  saving.value = true
  try {
    await store.saveBranch(companyId.value, {
      name: form.value.name,
      code: form.value.code,
      is_active: form.value.is_active,
      settings: { receipt_footer: form.value.receipt_footer },
    }, editing.value?.id)
    await store.loadBranches(companyId.value)
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function openProfile(branch: Branch) {
  selected.value = await store.loadBranchProfile(branch.id)
}

async function addExpense() {
  if (!selected.value || !expenseDescription.value.trim()) return
  await store.addBranchExpense(selected.value.id, {
    description: expenseDescription.value.trim(),
    amount: parseMoneyInput(expenseAmount.value),
  })
  expenseDescription.value = ''
  expenseAmount.value = ''
  selected.value = await store.loadBranchProfile(selected.value.id)
}

async function remove(branch: Branch) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteBranch(branch.id)
  await store.loadBranches(companyId.value)
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <select v-model="companyId" class="field w-auto">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
        <button class="btn-primary" @click="openCreate">+ {{ t('org.addBranch') }}</button>
      </div>

      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="branch in filtered" :key="branch.id" class="cursor-pointer hover:bg-slate-50" @click="openProfile(branch)">
              <td class="px-4 py-3 font-medium">{{ branch.name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ branch.code }}</td>
              <td class="px-4 py-3"><StatusBadge :active="branch.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2" @click.stop>
                <button class="text-brand-600" @click="openEdit(branch)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(branch)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <section v-if="selected" class="space-y-4 rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 class="font-semibold">{{ selected.name }}</h2>
        <div class="grid gap-3 sm:grid-cols-3">
          <article class="rounded-lg bg-slate-50 p-3 text-sm">
            <p class="font-medium">{{ t('org.branchStock') }}</p>
            <p>{{ selected.stock?.warehouses?.map(item => item.name).join(', ') || '—' }}</p>
            <p class="text-slate-500">{{ selected.stock?.lines ?? 0 }}</p>
          </article>
          <article class="rounded-lg bg-slate-50 p-3 text-sm">
            <p class="font-medium">{{ t('org.branchUsers') }}</p>
            <p>{{ selected.users?.map(item => item.name).join(', ') || '—' }}</p>
          </article>
          <article class="rounded-lg bg-slate-50 p-3 text-sm">
            <p class="font-medium">{{ t('org.branchRegisters') }}</p>
            <p>{{ selected.registers?.map(item => item.name).join(', ') || '—' }}</p>
          </article>
          <article class="rounded-lg bg-slate-50 p-3 text-sm">
            <p class="font-medium">{{ t('org.branchSales') }}</p>
            <p>{{ selected.sales_count ?? 0 }}</p>
          </article>
          <article class="rounded-lg bg-slate-50 p-3 text-sm sm:col-span-2">
            <p class="font-medium">{{ t('org.storeKind') }} / {{ t('org.boutiqueKind') }}</p>
            <p>{{ selected.stores?.map(item => `${item.name} (${item.kind === 'boutique' ? t('org.boutiqueKind') : t('org.storeKind')})`).join(', ') || '—' }}</p>
          </article>
        </div>
        <div>
          <p class="mb-2 text-sm font-medium">{{ t('org.branchExpenses') }}</p>
          <ul class="mb-3 space-y-1 text-sm text-slate-600">
            <li v-for="expense in selected.expenses ?? []" :key="expense.id">{{ expense.description }} — {{ formatMoney(expense.amount) }}</li>
            <li v-if="!(selected.expenses ?? []).length">{{ t('org.empty') }}</li>
          </ul>
          <form class="flex flex-wrap gap-2" @submit.prevent="addExpense">
            <input v-model="expenseDescription" class="field" :placeholder="t('org.expenseDescription')" required />
            <input v-model="expenseAmount" class="field w-32" inputmode="numeric" :placeholder="t('org.expenseAmount')" required />
            <button class="btn-secondary" type="submit">{{ t('org.addExpense') }}</button>
          </form>
        </div>
      </section>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('org.editBranch') : t('org.addBranch')"
      icon="building"
      tone="brand"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" /></div>
        <div><FieldLabel icon="tag">{{ t('org.code') }}</FieldLabel><input v-model="form.code" required class="field" /></div>
        <div><FieldLabel icon="receipt">{{ t('org.branchSettings') }}</FieldLabel><input v-model="form.receipt_footer" class="field" :placeholder="t('org.receiptFooter')" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
