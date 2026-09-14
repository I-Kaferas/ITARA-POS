<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Branch, Warehouse } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const companyId = ref('')
const branchId = ref('')
const branches = ref<Branch[]>([])
const showModal = ref(false)
const editing = ref<Warehouse | null>(null)
const saving = ref(false)
const form = ref({ name: '', code: '', is_active: true })

onMounted(async () => {
  await store.loadCompanies()
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, async (id) => {
  if (!id) return
  branches.value = await store.loadBranches(id)
  branchId.value = branches.value[0]?.id ?? ''
})

watch(branchId, (id) => { if (id) store.loadWarehouses(id) })

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', is_active: true }
  showModal.value = true
}

function openEdit(wh: Warehouse) {
  editing.value = wh
  form.value = { name: wh.name, code: wh.code, is_active: wh.is_active }
  showModal.value = true
}

async function save() {
  if (!branchId.value) return
  saving.value = true
  try {
    await store.saveWarehouse(branchId.value, form.value, editing.value?.id)
    await store.loadWarehouses(branchId.value)
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(wh: Warehouse) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteWarehouse(wh.id)
  await store.loadWarehouses(branchId.value)
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-4">
        <select v-model="companyId" class="field w-auto">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
        <select v-model="branchId" class="field w-auto">
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
        </select>
        <button class="btn-primary ml-auto" @click="openCreate">+ {{ t('org.addWarehouse') }}</button>
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
            <tr v-for="wh in store.warehouses" :key="wh.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ wh.name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ wh.code }}</td>
              <td class="px-4 py-3"><StatusBadge :active="wh.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(wh)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(wh)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.warehouses.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('org.editWarehouse') : t('org.addWarehouse')"
      icon="inventory"
      tone="info"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field w-full" /></div>
        <div><FieldLabel icon="tag">{{ t('org.code') }}</FieldLabel><input v-model="form.code" required class="field w-full" /></div>
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
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
