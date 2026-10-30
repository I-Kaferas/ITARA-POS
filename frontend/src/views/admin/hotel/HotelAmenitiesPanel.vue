<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { getAppCurrency } from '../../../utils/currency'
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

type StatusFilter = 'all' | 'active' | 'inactive'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()

const amenities = ref<Amenity[]>([])
const editingId = ref<string | null>(null)
const formOpen = ref(false)
const saving = ref(false)
const loading = ref(false)
const error = ref('')
const form = ref(blankForm())
const search = ref('')
const categoryFilter = ref<string>('all')
const statusFilter = ref<StatusFilter>('all')
const iconQuery = ref('')

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

const CATEGORY_TONES: Record<string, string> = {
  connectivity: '#2f6fed',
  entertainment: '#6366f1',
  climate: '#0f9f8f',
  bathroom: '#0891b2',
  comfort: '#ea8a12',
  security: '#e0533a',
  conference: '#e8478f',
  other: '#64748b',
}

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

const uniqueAmenityIcons: string[] = [...new Set(amenityIconOptions)]

const iconChoices = computed(() => {
  const current = form.value.icon_key.trim()
  const list = current && !uniqueAmenityIcons.includes(current)
    ? [current, ...uniqueAmenityIcons]
    : uniqueAmenityIcons
  const query = iconQuery.value.trim().toLowerCase()
  return query ? list.filter(icon => icon.includes(query)) : list
})

const generatedCode = computed(() => {
  if (editingId.value && form.value.code) return form.value.code
  return slugFromName(form.value.name) || '—'
})

const currency = computed(() => getAppCurrency())

const rows = computed(() =>
  amenities.value.slice().sort((a, b) => {
    const order = Number(a.display_order ?? 0) - Number(b.display_order ?? 0)
    if (order !== 0) return order
    return String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })
  }),
)

const summary = computed(() => {
  const active = amenities.value.filter(row => row.is_active !== false).length
  return {
    total: amenities.value.length,
    active,
    inactive: amenities.value.length - active,
    categories: new Set(amenities.value.map(row => normalizeCategory(row.category))).size,
    value: amenities.value.reduce((sum, row) => sum + (Number(row.replacement_value_cents) || 0), 0),
  }
})

const categoryTabs = computed(() => {
  const counts = new Map<string, number>()
  amenities.value.forEach(row => {
    const key = normalizeCategory(row.category)
    counts.set(key, (counts.get(key) ?? 0) + 1)
  })
  return [
    { key: 'all', label: t('hotel.amenities.all'), count: amenities.value.length },
    ...categories.value
      .filter(key => counts.has(key))
      .map(key => ({ key, label: categoryLabel(key), count: counts.get(key) ?? 0 })),
  ]
})

const filtered = computed(() => {
  const query = search.value.trim().toLowerCase()
  return rows.value.filter(row => {
    if (categoryFilter.value !== 'all' && normalizeCategory(row.category) !== categoryFilter.value) return false
    if (statusFilter.value === 'active' && row.is_active === false) return false
    if (statusFilter.value === 'inactive' && row.is_active !== false) return false
    if (!query) return true
    return String(row.name ?? '').toLowerCase().includes(query)
      || String(row.code ?? '').toLowerCase().includes(query)
  })
})

const hasFilters = computed(() =>
  Boolean(search.value.trim()) || categoryFilter.value !== 'all' || statusFilter.value !== 'all',
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

function normalizeCategory(value?: string) {
  return value && categories.value.includes(value as typeof categories.value[number]) ? value : 'other'
}

function categoryLabel(value?: string) {
  return t(`hotel.amenities.categories.${normalizeCategory(value)}`)
}

function toneOf(value?: string) {
  return CATEGORY_TONES[normalizeCategory(value)]
}

function clearFilters() {
  search.value = ''
  categoryFilter.value = 'all'
  statusFilter.value = 'all'
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
  iconQuery.value = ''
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
  resetForm()
  editingId.value = row.id
  form.value = {
    name: row.name ?? '',
    code: row.code ?? '',
    category: normalizeCategory(row.category),
    replacement_value: Number(((row.replacement_value_cents ?? 0) / 100).toFixed(2)),
    display_order: Number(row.display_order ?? 0),
    icon_key: row.icon_key ?? '',
    is_active: row.is_active !== false,
  }
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
    <header class="am-head">
      <p class="am-head__hint">{{ t('hotel.amenities.hint') }}</p>
      <button type="button" class="btn-primary" @click="openCreate">
        <AppIcon name="plus" :size="16" />
        {{ t('hotel.amenities.createTitle') }}
      </button>
    </header>

    <dl class="am-stats">
      <div class="am-stat">
        <span class="am-stat__icon am-stat__icon--navy" aria-hidden="true"><AppIcon name="sparkles" :size="18" /></span>
        <div>
          <dt>{{ t('hotel.amenities.total') }}</dt>
          <dd>{{ summary.total }}</dd>
        </div>
      </div>
      <div class="am-stat">
        <span class="am-stat__icon am-stat__icon--green" aria-hidden="true"><AppIcon name="check" :size="18" /></span>
        <div>
          <dt>{{ t('hotel.amenities.active') }}</dt>
          <dd>{{ summary.active }}<small v-if="summary.inactive"> · {{ summary.inactive }} {{ t('hotel.amenities.inactive').toLowerCase() }}</small></dd>
        </div>
      </div>
      <div class="am-stat">
        <span class="am-stat__icon am-stat__icon--violet" aria-hidden="true"><AppIcon name="layers" :size="18" /></span>
        <div>
          <dt>{{ t('hotel.amenities.categoriesCount') }}</dt>
          <dd>{{ summary.categories }}</dd>
        </div>
      </div>
      <div class="am-stat">
        <span class="am-stat__icon am-stat__icon--amber" aria-hidden="true"><AppIcon name="coins" :size="18" /></span>
        <div>
          <dt>{{ t('hotel.amenities.totalValue') }}</dt>
          <dd>{{ formatMoney(summary.value) }}</dd>
        </div>
      </div>
    </dl>

    <div class="am-filters">
      <label class="am-search">
        <AppIcon name="search" :size="16" />
        <input
          v-model="search"
          type="search"
          :placeholder="t('hotel.amenities.searchPlaceholder')"
          :aria-label="t('hotel.amenities.searchPlaceholder')"
        >
      </label>
      <div class="am-segment" role="group" :aria-label="t('products.status')">
        <button
          v-for="option in (['all', 'active', 'inactive'] as const)"
          :key="option"
          type="button"
          :class="{ 'is-active': statusFilter === option }"
          :aria-pressed="statusFilter === option"
          @click="statusFilter = option"
        >
          {{ t(`hotel.amenities.${option}`) }}
        </button>
      </div>
    </div>

    <div v-if="categoryTabs.length > 2" class="am-chips" role="group" :aria-label="t('hotel.amenities.category')">
      <button
        v-for="tab in categoryTabs"
        :key="tab.key"
        type="button"
        class="am-chip"
        :class="{ 'is-active': categoryFilter === tab.key }"
        :style="tab.key !== 'all' ? { '--tone': toneOf(tab.key) } : undefined"
        :aria-pressed="categoryFilter === tab.key"
        @click="categoryFilter = tab.key"
      >
        <i v-if="tab.key !== 'all'" aria-hidden="true" />
        {{ tab.label }}
        <span>{{ tab.count }}</span>
      </button>
    </div>

    <p v-if="error && !formOpen" class="am-error" role="alert">
      <AppIcon name="alert" :size="16" />
      {{ error }}
    </p>

    <LoadingBlock v-if="loading && !amenities.length" variant="cards" :rows="6" :label="t('common.loading')" />

    <div v-else-if="!amenities.length" class="am-empty">
      <span class="am-empty__icon" aria-hidden="true"><AppIcon name="sparkles" :size="26" /></span>
      <p class="am-empty__title">{{ t('hotel.amenities.empty') }}</p>
      <p class="am-empty__desc">{{ t('hotel.amenities.emptyHint') }}</p>
      <button type="button" class="btn-primary" @click="openCreate">
        <AppIcon name="plus" :size="16" />
        {{ t('hotel.amenities.createTitle') }}
      </button>
    </div>

    <div v-else-if="!filtered.length" class="am-empty">
      <span class="am-empty__icon" aria-hidden="true"><AppIcon name="search" :size="24" /></span>
      <p class="am-empty__title">{{ t('hotel.amenities.noResults') }}</p>
      <button v-if="hasFilters" type="button" class="btn-secondary" @click="clearFilters">
        {{ t('hotel.amenities.clearFilters') }}
      </button>
    </div>

    <ul v-else class="am-grid stagger-in">
      <li
        v-for="row in filtered"
        :key="row.id"
        class="am-card"
        :class="{ 'is-inactive': row.is_active === false }"
        :style="{ '--tone': toneOf(row.category) }"
      >
        <div class="am-card__top">
          <span class="am-card__icon" aria-hidden="true">
            <AppIcon :name="row.icon_key || 'sparkles'" :size="22" />
          </span>
          <div class="am-card__title">
            <h3>{{ row.name }}</h3>
            <code>{{ row.code }}</code>
          </div>
          <span class="am-status" :class="row.is_active === false ? 'am-status--off' : 'am-status--on'">
            {{ row.is_active === false ? t('products.inactive') : t('products.active') }}
          </span>
        </div>

        <div class="am-card__tags">
          <span class="am-tag">{{ categoryLabel(row.category) }}</span>
          <span class="am-order" :title="t('hotel.amenities.displayOrder')">#{{ row.display_order ?? 0 }}</span>
        </div>

        <div class="am-card__foot">
          <div class="am-card__value">
            <span>{{ t('hotel.amenities.replacementShort') }}</span>
            <strong>{{ formatMoney(row.replacement_value_cents ?? 0) }}</strong>
          </div>
          <div class="am-card__actions">
            <button
              type="button"
              class="am-icon-btn"
              :title="t('common.edit')"
              :aria-label="`${t('common.edit')} ${row.name ?? ''}`"
              @click="openEdit(row)"
            >
              <AppIcon name="edit" :size="16" />
            </button>
            <button
              type="button"
              class="am-icon-btn am-icon-btn--danger"
              :title="t('common.delete')"
              :aria-label="`${t('common.delete')} ${row.name ?? ''}`"
              @click="remove(row)"
            >
              <AppIcon name="trash" :size="16" />
            </button>
          </div>
        </div>
      </li>
    </ul>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.amenities.editTitle') : t('hotel.amenities.createTitle')"
      icon="sparkles"
      size="lg"
      @close="closeForm"
    >
      <form class="am-form" @submit.prevent="save">
        <div class="am-preview" :style="{ '--tone': toneOf(form.category) }">
          <span class="am-card__icon" aria-hidden="true">
            <AppIcon :name="form.icon_key || 'sparkles'" :size="24" />
          </span>
          <div class="am-preview__copy">
            <span class="am-preview__eyebrow">{{ t('hotel.amenities.preview') }}</span>
            <strong>{{ form.name.trim() || t('hotel.amenities.namePlaceholder') }}</strong>
            <span class="am-preview__meta">
              <code>{{ generatedCode }}</code>
              <span class="am-tag">{{ categoryLabel(form.category) }}</span>
            </span>
          </div>
          <span class="am-status" :class="form.is_active ? 'am-status--on' : 'am-status--off'">
            {{ form.is_active ? t('products.active') : t('products.inactive') }}
          </span>
        </div>

        <p v-if="error" class="am-error" role="alert">
          <AppIcon name="alert" :size="16" />
          {{ error }}
        </p>

        <div class="am-form__grid">
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
            <div class="am-money">
              <input
                v-model.number="form.replacement_value"
                type="number"
                min="0"
                step="0.01"
                required
                class="ui-input"
              >
              <span>{{ currency }}</span>
            </div>
          </div>
          <div class="ui-field">
            <FieldLabel icon="adjust">{{ t('hotel.amenities.displayOrder') }}</FieldLabel>
            <input v-model.number="form.display_order" type="number" min="0" class="ui-input">
          </div>

          <div class="ui-field am-form__span">
            <div class="am-icons__head">
              <FieldLabel icon="sparkles">{{ t('hotel.amenities.iconKey') }}</FieldLabel>
              <label class="am-search am-search--sm">
                <AppIcon name="search" :size="14" />
                <input
                  v-model="iconQuery"
                  type="search"
                  :placeholder="t('hotel.amenities.iconSearch')"
                  :aria-label="t('hotel.amenities.iconSearch')"
                >
              </label>
            </div>
            <div class="icon-picker" role="listbox" :aria-label="t('hotel.amenities.iconKey')">
              <button
                type="button"
                role="option"
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
                role="option"
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

          <label class="am-switch am-form__span">
            <input v-model="form.is_active" type="checkbox">
            <span class="am-switch__track" aria-hidden="true"><span /></span>
            <span>{{ t('products.active') }}</span>
          </label>
        </div>

        <div class="am-form__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'ui-btn--loading': saving }" :disabled="saving">
            <AppIcon name="check" :size="16" />
            {{ saving ? t('common.saving') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </div>
</template>

<style scoped>
.amenities {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  margin-top: var(--space-2);
}

/* ─── Header ──────────────────────────────────────────────────────── */
.am-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
}

.am-head__hint {
  max-width: 62ch;
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  line-height: 1.55;
}

/* ─── Summary ─────────────────────────────────────────────────────── */
.am-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-3);
  margin: 0;
}

.am-stat {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-width: 0;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}

.am-stat > div {
  min-width: 0;
}

.am-stat dt {
  overflow: hidden;
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.am-stat dd {
  margin: 2px 0 0;
  overflow: hidden;
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.am-stat dd small {
  color: var(--color-text-faint);
  font-family: var(--font-sans);
  font-size: var(--text-2xs);
  font-weight: 500;
  letter-spacing: 0;
}

.am-stat__icon {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
  color: var(--tone);
}

.am-stat__icon--navy { --tone: var(--color-brand-500); }
.am-stat__icon--green { --tone: #10a36b; }
.am-stat__icon--violet { --tone: #6366f1; }
.am-stat__icon--amber { --tone: #ea8a12; }

/* ─── Filters ─────────────────────────────────────────────────────── */
.am-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.am-search {
  display: flex;
  flex: 1 1 260px;
  align-items: center;
  gap: var(--space-2);
  min-height: var(--control-md, 40px);
  padding: 0 var(--space-3);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-faint);
  transition: border-color var(--motion-fast) var(--ease-out), box-shadow var(--motion-fast) var(--ease-out);
}

.am-search:focus-within {
  border-color: var(--color-brand-500);
  box-shadow: 0 0 0 3px var(--color-focus-ring);
}

.amenities .am-search input {
  flex: 1;
  min-width: 0;
  min-height: 0 !important;
  padding: 0 !important;
  border: 0 !important;
  outline: 0 !important;
  box-shadow: none !important;
  background: transparent !important;
  color: var(--color-text-primary);
  font-size: var(--text-sm);
}

.am-search--sm {
  flex: 0 1 220px;
  min-height: 34px;
}

.am-segment {
  display: inline-flex;
  padding: 3px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface-muted);
}

.am-segment button {
  min-height: 34px;
  padding: 0 var(--space-4);
  border: 0;
  border-radius: calc(var(--radius-md) - 3px);
  background: transparent;
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
  cursor: pointer;
  transition: background-color var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.am-segment button:hover {
  color: var(--color-text-primary);
}

.am-segment button.is-active {
  background: var(--color-surface);
  color: var(--color-text-primary);
  box-shadow: var(--shadow-xs);
}

.am-chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.am-chip {
  --tone: var(--color-brand-500);
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 34px;
  padding: 0 var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: var(--text-xs);
  font-weight: 600;
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
}

.am-chip i {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--tone);
}

.am-chip span {
  min-width: 20px;
  padding: 0 6px;
  border-radius: 999px;
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
  font-size: var(--text-2xs);
  line-height: 18px;
  text-align: center;
}

.am-chip:hover {
  border-color: color-mix(in srgb, var(--tone) 45%, var(--color-border));
}

.am-chip.is-active {
  border-color: color-mix(in srgb, var(--tone) 55%, transparent);
  background: color-mix(in srgb, var(--tone) 10%, var(--color-surface));
  color: var(--color-text-primary);
}

.am-chip.is-active span {
  background: var(--tone);
  color: #fff;
}

.am-segment button:focus-visible,
.am-chip:focus-visible,
.am-icon-btn:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.am-error {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  padding: var(--space-3) var(--space-4);
  border: 1px solid color-mix(in srgb, var(--color-danger) 25%, transparent);
  border-radius: var(--radius-md);
  background: var(--color-danger-bg);
  color: var(--color-danger);
  font-size: var(--text-sm);
  font-weight: 500;
}

/* ─── Empty states ────────────────────────────────────────────────── */
.am-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-10, 2.5rem) var(--space-6);
  border: 1px dashed var(--color-border-strong);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  text-align: center;
}

.am-empty__icon {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  margin-bottom: var(--space-2);
  border-radius: 18px;
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
}

.am-empty__title {
  margin: 0;
  color: var(--color-text-primary);
  font-size: var(--text-md);
  font-weight: 600;
}

.am-empty__desc {
  max-width: 48ch;
  margin: 0 0 var(--space-3);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

/* ─── Cards ───────────────────────────────────────────────────────── */
.am-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(270px, 1fr));
  gap: var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
}

.am-card {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  min-width: 0;
  padding: var(--space-5);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  transition:
    border-color var(--motion-normal) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.am-card:hover {
  border-color: color-mix(in srgb, var(--tone) 35%, var(--color-border));
  box-shadow: var(--shadow-md);
  transform: var(--lift);
}

.am-card.is-inactive {
  background: var(--color-surface-muted);
}

.am-card.is-inactive .am-card__icon {
  filter: grayscale(1);
  opacity: 0.6;
}

.am-card__top {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
}

.am-card__icon {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 14px;
  background: color-mix(in srgb, var(--tone) 12%, transparent);
  color: var(--tone);
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--tone) 18%, transparent);
}

.am-card__title {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.am-card__title h3 {
  margin: 0;
  overflow: hidden;
  color: var(--color-text-primary);
  font-size: var(--text-base);
  font-weight: 700;
  line-height: 1.35;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.am-card__title code,
.am-preview__meta code {
  overflow: hidden;
  color: var(--color-text-faint);
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: var(--text-2xs);
  font-weight: 600;
  letter-spacing: 0.03em;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.am-status {
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: 6px;
  padding: 2px 10px 2px 8px;
  border-radius: 999px;
  font-size: var(--text-2xs);
  font-weight: 700;
}

.am-status::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 999px;
  background: currentColor;
}

.am-status--on {
  background: var(--color-success-bg);
  color: var(--color-success);
}

.am-status--off {
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
  box-shadow: inset 0 0 0 1px var(--color-border);
}

.am-card__tags {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
}

.am-tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 10px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--tone) 10%, transparent);
  color: color-mix(in srgb, var(--tone) 80%, var(--color-text-primary));
  font-size: var(--text-2xs);
  font-weight: 600;
  white-space: nowrap;
}

.am-order {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.am-card__foot {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-3);
  margin-top: auto;
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-table-border, var(--color-border));
}

.am-card__value {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.am-card__value span {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 600;
}

.am-card__value strong {
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-variant-numeric: tabular-nums;
}

.am-card__actions {
  display: flex;
  gap: var(--space-1);
}

.am-icon-btn {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
}

.am-icon-btn:hover {
  border-color: var(--color-brand-300);
  background: var(--color-brand-50);
  color: var(--color-ink-brand);
}

.am-icon-btn--danger:hover {
  border-color: color-mix(in srgb, var(--color-danger) 35%, transparent);
  background: var(--color-danger-bg);
  color: var(--color-danger);
}

/* ─── Form ────────────────────────────────────────────────────────── */
.am-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.am-preview {
  display: flex;
  align-items: center;
  gap: var(--space-4);
  padding: var(--space-4);
  border: 1px solid color-mix(in srgb, var(--tone) 22%, var(--color-border));
  border-radius: var(--radius-xl);
  background: color-mix(in srgb, var(--tone) 5%, var(--color-surface));
}

.am-preview__copy {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.am-preview__eyebrow {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.am-preview__copy strong {
  overflow: hidden;
  color: var(--color-text-primary);
  font-size: var(--text-md);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.am-preview__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}

.am-form__grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-4);
}

@media (min-width: 640px) {
  .am-form__grid {
    grid-template-columns: 1fr 1fr;
  }

  .am-form__span {
    grid-column: 1 / -1;
  }
}

.am-money {
  position: relative;
}

.am-money .ui-input {
  width: 100%;
  padding-right: 3.5rem;
}

.am-money span {
  position: absolute;
  top: 50%;
  right: var(--space-3);
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 700;
  pointer-events: none;
  transform: translateY(-50%);
}

.am-icons__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
}

.icon-picker {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(2.5rem, 1fr));
  gap: 0.4rem;
  max-height: 14rem;
  padding: var(--space-2);
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface-muted);
}

.icon-picker__item {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  color: var(--color-text-muted);
  cursor: pointer;
  transition: border-color var(--motion-fast) ease, background var(--motion-fast) ease, color var(--motion-fast) ease;
}

.icon-picker__item:hover {
  border-color: var(--color-border-strong);
  color: var(--color-text-primary);
}

.icon-picker__item--active {
  border-color: var(--color-brand-500);
  background: color-mix(in srgb, var(--color-brand-500) 12%, var(--color-surface));
  color: var(--color-ink-brand);
}

.icon-picker__none {
  color: var(--color-text-faint);
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1;
}

.am-switch {
  display: inline-flex;
  align-items: center;
  gap: var(--space-3);
  width: fit-content;
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-weight: 600;
  cursor: pointer;
}

.am-switch input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.am-switch__track {
  position: relative;
  width: 40px;
  height: 22px;
  border-radius: 999px;
  background: var(--color-border-strong);
  transition: background-color var(--motion-fast) var(--ease-out);
}

.am-switch__track span {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 16px;
  height: 16px;
  border-radius: 999px;
  background: #fff;
  box-shadow: var(--shadow-xs);
  transition: transform var(--motion-fast) var(--ease-out);
}

.am-switch input:checked + .am-switch__track {
  background: var(--color-success);
}

.am-switch input:checked + .am-switch__track span {
  transform: translateX(18px);
}

.am-switch input:focus-visible + .am-switch__track {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.am-form__actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  padding-top: var(--space-4);
  border-top: 1px solid var(--color-table-border, var(--color-border));
}

/* ─── Responsive ──────────────────────────────────────────────────── */
@media (max-width: 1100px) {
  .am-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .am-stats {
    grid-template-columns: 1fr;
  }

  .am-segment {
    width: 100%;
  }

  .am-segment button {
    flex: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .am-card:hover {
    transform: none;
  }
}
</style>
