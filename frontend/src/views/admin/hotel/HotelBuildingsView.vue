<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import HotelChrome from './HotelChrome.vue'

type Doc = {
  id: string
  kind?: string
  name?: string
  display_order?: number
  is_active?: boolean
}

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()

const buildings = ref<Doc[]>([])
const editingId = ref<string | null>(null)
const formOpen = ref(false)
const saving = ref(false)
const loading = ref(false)
const error = ref('')
const form = ref(blankForm())

const rows = computed(() =>
  buildings.value.slice().sort((a, b) => {
    const order = Number(a.display_order ?? 0) - Number(b.display_order ?? 0)
    if (order !== 0) return order
    return String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })
  }),
)

onMounted(load)

function blankForm() {
  return {
    name: '',
    display_order: 0,
    is_active: true,
  }
}

function resetForm() {
  editingId.value = null
  form.value = blankForm()
  error.value = ''
}

function openCreate() {
  resetForm()
  formOpen.value = true
}

function closeForm() {
  formOpen.value = false
  resetForm()
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const docs = (await api.get<{ data: { docs: Doc[] } }>('/hospitality')).data.docs
    buildings.value = docs.filter(doc => doc.kind === 'building')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function openEdit(row: Doc) {
  editingId.value = row.id
  form.value = {
    name: row.name ?? '',
    display_order: Number(row.display_order ?? 0),
    is_active: row.is_active !== false,
  }
  error.value = ''
  formOpen.value = true
}

async function save() {
  if (!form.value.name.trim()) return
  saving.value = true
  error.value = ''
  try {
    const docs = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'upsert_building',
      id: editingId.value ?? undefined,
      name: form.value.name.trim(),
      display_order: Number(form.value.display_order) || 0,
      is_active: form.value.is_active,
    })).data.docs
    buildings.value = docs.filter(doc => doc.kind === 'building')
    closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function remove(row: Doc) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  error.value = ''
  try {
    const docs = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'delete_building',
      id: row.id,
    })).data.docs
    buildings.value = docs.filter(doc => doc.kind === 'building')
    if (editingId.value === row.id) closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}
</script>

<template>
  <HotelChrome>
    <div class="hotel-crud">
      <div class="hotel-crud__toolbar">
        <p>{{ t('hotel.buildings.hint') }}</p>
        <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
          {{ t('hotel.buildings.createTitle') }}
        </button>
      </div>

      <p v-if="error && !formOpen" class="hotel-crud__error">{{ error }}</p>

      <div class="hotel-crud__list">
        <div class="ui-table-wrap">
          <table class="ui-table">
            <thead>
              <tr>
                <th>{{ t('hotel.buildings.name') }}</th>
                <th>{{ t('hotel.buildings.displayOrder') }}</th>
                <th>{{ t('products.status') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in rows" :key="row.id">
                <td class="font-semibold">{{ row.name }}</td>
                <td>{{ row.display_order ?? 0 }}</td>
                <td><StatusBadge :active="row.is_active !== false" /></td>
                <td class="hotel-crud__row-actions">
                  <button type="button" class="text-brand-600" @click="openEdit(row)">{{ t('common.edit') }}</button>
                  <button type="button" class="text-red-600" @click="remove(row)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!rows.length && !loading" class="hotel-crud__empty">{{ t('hotel.buildings.empty') }}</p>
        </div>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.buildings.editTitle') : t('hotel.buildings.createTitle')"
      icon="building"
      size="lg"
      @close="closeForm"
    >
      <form class="hotel-crud__form" @submit.prevent="save">
        <p class="hotel-crud__intro">{{ t('hotel.buildings.hint') }}</p>
        <p v-if="error" class="hotel-crud__error">{{ error }}</p>

        <div class="hotel-crud__grid">
          <div>
            <FieldLabel icon="building">{{ t('hotel.buildings.name') }} *</FieldLabel>
            <input
              v-model="form.name"
              required
              class="field"
              :placeholder="t('hotel.buildings.namePlaceholder')"
            >
          </div>
          <div>
            <FieldLabel icon="adjust">{{ t('hotel.buildings.displayOrder') }}</FieldLabel>
            <input v-model.number="form.display_order" type="number" class="field">
          </div>
        </div>

        <label class="hotel-switch">
          <input v-model="form.is_active" type="checkbox">
          <span class="hotel-switch__track" aria-hidden="true" />
          <span>{{ t('products.active') }}</span>
        </label>

        <div class="hotel-crud__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.hotel-crud {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 1rem;
}

.hotel-crud__toolbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.hotel-crud__toolbar p,
.hotel-crud__intro {
  margin: 0;
  max-width: 40rem;
  font-size: 0.875rem;
  color: #66727c;
  line-height: 1.45;
}

.hotel-crud__form {
  display: flex;
  flex-direction: column;
}

.hotel-crud__error {
  margin: 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 0.85rem;
}

.hotel-crud__grid {
  display: grid;
  gap: 0.9rem 1rem;
  margin-top: 1.1rem;
  grid-template-columns: 1fr;
}

@media (min-width: 640px) {
  .hotel-crud__grid {
    grid-template-columns: 1fr 1fr;
  }
}

.hotel-switch {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  margin-top: 1.05rem;
  font-size: 0.875rem;
  color: #334155;
  cursor: pointer;
}

.hotel-switch input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.hotel-switch__track {
  width: 2.4rem;
  height: 1.3rem;
  border-radius: 999px;
  background: #cbd5e1;
  position: relative;
  transition: background 0.16s ease;
}

.hotel-switch__track::after {
  content: '';
  position: absolute;
  top: 0.14rem;
  left: 0.16rem;
  width: 1.02rem;
  height: 1.02rem;
  border-radius: 999px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.2);
  transition: transform 0.16s ease;
}

.hotel-switch input:checked + .hotel-switch__track {
  background: #0f766e;
}

.hotel-switch input:checked + .hotel-switch__track::after {
  transform: translateX(1.05rem);
}

.hotel-crud__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.55rem;
  margin-top: 1.15rem;
}

.hotel-crud__row-actions {
  text-align: right;
  white-space: nowrap;
}

.hotel-crud__row-actions button + button {
  margin-left: 0.7rem;
}

.hotel-crud__empty {
  margin: 0;
  padding: 1.4rem;
  text-align: center;
  color: #66727c;
  font-size: 0.875rem;
}

.font-semibold { font-weight: 600; }
.text-brand-600 { color: var(--color-brand-600); }
.text-red-600 { color: #dc2626; }
</style>
