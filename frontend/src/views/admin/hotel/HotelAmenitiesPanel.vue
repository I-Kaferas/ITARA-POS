<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { formatMoney } from '../../../utils/money'

type Amenity = {
  id: string
  name?: string
  code?: string
  category?: string
  replacement_value_cents?: number
  display_order?: number
  icon_key?: string
  is_active?: boolean
}

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()

const amenities = ref<Amenity[]>([])
const editingId = ref<string | null>(null)
const formOpen = ref(false)
const saving = ref(false)
const loading = ref(false)
const error = ref('')
const form = ref(blankForm())

const categories = computed(() => [
  'other',
  'connectivity',
  'entertainment',
  'climate',
  'bathroom',
  'comfort',
  'security',
  'conference',
] as const)

/** Icons available for amenity selection (must match AppIcon names). */
const amenityIconOptions = [
  // Room / hotel amenities
  'wifi', 'tv', 'ac', 'minibar', 'safe', 'balcony', 'bathtub', 'shower', 'desk',
  'kettle', 'hairdryer', 'projector', 'sound', 'stage', 'catering', 'bed', 'broom',
  'key', 'floors', 'tables', 'parking', 'pool', 'gym', 'coffee', 'iron', 'fridge',
  'microwave', 'laundry', 'elevator', 'wheelchair', 'pets', 'smoking', 'no-smoking',
  'baby', 'towel', 'slippers', 'robe', 'lamp', 'fan', 'heater', 'window', 'garden',
  'restaurant', 'bar', 'spa', 'luggage', 'clock', 'camera', 'music', 'game',
  'water', 'fire', 'leaf', 'sun', 'moon', 'star', 'heart', 'umbrella',
  'car', 'bus', 'plane', 'map', 'globe', 'power', 'plug', 'battery', 'speaker', 'headset',
  // General app icons
  'sparkles', 'lock', 'phone', 'bell', 'mail', 'calendar', 'building', 'package',
  'card', 'coins', 'note', 'tag', 'pin', 'receipt', 'layers', 'check', 'info',
  'alert', 'percent', 'pause', 'search', 'plus', 'import', 'upload', 'filter',
  'adjust', 'transfer', 'shift', 'calculator', 'id-card', 'account', 'customers',
  'organization', 'stores', 'store-pin', 'products', 'catalog', 'inventory',
  'suppliers', 'purchases', 'sales', 'dashboard', 'menu',
  'device-pos', 'device-printer', 'device-tablet', 'device-computer', 'device-other',
  'conn-usb', 'conn-bluetooth',
] as const

const uniqueAmenityIcons = [...new Set(amenityIconOptions)]

const iconChoices = computed(() => {
  const current = form.value.icon_key.trim()
  if (current && !uniqueAmenityIcons.includes(current)) {
    return [current, ...uniqueAmenityIcons]
  }
  return uniqueAmenityIcons
})

const generatedCode = computed(() => {
  if (editingId.value && form.value.code) return form.value.code
  return slugFromName(form.value.name) || '—'
})

const rows = computed(() =>
  amenities.value.slice().sort((a, b) => {
    const order = Number(a.display_order ?? 0) - Number(b.display_order ?? 0)
    if (order !== 0) return order
    return String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })
  }),
)

onMounted(load)

function blankForm() {
  return {
    name: '',
    code: '',
    category: 'other',
    replacement_value: 0,
    display_order: 0,
    icon_key: '',
    is_active: true,
  }
}

function slugFromName(name: string) {
  const slug = name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toUpperCase()
  return slug
}

function categoryLabel(value?: string) {
  const key = value && categories.value.includes(value as typeof categories.value[number]) ? value : 'other'
  return t(`hotel.amenities.categories.${key}`)
}

function selectIcon(key: string) {
  form.value.icon_key = key
}

function clearIcon() {
  form.value.icon_key = ''
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
    const docs = (await api.get<{ data: { docs: Amenity[] } }>('/hospitality')).data.docs
    amenities.value = docs.filter(doc => (doc as Amenity & { kind?: string }).kind === 'amenity')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function openEdit(row: Amenity) {
  editingId.value = row.id
  form.value = {
    name: row.name ?? '',
    code: row.code ?? '',
    category: row.category && categories.value.includes(row.category as typeof categories.value[number]) ? row.category : 'other',
    replacement_value: Number(((row.replacement_value_cents ?? 0) / 100).toFixed(2)),
    display_order: Number(row.display_order ?? 0),
    icon_key: row.icon_key ?? '',
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
    const docs = (await api.post<{ data: { docs: Amenity[] } }>('/hospitality/actions', {
      action: 'upsert_amenity',
      id: editingId.value ?? undefined,
      name: form.value.name.trim(),
      code: editingId.value ? form.value.code : undefined,
      category: form.value.category,
      replacement_value_cents: Math.round(Math.max(0, Number(form.value.replacement_value) || 0) * 100),
      display_order: Number(form.value.display_order) || 0,
      icon_key: form.value.icon_key.trim(),
      is_active: form.value.is_active,
    })).data.docs
    amenities.value = docs.filter(doc => (doc as Amenity & { kind?: string }).kind === 'amenity')
    closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function remove(row: Amenity) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  error.value = ''
  try {
    const docs = (await api.post<{ data: { docs: Amenity[] } }>('/hospitality/actions', {
      action: 'delete_amenity',
      id: row.id,
    })).data.docs
    amenities.value = docs.filter(doc => (doc as Amenity & { kind?: string }).kind === 'amenity')
    if (editingId.value === row.id) closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}
</script>

<template>
  <div class="amenities">
    <div class="amenities__toolbar">
      <p>{{ t('hotel.amenities.hint') }}</p>
      <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
        {{ t('hotel.amenities.createTitle') }}
      </button>
    </div>

    <p v-if="error && !formOpen" class="amenities__error">{{ error }}</p>

    <div class="amenities__list">
      <div class="ui-table-wrap">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('hotel.amenities.name') }}</th>
              <th>{{ t('hotel.amenities.generatedCode') }}</th>
              <th>{{ t('hotel.amenities.category') }}</th>
              <th>{{ t('hotel.amenities.replacementValue') }}</th>
              <th>{{ t('hotel.amenities.displayOrder') }}</th>
              <th>{{ t('products.status') }}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id">
              <td>
                <span class="amenities__name">
                  <AppIcon :name="row.icon_key || 'sparkles'" :size="14" />
                  {{ row.name }}
                </span>
              </td>
              <td class="font-mono">{{ row.code }}</td>
              <td>{{ categoryLabel(row.category) }}</td>
              <td>{{ formatMoney(row.replacement_value_cents ?? 0, 'USD') }}</td>
              <td>{{ row.display_order ?? 0 }}</td>
              <td><StatusBadge :active="row.is_active !== false" /></td>
              <td class="amenities__row-actions">
                <button type="button" class="text-brand-600" @click="openEdit(row)">{{ t('common.edit') }}</button>
                <button type="button" class="text-red-600" @click="remove(row)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!rows.length && !loading" class="amenities__empty">{{ t('hotel.amenities.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.amenities.editTitle') : t('hotel.amenities.createTitle')"
      icon="sparkles"
      size="lg"
      @close="closeForm"
    >
      <form class="amenities__form" @submit.prevent="save">
        <p class="amenities__intro">{{ t('hotel.amenities.hint') }}</p>
        <p class="amenities__code">
          {{ t('hotel.amenities.generatedCode') }}
          <strong>{{ generatedCode }}</strong>
        </p>

        <p v-if="error" class="amenities__error">{{ error }}</p>

        <div class="amenities__grid">
          <div class="ui-field">
            <FieldLabel icon="sparkles">{{ t('hotel.amenities.name') }}</FieldLabel>
            <input
              v-model="form.name"
              required
              class="ui-input"
              :placeholder="t('hotel.amenities.namePlaceholder')"
            >
          </div>
          <div class="ui-field">
            <FieldLabel icon="layers">{{ t('hotel.amenities.category') }}</FieldLabel>
            <select v-model="form.category" class="ui-select">
              <option v-for="item in categories" :key="item" :value="item">{{ categoryLabel(item) }}</option>
            </select>
          </div>
          <div class="ui-field">
            <FieldLabel icon="coins">{{ t('hotel.amenities.replacementValue') }} *</FieldLabel>
            <div class="amenities__money">
              <span>$</span>
              <input
                v-model.number="form.replacement_value"
                type="number"
                min="0"
                step="0.01"
                required
                class="ui-input"
              >
            </div>
          </div>
          <div class="ui-field">
            <FieldLabel icon="adjust">{{ t('hotel.amenities.displayOrder') }}</FieldLabel>
            <input v-model.number="form.display_order" type="number" class="ui-input">
          </div>
          <div class="ui-field amenities__span">
            <FieldLabel icon="sparkles">{{ t('hotel.amenities.iconKey') }}</FieldLabel>
            <div class="icon-picker" role="listbox" :aria-label="t('hotel.amenities.iconKey')">
              <button
                type="button"
                class="icon-picker__item"
                :class="{ 'icon-picker__item--active': !form.icon_key }"
                :aria-selected="!form.icon_key"
                :title="t('hotel.amenities.iconNone')"
                @click="clearIcon"
              >
                <span class="icon-picker__none">—</span>
              </button>
              <button
                v-for="icon in iconChoices"
                :key="icon"
                type="button"
                class="icon-picker__item"
                :class="{ 'icon-picker__item--active': form.icon_key === icon }"
                :aria-selected="form.icon_key === icon"
                :title="icon"
                @click="selectIcon(icon)"
              >
                <AppIcon :name="icon" :size="18" />
              </button>
            </div>
          </div>
          <label class="amenities__check">
            <input v-model="form.is_active" type="checkbox">
            <span>{{ t('products.active') }}</span>
          </label>
        </div>

        <div class="amenities__actions">
          <button type="button" class="ui-btn" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="ui-btn ui-btn--primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </div>
</template>

<style scoped>
.amenities {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 1rem;
}

.amenities__toolbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.amenities__toolbar p {
  margin: 0;
  max-width: 40rem;
  font-size: 0.875rem;
  color: #66727c;
  line-height: 1.45;
}

.amenities__form {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.amenities__intro {
  margin: 0;
  font-size: 0.875rem;
  color: #66727c;
  line-height: 1.45;
}

.amenities__code {
  margin: 0;
  font-size: 0.8rem;
  color: #66727c;
}

.amenities__code strong {
  margin-left: 0.35rem;
  font-family: var(--font-mono);
  color: #1a2833;
}

.amenities__error {
  margin: 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 0.85rem;
}

.amenities__grid {
  display: grid;
  gap: 0.9rem 1rem;
  grid-template-columns: 1fr;
}

@media (min-width: 640px) {
  .amenities__grid {
    grid-template-columns: 1fr 1fr;
  }

  .amenities__span {
    grid-column: 1 / -1;
  }
}

.amenities__money {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 0.4rem;
}

.amenities__money span {
  font-weight: 700;
  color: #3d5c73;
}

.icon-picker {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(2.4rem, 1fr));
  gap: 0.4rem;
  padding: 0.55rem;
  border: 1px solid #d7e0e7;
  border-radius: 0.75rem;
  background: #f8fafb;
  max-height: 16rem;
  overflow-y: auto;
}

.icon-picker__item {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  height: 2.4rem;
  border: 1px solid transparent;
  border-radius: 0.55rem;
  background: #fff;
  color: #4a6272;
  cursor: pointer;
  transition: border-color 0.12s ease, background 0.12s ease, color 0.12s ease;
}

.icon-picker__item:hover {
  border-color: #b7c9d6;
  color: #1a2833;
}

.icon-picker__item--active {
  border-color: var(--color-brand-500, #2f6fed);
  background: color-mix(in srgb, var(--color-brand-500, #2f6fed) 12%, #fff);
  color: var(--color-brand-700, #1d4ed8);
}

.icon-picker__none {
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1;
  color: #8a9aa6;
}

.amenities__check {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin-top: 1.55rem;
  font-size: 0.875rem;
  color: #1c2830;
}

.amenities__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.55rem;
  margin-top: 0.5rem;
}

.amenities__name {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  font-weight: 600;
}

.amenities__row-actions {
  text-align: right;
  white-space: nowrap;
}

.amenities__row-actions button + button {
  margin-left: 0.7rem;
}

.amenities__empty {
  margin: 0;
  padding: 1.4rem;
  text-align: center;
  color: #66727c;
  font-size: 0.875rem;
}

.text-brand-600 { color: var(--color-brand-600); }
.text-red-600 { color: #dc2626; }
</style>
