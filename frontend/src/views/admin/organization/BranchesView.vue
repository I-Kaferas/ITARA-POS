<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Branch } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const companyId = ref('')
const showModal = ref(false)
const editing = ref<Branch | null>(null)
const saving = ref(false)
const form = ref({ name: '', code: '', is_active: true })

onMounted(async () => {
  await store.loadCompanies()
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, (id) => { if (id) store.loadBranches(id) })

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', is_active: true }
  showModal.value = true
}

function openEdit(branch: Branch) {
  editing.value = branch
  form.value = { name: branch.name, code: branch.code, is_active: branch.is_active }
  showModal.value = true
}

async function save() {
  if (!companyId.value) return
  saving.value = true
  try {
    await store.saveBranch(companyId.value, form.value, editing.value?.id)
    await store.loadBranches(companyId.value)
    showModal.value = false
  } finally {
    saving.value = false
  }
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
            <tr v-for="branch in store.branches" :key="branch.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ branch.name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ branch.code }}</td>
              <td class="px-4 py-3"><StatusBadge :active="branch.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(branch)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(branch)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.branches.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('org.editBranch') : t('org.addBranch')"
      icon="building"
      tone="brand"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.name') }}</label><input v-model="form.name" required class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.code') }}</label><input v-model="form.code" required class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
