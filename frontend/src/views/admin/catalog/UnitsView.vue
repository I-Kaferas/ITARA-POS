<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Unit } from '../../../types'

const { t } = useI18n()
const store = useBackofficeStore()
const showModal = ref(false)
const editing = ref<Unit | null>(null)
const saving = ref(false)
const form = ref({ code: '', name: '', symbol: '', is_fractional: false, is_active: true })

onMounted(() => store.loadUnits())

function openCreate() {
  editing.value = null
  form.value = { code: '', name: '', symbol: '', is_fractional: false, is_active: true }
  showModal.value = true
}

function openEdit(unit: Unit) {
  editing.value = unit
  form.value = { code: unit.code, name: unit.name, symbol: unit.symbol ?? '', is_fractional: unit.is_fractional, is_active: unit.is_active }
  showModal.value = true
}

async function save() {
  saving.value = true
  try {
    await store.saveUnit(form.value, editing.value?.id)
    await store.loadUnits()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(unit: Unit) {
  if (!confirm(t('org.confirmDelete'))) return
  await store.deleteUnit(unit.id)
  await store.loadUnits()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex items-center justify-between gap-3">
        <p class="m-0 text-sm text-slate-500">{{ t('catalog.unitsHint') }}</p>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('catalog.addUnit') }}</button>
      </div>
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.symbol') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.fractional') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="unit in store.units" :key="unit.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono">{{ unit.code }}</td>
              <td class="px-4 py-3 font-medium">{{ unit.name }}</td>
              <td class="px-4 py-3">{{ unit.symbol || '—' }}</td>
              <td class="px-4 py-3">{{ unit.is_fractional ? '✓' : '—' }}</td>
              <td class="px-4 py-3"><StatusBadge :active="unit.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(unit)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(unit)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.units.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editUnit') : t('catalog.addUnit')"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div class="grid grid-cols-2 gap-3">
          <div><FieldLabel icon="tag">{{ t('org.code') }}</FieldLabel><input v-model="form.code" required class="field" /></div>
          <div><FieldLabel icon="tag">{{ t('catalog.symbol') }}</FieldLabel><input v-model="form.symbol" class="field" /></div>
        </div>
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="form.is_fractional" type="checkbox" class="rounded" />{{ t('catalog.fractional') }}</label>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
</style>
