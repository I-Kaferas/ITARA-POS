<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Role } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const showModal = ref(false)
const editing = ref<Role | null>(null)
const saving = ref(false)
const form = ref({ name: '', slug: '', permissions: [] as string[] })

const groupedPermissions = computed(() => {
  const groups: Record<string, typeof store.permissions> = {}
  for (const p of store.permissions) {
    if (!groups[p.group]) groups[p.group] = []
    groups[p.group].push(p)
  }
  return groups
})

onMounted(async () => {
  await store.loadRoles()
  await store.loadPermissions()
})

function openCreate() {
  editing.value = null
  form.value = { name: '', slug: '', permissions: [] }
  showModal.value = true
}

function openEdit(role: Role) {
  editing.value = role
  form.value = {
    name: role.name,
    slug: role.slug,
    permissions: role.permissions?.map(p => p.slug) ?? [],
  }
  showModal.value = true
}

function togglePermission(slug: string) {
  if (form.value.permissions.includes(slug)) {
    form.value.permissions = form.value.permissions.filter(p => p !== slug)
  } else {
    form.value.permissions.push(slug)
  }
}

async function save() {
  saving.value = true
  try {
    await store.saveRole(form.value, editing.value?.id)
    await store.loadRoles()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(role: Role) {
  if (role.is_system) return
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteRole(role.id)
  await store.loadRoles()
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="flex justify-end">
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('rbac.addRole') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">Slug</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('rbac.permissions') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="role in store.roles" :key="role.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">
                {{ role.name }}
                <span v-if="role.is_system" class="ml-2 rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-500">system</span>
              </td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ role.slug }}</td>
              <td class="px-4 py-3 text-slate-500">{{ role.permissions?.length ?? 0 }}</td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(role)">{{ t('common.edit') }}</button>
                <button v-if="!role.is_system" class="text-red-600" @click="remove(role)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('rbac.editRole') : t('rbac.addRole')"
      icon="organization"
      tone="info"
      size="lg"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div class="grid grid-cols-2 gap-3">
          <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" /></div>
          <div><FieldLabel icon="tag">Slug</FieldLabel><input v-model="form.slug" required pattern="[a-z0-9_]+" class="field" :disabled="!!editing?.is_system" /></div>
        </div>
        <div>
          <FieldLabel icon="lock">{{ t('rbac.permissions') }}</FieldLabel>
          <div v-for="(perms, group) in groupedPermissions" :key="group" class="mb-4">
            <p class="mb-1 text-xs font-semibold uppercase text-slate-500">{{ group }}</p>
            <div class="grid grid-cols-2 gap-1">
              <label v-for="perm in perms" :key="perm.id" class="flex items-center gap-2 text-sm">
                <input type="checkbox" :checked="form.permissions.includes(perm.slug)" @change="togglePermission(perm.slug)" />
                {{ perm.name }}
              </label>
            </div>
          </div>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
