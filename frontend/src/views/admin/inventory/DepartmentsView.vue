<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FilterFold from '../../../components/ui/FilterFold.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useClientPager } from '../../../composables/useClientPager'
import ListPager from '../../../components/ui/ListPager.vue'

type Department = {
  id: string
  name: string
  code: string
  description: string
  parentId: string | null
  manager: string
  active: boolean
}

const departments = ref<Department[]>([
  { id: 'administration', name: 'Administration', code: 'admin', description: '', parentId: null, manager: '', active: true },
  { id: 'finance', name: 'Finance', code: 'finance', description: '', parentId: null, manager: '', active: true },
  { id: 'inventory', name: 'Inventory', code: 'inventory', description: '', parentId: null, manager: '', active: true },
  { id: 'purchasing', name: 'Purchasing', code: 'purchasing', description: '', parentId: null, manager: '', active: true },
  { id: 'sales', name: 'Sales', code: 'sales', description: '', parentId: null, manager: '', active: true },
])

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const query = ref('')
const creating = ref(false)
const editingId = ref<string | null>(null)
const form = ref(blankForm())
const baseline = ref('')

const dirty = computed(() => creating.value && JSON.stringify(form.value) !== baseline.value)

const parentOptions = computed(() => {
  if (!editingId.value) return departments.value
  const blocked = descendantIds(editingId.value)
  blocked.add(editingId.value)
  return departments.value.filter((row) => !blocked.has(row.id))
})

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return departments.value
  return departments.value.filter((item) => {
    const parent = parentName(item)
    return [item.name, item.code, item.description, item.manager, parent].join(' ').toLowerCase()      .includes(q)
  })
})
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

function blankForm() {
  return {
    name: '',
    code: '',
    description: '',
    parentId: '',
    manager: '',
    active: true,
  }
}

function parentName(item: Department) {
  if (!item.parentId) return ''
  return departments.value.find((row) => row.id === item.parentId)?.name ?? ''
}

function slugify(value: string) {
  return value
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function snapshotForm() {
  baseline.value = JSON.stringify(form.value)
}

function descendantIds(id: string) {
  const ids = new Set<string>()
  const walk = (parentId: string) => {
    for (const row of departments.value) {
      if (row.parentId === parentId && !ids.has(row.id)) {
        ids.add(row.id)
        walk(row.id)
      }
    }
  }
  walk(id)
  return ids
}

function uniqueCode(raw: string, exceptId?: string) {
  const taken = new Set(departments.value.filter((row) => row.id !== exceptId).map((row) => row.code))
  let unique = raw
  let n = 2
  while (taken.has(unique)) {
    unique = `${raw}-${n}`
    n += 1
  }
  return unique
}

function openCreate() {
  editingId.value = null
  form.value = blankForm()
  snapshotForm()
  creating.value = true
}

function openEdit(item: Department) {
  editingId.value = item.id
  form.value = {
    name: item.name,
    code: item.code,
    description: item.description,
    parentId: item.parentId ?? '',
    manager: item.manager,
    active: item.active,
  }
  snapshotForm()
  creating.value = true
}

function closeCreate() {
  creating.value = false
  editingId.value = null
}

function save() {
  const name = form.value.name.trim()
  if (!name) return
  const code = uniqueCode(slugify(form.value.code || name) || 'department', editingId.value ?? undefined)
  const next = {
    name,
    code,
    description: form.value.description.trim(),
    parentId: form.value.parentId || null,
    manager: form.value.manager.trim(),
    active: form.value.active,
  }
  if (editingId.value) {
    departments.value = departments.value.map((item) => (
      item.id === editingId.value ? { ...item, ...next } : item
    ))
  } else {
    departments.value.unshift({ id: `${code}-${Date.now()}`, ...next })
  }
  closeCreate()
}

async function remove(item: Department) {
  if (!(await confirmDialog(t('org.confirmDelete'), { danger: true }))) return
  departments.value = departments.value
    .filter((row) => row.id !== item.id)
    .map((row) => (row.parentId === item.id ? { ...row, parentId: null } : row))
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.inventoryItems.departments') }}</template>
    <template #subtitle>{{ t('orgDepartments.subtitle') }}</template>

    <div class="departments">
      <div class="departments__toolbar">
        <button type="button" class="btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('orgDepartments.add') }}
        </button>
        <FilterFold>
        <label class="departments__search">
          <span class="sr-only">{{ t('orgDepartments.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('orgDepartments.searchPlaceholder')"
          />
        </label>
        </FilterFold>
      </div>

      <DataTableShell
        :empty="!filtered.length"
        :empty-title="t('orgDepartments.empty')"
        empty-icon="building"
      >
        <table class="ui-table departments__table">
          <thead>
            <tr>
              <th>{{ t('orgDepartments.columns.department') }}</th>
              <th>{{ t('orgDepartments.columns.description') }}</th>
              <th>{{ t('orgDepartments.columns.parent') }}</th>
              <th>{{ t('orgDepartments.columns.manager') }}</th>
              <th>{{ t('orgDepartments.columns.status') }}</th>
              <th>{{ t('orgDepartments.columns.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in paged" :key="item.id">
              <td>
                <div class="departments__name">{{ item.name }}</div>
                <div class="departments__code">{{ item.code }}</div>
              </td>
              <td :class="{ 'departments__muted': !item.description }">{{ item.description || '—' }}</td>
              <td :class="{ 'departments__muted': !parentName(item) }">{{ parentName(item) || '—' }}</td>
              <td :class="{ 'departments__muted': !item.manager }">{{ item.manager || '—' }}</td>
              <td>
                <Badge :variant="item.active ? 'success' : 'neutral'" dot>
                  {{ item.active ? t('orgDepartments.active') : t('orgDepartments.inactive') }}
                </Badge>
              </td>
              <td class="departments__actions">
                <button type="button" class="text-brand-600" @click="openEdit(item)">
                  <AppIcon name="edit" :size="16" /> {{ t('common.edit') }}
                </button>
                <button type="button" class="text-red-600" @click="remove(item)">
                  <AppIcon name="trash" :size="16" /> {{ t('common.delete') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
      </DataTableShell>
    </div>

    <AppModal
      :open="creating"
      :title="editingId ? t('common.edit') : t('orgDepartments.add')"
      :subtitle="t('orgDepartments.formHint')"
      icon="building"
      tone="accent"
      size="lg"
      :dirty="dirty"
      @close="closeCreate"
    >
      <form id="department-form" class="departments-form" @submit.prevent="save">
        <div>
          <FieldLabel icon="building">{{ t('orgDepartments.name') }}</FieldLabel>
          <input v-model="form.name" class="field" required maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('orgDepartments.code') }}</FieldLabel>
          <input v-model="form.code" class="field" maxlength="40" />
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('orgDepartments.columns.description') }}</FieldLabel>
          <textarea v-model="form.description" class="field" rows="3" maxlength="240" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgDepartments.columns.parent') }}</FieldLabel>
          <select v-model="form.parentId" class="field">
            <option value="">—</option>
            <option v-for="item in parentOptions" :key="item.id" :value="item.id">{{ item.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="account">{{ t('orgDepartments.columns.manager') }}</FieldLabel>
          <input v-model="form.manager" class="field" maxlength="80" />
        </div>
        <label class="departments-form__check">
          <input v-model="form.active" type="checkbox" />
          {{ t('orgDepartments.active') }}
        </label>
      </form>
      <template #footer>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="closeCreate"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" form="department-form"><AppIcon name="check" :size="16" /> {{ t('common.save') }}</button>
        </div>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.departments {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.departments__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.departments__search {
  display: flex;
  flex: 1;
  min-width: 16rem;
}

.departments__search .field {
  width: 100%;
}

.departments__table td {
  height: auto;
  padding-top: var(--space-3);
  padding-bottom: var(--space-3);
}

.departments__name {
  font-weight: 600;
  color: var(--color-text-primary);
}

.departments__code,
.departments__muted {
  color: var(--color-text-muted);
}

.departments__code {
  margin-top: 2px;
  font-size: var(--text-xs);
}

.departments__actions {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  white-space: nowrap;
}

.departments-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.departments-form__check {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}
</style>
