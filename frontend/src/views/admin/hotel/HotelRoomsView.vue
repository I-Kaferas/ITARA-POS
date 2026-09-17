<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_ROOM_KINDS } from '../../../api/hospitality'
import { useConfirm } from '../../../composables/useConfirm'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type SpaceKind = 'guest_room' | 'conference' | 'reception'
type Mode = 'single' | 'range'
type HkStatus = 'clean' | 'dirty' | 'cleaning' | 'inspected' | 'maintenance' | 'out_of_service'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const docs = ref<Doc[]>([])
const editingId = ref<string | null>(null)
const selectedCategoryId = ref<string | null>(null)
const saving = ref(false)
const hkSavingId = ref<string | null>(null)
const loading = ref(false)
const error = ref('')
const galleryOpen = ref(false)
const formOpen = ref(false)
const form = ref(blankForm())

const spaceKinds: { id: SpaceKind; titleKey: string; hintKey: string; icon: string }[] = [
  { id: 'guest_room', titleKey: 'hotel.roomTypes.space.guest', hintKey: 'hotel.roomTypes.space.guestHint', icon: 'bed' },
  { id: 'conference', titleKey: 'hotel.roomTypes.space.conference', hintKey: 'hotel.roomTypes.space.conferenceHint', icon: 'organization' },
  { id: 'reception', titleKey: 'hotel.roomTypes.space.reception', hintKey: 'hotel.roomTypes.space.receptionHint', icon: 'sparkles' },
]

const housekeepingStatuses: HkStatus[] = ['clean', 'dirty', 'cleaning', 'inspected', 'maintenance', 'out_of_service']

const hkMeta: Record<HkStatus, { icon: string; tone: string }> = {
  clean: { icon: 'check', tone: 'clean' },
  dirty: { icon: 'alert', tone: 'dirty' },
  cleaning: { icon: 'broom', tone: 'cleaning' },
  inspected: { icon: 'sparkles', tone: 'inspected' },
  maintenance: { icon: 'adjust', tone: 'maintenance' },
  out_of_service: { icon: 'pause', tone: 'oos' },
}

const buildings = computed(() => docs.value.filter(d => d.kind === 'building'))
const wings = computed(() => docs.value.filter(d => d.kind === 'wing'))
const floors = computed(() => docs.value.filter(d => d.kind === 'floor'))
const roomTypes = computed(() => docs.value.filter(d => d.kind === 'room_type'))
const rooms = computed(() => docs.value.filter(d => d.kind === 'room'))

const activeBuildings = computed(() =>
  buildings.value
    .filter(item => item.is_active !== false)
    .slice()
    .sort(sortByOrderThenName),
)

const buildingOptions = computed(() => {
  const map = new Map(activeBuildings.value.map(item => [item.id, item]))
  if (form.value.building_id && !map.has(form.value.building_id)) {
    const current = buildings.value.find(item => item.id === form.value.building_id)
    if (current) map.set(current.id, current)
  }
  return [...map.values()]
})

const wingOptions = computed(() => {
  const list = wings.value
    .filter(item => item.building_id === form.value.building_id && item.is_active !== false)
    .slice()
    .sort(sortByOrderThenName)
  const map = new Map(list.map(item => [item.id, item]))
  if (form.value.wing_id && !map.has(form.value.wing_id)) {
    const current = wings.value.find(item => item.id === form.value.wing_id)
    if (current) map.set(current.id, current)
  }
  return [...map.values()]
})

const floorOptions = computed(() => {
  const list = floors.value
    .filter((item) => {
      if (item.building_id !== form.value.building_id || item.is_active === false) return false
      if (!form.value.wing_id) return true
      return !item.wing_id || item.wing_id === form.value.wing_id
    })
    .slice()
    .sort((a, b) => Number(a.floor_number ?? 0) - Number(b.floor_number ?? 0))
  const map = new Map(list.map(item => [item.id, item]))
  if (form.value.floor_id && !map.has(form.value.floor_id)) {
    const current = floors.value.find(item => item.id === form.value.floor_id)
    if (current) map.set(current.id, current)
  }
  return [...map.values()]
})

const typeOptions = computed(() => {
  const list = roomTypes.value
    .filter(item => item.is_active !== false && item.status !== 'inactive')
    .filter(item => !form.value.space_kind || (item.space_kind || 'guest_room') === form.value.space_kind)
    .slice()
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' }))
  const map = new Map(list.map(item => [item.id, item]))
  if (form.value.type_id && !map.has(form.value.type_id)) {
    const current = roomTypes.value.find(item => item.id === form.value.type_id)
    if (current) map.set(current.id, current)
  }
  return [...map.values()]
})

const selectedType = computed(() => roomTypes.value.find(item => item.id === form.value.type_id) ?? null)

const typeDefaultPrice = computed(() =>
  formatMoney(Number(selectedType.value?.base_price_cents ?? selectedType.value?.rate ?? 0), String(selectedType.value?.currency ?? 'USD')),
)

const categories = computed(() => {
  const counts = new Map<string, number>()
  for (const room of rooms.value) {
    const key = String(room.type_id ?? '')
    counts.set(key, (counts.get(key) ?? 0) + 1)
  }
  const list = roomTypes.value
    .slice()
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' }))
    .map(type => ({
      id: String(type.id),
      name: String(type.name ?? type.id),
      space_kind: (type.space_kind as SpaceKind) || 'guest_room',
      count: counts.get(String(type.id)) ?? 0,
      photo: Array.isArray(type.photo_urls) && type.photo_urls[0] ? String(type.photo_urls[0]) : '',
    }))
  const orphanCount = rooms.value.filter(room => !roomTypes.value.some(type => type.id === room.type_id)).length
  if (orphanCount) {
    list.push({
      id: '__other__',
      name: t('hotel.rooms.otherCategory'),
      space_kind: 'guest_room',
      count: orphanCount,
      photo: '',
    })
  }
  return list
})

const filteredRooms = computed(() => {
  const list = rooms.value.filter((room) => {
    if (!selectedCategoryId.value) return true
    if (selectedCategoryId.value === '__other__') {
      return !roomTypes.value.some(type => type.id === room.type_id)
    }
    return room.type_id === selectedCategoryId.value
  })
  return list.slice().sort((a, b) => {
    const building = String(a.building_name ?? '').localeCompare(String(b.building_name ?? ''), undefined, { sensitivity: 'base' })
    if (building !== 0) return building
    const floor = Number(a.floor_number ?? 0) - Number(b.floor_number ?? 0)
    if (floor !== 0) return floor
    return String(a.number ?? '').localeCompare(String(b.number ?? ''), undefined, { numeric: true, sensitivity: 'base' })
  })
})

const selectedCategory = computed(() =>
  categories.value.find(item => item.id === selectedCategoryId.value) ?? null,
)

const galleryItems = computed(() =>
  store.products
    .flatMap(product => (product.images ?? []).map(image => ({
      url: image.cdn_url,
      label: product.name,
    })))
    .filter(item => Boolean(item.url)),
)

onMounted(async () => {
  await Promise.all([load(), loadGallery()])
})

watch(() => form.value.building_id, () => {
  if (form.value.wing_id && !wingOptions.value.some(item => item.id === form.value.wing_id)) {
    form.value.wing_id = ''
  }
  if (form.value.floor_id && !floorOptions.value.some(item => item.id === form.value.floor_id)) {
    form.value.floor_id = ''
  }
})

watch(() => form.value.wing_id, () => {
  if (form.value.floor_id && !floorOptions.value.some(item => item.id === form.value.floor_id)) {
    form.value.floor_id = ''
  }
})

watch(() => form.value.space_kind, () => {
  if (form.value.type_id && !typeOptions.value.some(item => item.id === form.value.type_id)) {
    form.value.type_id = typeOptions.value[0]?.id ?? ''
  }
})

function sortByOrderThenName(a: Doc, b: Doc) {
  const order = Number(a.display_order ?? 0) - Number(b.display_order ?? 0)
  if (order !== 0) return order
  return String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })
}

function blankForm() {
  return {
    building_id: '',
    wing_id: '',
    floor_id: '',
    mode: 'single' as Mode,
    space_kind: 'guest_room' as SpaceKind,
    type_id: '',
    number: '',
    number_from: '',
    number_to: '',
    display_name: '',
    housekeeping_status: 'clean',
    is_active: true,
    price_override: '',
    max_adults_override: '',
    max_children_override: '',
    photo_urls: [] as string[],
    notes: '',
  }
}

function resetForm() {
  editingId.value = null
  form.value = {
    ...blankForm(),
    building_id: activeBuildings.value[0]?.id ?? '',
    type_id: roomTypes.value.find(item => item.is_active !== false)?.id ?? '',
  }
  error.value = ''
}

function openCreate() {
  resetForm()
  formOpen.value = true
}

function closeForm() {
  galleryOpen.value = false
  formOpen.value = false
  resetForm()
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_ROOM_KINDS]))).data.docs
    if (!form.value.building_id) {
      form.value.building_id = activeBuildings.value[0]?.id ?? ''
    }
    if (!form.value.type_id) {
      form.value.type_id = typeOptions.value[0]?.id ?? ''
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function loadGallery() {
  try {
    await store.loadCompanies()
    const company = store.companies[0]
    if (!company) return
    const catalogs = await store.loadCatalogs(company.id)
    const catalog = catalogs.find(c => c.is_default) ?? catalogs[0]
    if (catalog) await store.loadProducts(catalog.id)
  } catch {
    // optional
  }
}

function openEdit(row: Doc) {
  editingId.value = row.id
  form.value = {
    building_id: row.building_id ?? '',
    wing_id: row.wing_id ?? '',
    floor_id: row.floor_id ?? '',
    mode: 'single',
    space_kind: (row.space_kind as SpaceKind) || 'guest_room',
    type_id: row.type_id ?? '',
    number: String(row.number ?? ''),
    number_from: '',
    number_to: '',
    display_name: String(row.display_name ?? ''),
    housekeeping_status: String(row.housekeeping_status ?? 'clean'),
    is_active: row.is_active !== false,
    price_override: row.price_override_cents != null ? String(Number(row.price_override_cents) / 100) : '',
    max_adults_override: row.max_adults_override != null ? String(row.max_adults_override) : '',
    max_children_override: row.max_children_override != null ? String(row.max_children_override) : '',
    photo_urls: Array.isArray(row.photo_urls) ? [...row.photo_urls] : [],
    notes: String(row.notes ?? ''),
  }
  error.value = ''
  formOpen.value = true
}

async function save() {
  if (!form.value.building_id || !form.value.floor_id || !form.value.type_id) return
  if (form.value.mode === 'single' && !form.value.number.trim() && !editingId.value) return
  saving.value = true
  error.value = ''
  try {
    const payload: Record<string, unknown> = {
      action: 'upsert_room',
      id: editingId.value ?? undefined,
      mode: editingId.value ? 'single' : form.value.mode,
      building_id: form.value.building_id,
      wing_id: form.value.wing_id || undefined,
      floor_id: form.value.floor_id,
      space_kind: form.value.space_kind,
      type_id: form.value.type_id,
      number: form.value.number.trim(),
      number_from: form.value.number_from.trim(),
      number_to: form.value.number_to.trim(),
      display_name: form.value.display_name.trim(),
      housekeeping_status: form.value.housekeeping_status,
      is_active: form.value.is_active,
      price_override_cents: form.value.price_override === '' ? null : parseMoneyInput(form.value.price_override),
      max_adults_override: form.value.max_adults_override === '' ? null : Number(form.value.max_adults_override),
      max_children_override: form.value.max_children_override === '' ? null : Number(form.value.max_children_override),
      photo_urls: form.value.photo_urls,
      notes: form.value.notes.trim(),
    }
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', payload)).data.docs
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
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'delete_room',
      id: row.id,
    })).data.docs
    if (editingId.value === row.id) closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function setHousekeeping(row: Doc, status: HkStatus) {
  if (String(row.housekeeping_status ?? 'clean') === status) return
  hkSavingId.value = row.id
  error.value = ''
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'set_room_housekeeping',
      id: row.id,
      housekeeping_status: status,
    })).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    hkSavingId.value = null
  }
}

function togglePhoto(url: string) {
  const idx = form.value.photo_urls.indexOf(url)
  if (idx >= 0) form.value.photo_urls.splice(idx, 1)
  else form.value.photo_urls.push(url)
}

function floorLabel(item: Doc) {
  return item.name || `${t('hotel.rooms.floor')} ${item.floor_number ?? ''}`.trim()
}

function hkLabel(status?: string) {
  const key = status && housekeepingStatuses.includes(status as HkStatus) ? status : 'clean'
  return t(`hotel.rooms.hk.${key}`)
}

function hkTone(status?: string) {
  const key = (status && housekeepingStatuses.includes(status as HkStatus) ? status : 'clean') as HkStatus
  return hkMeta[key].tone
}

function hkIcon(status?: string) {
  const key = (status && housekeepingStatuses.includes(status as HkStatus) ? status : 'clean') as HkStatus
  return hkMeta[key].icon
}

function spaceIcon(kind?: string) {
  if (kind === 'conference') return 'organization'
  if (kind === 'reception') return 'sparkles'
  return 'bed'
}

function roomTypeOf(row: Doc) {
  return roomTypes.value.find(type => type.id === row.type_id) ?? null
}

function roomPhotos(row: Doc) {
  const own = Array.isArray(row.photo_urls) ? row.photo_urls.filter(Boolean) : []
  if (own.length) return own.map(String)
  const type = roomTypeOf(row)
  const fromType = Array.isArray(type?.photo_urls) ? type.photo_urls.filter(Boolean) : []
  return fromType.map(String)
}

function roomTitle(row: Doc) {
  const typeName = row.type_name || roomTypeOf(row)?.name || t('hotel.rooms.room')
  return `${typeName} ${t('hotel.rooms.room')}#${row.number ?? ''}`
}

function spaceLabel(kind?: string) {
  if (kind === 'conference') return t('hotel.roomTypes.space.conference')
  if (kind === 'reception') return t('hotel.roomTypes.space.reception')
  return t('hotel.roomTypes.space.guest')
}

function bedLabel(row: Doc) {
  const type = roomTypeOf(row)
  const bed = String(type?.bed_type ?? 'Queen')
  const count = Number(type?.bed_count ?? 1)
  return `${bed} × ${count}`
}

function guestsLabel(row: Doc) {
  const type = roomTypeOf(row)
  const adults = Number(row.max_adults_override ?? type?.max_adults ?? 2)
  return t('hotel.rooms.guests', { count: adults })
}

function priceLabel(row: Doc) {
  const type = roomTypeOf(row)
  const cents = row.price_override_cents != null
    ? Number(row.price_override_cents)
    : Number(type?.base_price_cents ?? type?.rate ?? 0)
  const currency = String(type?.currency ?? 'USD')
  return `${formatMoney(cents, currency)}/${t('hotel.rooms.perNight')}`
}

function descriptionOf(row: Doc) {
  const type = roomTypeOf(row)
  return String(type?.description ?? '').trim()
}

function selectCategory(id: string | null) {
  selectedCategoryId.value = id
}
</script>

<template>
  <HotelChrome scroll-body>
    <div class="rooms">
      <div class="rooms__toolbar">
        <p>{{ t('hotel.rooms.locationHint') }}</p>
        <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
          {{ t('hotel.rooms.createTitle') }}
        </button>
      </div>

      <p v-if="error && !formOpen" class="rooms__error">{{ error }}</p>

      <div class="rooms__list">
        <div v-if="loading" class="rooms__muted">{{ t('common.loading') }}</div>
        <template v-else>
          <div class="rooms__browse">
            <div class="rooms__browse-head">
              <div>
                <h3>
                  <AppIcon :name="selectedCategory ? 'bed' : 'layers'" :size="15" />
                  {{ selectedCategory ? selectedCategory.name : t('hotel.rooms.categoriesTitle') }}
                </h3>
                <p>{{ selectedCategory ? t('hotel.rooms.categoryRooms', { count: filteredRooms.length }) : t('hotel.rooms.categoriesHint') }}</p>
              </div>
              <button
                v-if="selectedCategoryId"
                type="button"
                class="btn-secondary"
                @click="selectCategory(null)"
              >
                {{ t('hotel.rooms.backToCategories') }}
              </button>
            </div>

            <div v-if="!selectedCategoryId" class="rooms__categories">
              <button
                v-for="cat in categories"
                :key="cat.id"
                type="button"
                class="rooms__category"
                @click="selectCategory(cat.id)"
              >
                <span class="rooms__category-media">
                  <img v-if="cat.photo" :src="cat.photo" :alt="cat.name" />
                  <span v-else class="rooms__category-fallback">
                    <AppIcon :name="spaceIcon(cat.space_kind)" :size="18" />
                  </span>
                </span>
                <span class="rooms__category-meta">
                  <strong>{{ cat.name }}</strong>
                  <small>
                    <AppIcon :name="spaceIcon(cat.space_kind)" :size="11" />
                    {{ spaceLabel(cat.space_kind) }} · {{ t('hotel.rooms.categoryRooms', { count: cat.count }) }}
                  </small>
                </span>
                <AppIcon name="chevron-right" :size="14" class="rooms__category-chevron" />
              </button>
              <p v-if="!categories.length" class="rooms__empty">{{ t('hotel.rooms.empty') }}</p>
            </div>

            <div v-else class="rooms__cards">
              <article v-for="row in filteredRooms" :key="row.id" class="room-card">
                <div class="room-card__media">
                  <img v-if="roomPhotos(row)[0]" :src="roomPhotos(row)[0]" :alt="roomTitle(row)" />
                  <div v-else class="room-card__nophoto">
                    <AppIcon name="sparkles" :size="22" />
                    <p>{{ t('hotel.rooms.photoEmptyTitle') }}</p>
                    <small>{{ t('hotel.rooms.photoEmptyHint') }}</small>
                  </div>
                  <span class="room-card__number">
                    <AppIcon name="tag" :size="11" />
                    {{ row.number }}
                  </span>
                  <span
                    class="room-card__hk-pill"
                    :class="`room-card__hk-pill--${hkTone(row.housekeeping_status)}`"
                  >
                    <AppIcon :name="hkIcon(row.housekeeping_status)" :size="11" />
                    {{ hkLabel(row.housekeeping_status) }}
                  </span>
                </div>

                <div class="room-card__body">
                  <div class="room-card__title-row">
                    <div>
                      <h4>{{ roomTitle(row) }}</h4>
                      <p>
                        <AppIcon :name="spaceIcon(row.space_kind || roomTypeOf(row)?.space_kind)" :size="12" />
                        {{ spaceLabel(row.space_kind || roomTypeOf(row)?.space_kind) }}
                      </p>
                    </div>
                    <span v-if="row.is_active === false" class="room-card__badge">
                      <AppIcon name="pause" :size="11" />
                      {{ t('hotel.rooms.unavailable') }}
                    </span>
                  </div>

                  <div class="room-card__hk">
                    <p>
                      <AppIcon name="broom" :size="13" />
                      {{ t('hotel.rooms.changeHk') }}
                    </p>
                    <div class="room-card__hk-options">
                      <button
                        v-for="status in housekeepingStatuses"
                        :key="status"
                        type="button"
                        class="room-card__hk-btn"
                        :class="[
                          `room-card__hk-btn--${hkTone(status)}`,
                          { 'room-card__hk-btn--on': (row.housekeeping_status || 'clean') === status },
                        ]"
                        :disabled="hkSavingId === row.id"
                        @click="setHousekeeping(row, status)"
                      >
                        <AppIcon :name="hkIcon(status)" :size="12" />
                        {{ hkLabel(status) }}
                      </button>
                    </div>
                  </div>

                  <div class="room-card__facts">
                    <span><AppIcon name="bed" :size="13" /> {{ bedLabel(row) }}</span>
                    <span><AppIcon name="account" :size="13" /> {{ guestsLabel(row) }}</span>
                    <span><AppIcon name="coins" :size="13" /> {{ priceLabel(row) }}</span>
                  </div>

                  <div class="room-card__desc">
                    <p class="room-card__desc-label">
                      <AppIcon name="note" :size="11" />
                      {{ t('hotel.rooms.description') }}
                    </p>
                    <p v-if="descriptionOf(row)">{{ descriptionOf(row) }}</p>
                    <p v-else class="room-card__desc-empty">{{ t('hotel.rooms.noDescription') }}</p>
                  </div>

                  <div class="room-card__actions">
                    <button type="button" class="btn-secondary" @click="openEdit(row)">
                      <AppIcon name="adjust" :size="13" />
                      {{ t('common.edit') }}
                    </button>
                    <button type="button" class="btn-danger" @click="remove(row)">
                      <AppIcon name="trash" :size="13" />
                      {{ t('common.delete') }}
                    </button>
                    <RouterLink
                      v-if="row.type_id"
                      class="room-card__type-link"
                      :to="`/admin/hotel/room-config/room-types`"
                    >
                      <AppIcon name="catalog" :size="12" />
                      {{ t('hotel.rooms.viewType') }}
                    </RouterLink>
                  </div>
                </div>
              </article>
              <p v-if="!filteredRooms.length" class="rooms__empty">{{ t('hotel.rooms.emptyCategory') }}</p>
            </div>
          </div>
        </template>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.rooms.editTitle') : t('hotel.rooms.createTitle')"
      icon="key"
      size="xl"
      @close="closeForm"
    >
      <form class="rooms__form" @submit.prevent="save">
        <p class="rooms__intro">{{ t('hotel.rooms.locationHint') }}</p>
        <p v-if="error" class="rooms__error">{{ error }}</p>

        <section class="rooms__block">
          <h3><AppIcon name="building" :size="15" /> {{ t('hotel.rooms.locationTitle') }}</h3>
          <div class="rooms__grid">
            <div>
              <FieldLabel icon="building">{{ t('hotel.rooms.building') }} *</FieldLabel>
              <select v-model="form.building_id" class="field" required>
                <option disabled value="">{{ t('hotel.rooms.chooseBuilding') }}</option>
                <option v-for="item in buildingOptions" :key="item.id" :value="item.id">{{ item.name }}</option>
              </select>
            </div>
            <div>
              <FieldLabel icon="layers">{{ t('hotel.rooms.wing') }}</FieldLabel>
              <select v-model="form.wing_id" class="field">
                <option value="">{{ t('hotel.rooms.wholeBuilding') }}</option>
                <option v-for="item in wingOptions" :key="item.id" :value="item.id">{{ item.name }}</option>
              </select>
            </div>
            <div class="rooms__span">
              <FieldLabel icon="floors">{{ t('hotel.rooms.floor') }} *</FieldLabel>
              <select v-model="form.floor_id" class="field" required>
                <option disabled value="">{{ t('hotel.rooms.chooseFloor') }}</option>
                <option v-for="item in floorOptions" :key="item.id" :value="item.id">{{ floorLabel(item) }}</option>
              </select>
            </div>
          </div>
        </section>

        <section class="rooms__block">
          <h3><AppIcon name="bed" :size="15" /> {{ t('hotel.rooms.identityTitle') }}</h3>
          <div v-if="!editingId" class="rooms__modes">
            <label class="rooms__mode" :class="{ 'rooms__mode--on': form.mode === 'single' }">
              <input v-model="form.mode" type="radio" value="single" />
              <AppIcon name="key" :size="13" />
              <span>{{ t('hotel.rooms.modeSingle') }}</span>
            </label>
            <label class="rooms__mode" :class="{ 'rooms__mode--on': form.mode === 'range' }">
              <input v-model="form.mode" type="radio" value="range" />
              <AppIcon name="layers" :size="13" />
              <span>{{ t('hotel.rooms.modeRange') }}</span>
            </label>
          </div>

          <p class="rooms__label">{{ t('hotel.rooms.spaceTitle') }}</p>
          <div class="rooms__spaces">
            <label
              v-for="kind in spaceKinds"
              :key="kind.id"
              class="rooms__space"
              :class="{ 'rooms__space--on': form.space_kind === kind.id }"
            >
              <input v-model="form.space_kind" type="radio" :value="kind.id" />
              <span class="rooms__space-icon"><AppIcon :name="kind.icon" :size="16" /></span>
              <strong>{{ t(kind.titleKey) }}</strong>
              <span>{{ t(kind.hintKey) }}</span>
            </label>
          </div>

          <div class="rooms__grid">
            <div>
              <FieldLabel icon="catalog">{{ t('hotel.rooms.roomType') }} *</FieldLabel>
              <select v-model="form.type_id" class="field" required>
                <option disabled value="">{{ t('hotel.rooms.chooseType') }}</option>
                <option v-for="item in typeOptions" :key="item.id" :value="item.id">{{ item.name }}</option>
              </select>
            </div>

            <template v-if="form.mode === 'single' || editingId">
              <div>
                <FieldLabel icon="tag">{{ t('hotel.rooms.number') }} *</FieldLabel>
                <input v-model="form.number" class="field" required :placeholder="t('hotel.rooms.numberPh')" />
              </div>
            </template>
            <template v-else>
              <div>
                <FieldLabel icon="tag">{{ t('hotel.rooms.numberFrom') }} *</FieldLabel>
                <input v-model="form.number_from" class="field" required inputmode="numeric" />
              </div>
              <div>
                <FieldLabel icon="tag">{{ t('hotel.rooms.numberTo') }} *</FieldLabel>
                <input v-model="form.number_to" class="field" required inputmode="numeric" />
              </div>
            </template>

            <div class="rooms__span">
              <FieldLabel icon="sparkles">{{ t('hotel.rooms.displayName') }}</FieldLabel>
              <input v-model="form.display_name" class="field" :placeholder="t('hotel.rooms.displayNamePh')" />
              <p class="rooms__hint">{{ t('hotel.rooms.displayNameHint') }}</p>
            </div>
          </div>
        </section>

        <section class="rooms__block">
          <h3><AppIcon name="broom" :size="15" /> {{ t('hotel.rooms.hkTitle') }}</h3>
          <p class="rooms__hint rooms__hint--block">{{ t('hotel.rooms.hkHint') }}</p>
          <div class="rooms__grid">
            <div>
              <FieldLabel icon="broom">{{ t('hotel.rooms.hkInitial') }}</FieldLabel>
              <select v-model="form.housekeeping_status" class="field">
                <option v-for="status in housekeepingStatuses" :key="status" :value="status">
                  {{ hkLabel(status) }}
                </option>
              </select>
              <p class="rooms__hint">{{ t('hotel.rooms.hkInitialHint') }}</p>
            </div>
          </div>
          <label class="rooms-switch">
            <input v-model="form.is_active" type="checkbox" />
            <span class="rooms-switch__track" aria-hidden="true" />
            <span>{{ t('hotel.rooms.active') }}</span>
          </label>
        </section>

        <section class="rooms__block">
          <h3><AppIcon name="coins" :size="15" /> {{ t('hotel.rooms.overridesTitle') }}</h3>
          <div class="rooms__grid">
            <div>
              <FieldLabel icon="coins">{{ t('hotel.rooms.priceOverride') }}</FieldLabel>
              <div class="rooms__money">
                <span>$</span>
                <input v-model="form.price_override" class="field" inputmode="decimal" :placeholder="t('hotel.rooms.priceOverridePh')" />
              </div>
              <p class="rooms__hint">{{ t('hotel.rooms.priceOverrideHint', { price: typeDefaultPrice }) }}</p>
            </div>
            <div>
              <FieldLabel icon="account">{{ t('hotel.rooms.maxAdults') }}</FieldLabel>
              <input v-model="form.max_adults_override" class="field" type="number" min="1" :placeholder="t('hotel.rooms.overrideEmpty')" />
            </div>
            <div>
              <FieldLabel icon="account">{{ t('hotel.rooms.maxChildren') }}</FieldLabel>
              <input v-model="form.max_children_override" class="field" type="number" min="0" :placeholder="t('hotel.rooms.overrideEmpty')" />
            </div>
          </div>
        </section>

        <section class="rooms__block">
          <div class="rooms__section-head">
            <div>
              <h3>
                <AppIcon name="sparkles" :size="15" />
                {{ t('hotel.rooms.photos') }}
              </h3>
              <p>{{ t('hotel.rooms.photosHint') }}</p>
            </div>
            <button type="button" class="btn-secondary" @click="galleryOpen = true">
              {{ t('hotel.rooms.addFromGallery') }}
            </button>
          </div>
          <div v-if="form.photo_urls.length" class="rooms__photos">
            <figure v-for="(url, index) in form.photo_urls" :key="url" class="rooms__photo">
              <img :src="url" alt="" />
              <span v-if="index === 0" class="rooms__cover">{{ t('hotel.roomTypes.cover') }}</span>
              <button type="button" @click="togglePhoto(url)">×</button>
            </figure>
          </div>
          <div v-else class="rooms__empty-photos">
            <p>{{ t('hotel.rooms.noPhotos') }}</p>
            <small>{{ t('hotel.rooms.noPhotosHint') }}</small>
          </div>
        </section>

        <section class="rooms__block">
          <h3><AppIcon name="note" :size="15" /> {{ t('hotel.rooms.notes') }}</h3>
          <textarea v-model="form.notes" class="field" rows="3" :placeholder="t('hotel.rooms.notesPh')" />
        </section>

        <div class="rooms__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="galleryOpen" :title="t('hotel.rooms.addFromGallery')" size="xl" @close="galleryOpen = false">
      <div v-if="galleryItems.length" class="rooms__gallery">
        <button
          v-for="item in galleryItems"
          :key="item.url"
          type="button"
          class="rooms__gallery-item"
          :class="{ 'rooms__gallery-item--on': form.photo_urls.includes(item.url) }"
          @click="togglePhoto(item.url)"
        >
          <img :src="item.url" :alt="item.label" />
          <span>{{ item.label }}</span>
        </button>
      </div>
      <p v-else class="rooms__muted">{{ t('hotel.rooms.noPhotosHint') }}</p>
      <div class="rooms__actions">
        <button type="button" class="btn-primary" @click="galleryOpen = false">{{ t('common.ok') }}</button>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.rooms {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 1rem;
  width: 100%;
}

.rooms__toolbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.rooms__toolbar p,
.rooms__intro {
  margin: 0;
  max-width: 40rem;
  color: #66727c;
  font-size: 0.85rem;
  line-height: 1.45;
}

.rooms__form {
  display: flex;
  flex-direction: column;
}

.rooms__list {
  display: flex;
  flex-direction: column;
  padding: 0;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  background: #fff;
}

.rooms__browse {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  padding: 1.15rem 1.2rem 1.3rem;
}

.rooms__browse-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  flex-shrink: 0;
}

.rooms__browse-head h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 1rem;
  color: #1c2830;
}

.rooms__browse-head h3 :deep(svg) {
  color: var(--color-brand-600, #4a6d86);
}

.rooms__browse-head p {
  margin: 0.25rem 0 0;
  font-size: 0.8rem;
  color: #7b8d9a;
}

.rooms__categories,
.rooms__cards {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.rooms__category {
  display: grid;
  grid-template-columns: 3.4rem 1fr auto;
  gap: 0.75rem;
  align-items: center;
  padding: 0.55rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.8rem;
  background: #fff;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.rooms__category:hover {
  border-color: var(--color-brand-400, #7d9aaf);
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.05);
}

.rooms__category-media {
  width: 3.4rem;
  height: 3.4rem;
  border-radius: 0.65rem;
  overflow: hidden;
  background: linear-gradient(145deg, #eef4f8, #dce7ef);
  display: grid;
  place-items: center;
  color: #3d5c73;
}

.rooms__category-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.rooms__category-fallback {
  display: grid;
  place-items: center;
}

.rooms__category-meta {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  min-width: 0;
}

.rooms__category-meta strong {
  font-size: 0.9rem;
  color: #1c2830;
}

.rooms__category-meta small {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  color: #7b8d9a;
  font-size: 0.75rem;
}

.rooms__category-chevron {
  color: #94a3b8;
}

.room-card {
  display: grid;
  grid-template-columns: minmax(8rem, 11rem) minmax(0, 1fr);
  gap: 0.85rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  overflow: hidden;
  background: #fff;
  flex-shrink: 0;
}

.room-card__media {
  position: relative;
  min-height: 10rem;
  background: #e8eef3;
}

.room-card__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.room-card__nophoto {
  height: 100%;
  min-height: 10rem;
  padding: 0.85rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-start;
  gap: 0.35rem;
  color: #66727c;
}

.room-card__nophoto :deep(svg) {
  color: #7d9aaf;
}

.room-card__nophoto p {
  margin: 0;
  font-size: 0.8rem;
  font-weight: 650;
  color: #1c2830;
}

.room-card__nophoto small {
  font-size: 0.72rem;
  line-height: 1.35;
}

.room-card__number,
.room-card__hk-pill {
  position: absolute;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.18rem 0.45rem;
  border-radius: 999px;
  font-size: 0.7rem;
  font-weight: 700;
}

.room-card__number {
  right: 0.45rem;
  bottom: 0.45rem;
  background: rgba(255, 255, 255, 0.94);
  color: #1c2830;
}

.room-card__hk-pill {
  left: 0.45rem;
  top: 0.45rem;
  backdrop-filter: blur(4px);
}

.room-card__hk-pill--clean { background: #ecfdf5; color: #047857; }
.room-card__hk-pill--dirty { background: #fef2f2; color: #b91c1c; }
.room-card__hk-pill--cleaning { background: #eff6ff; color: #1d4ed8; }
.room-card__hk-pill--inspected { background: #f0fdfa; color: #0f766e; }
.room-card__hk-pill--maintenance { background: #fffbeb; color: #b45309; }
.room-card__hk-pill--oos { background: #f1f5f9; color: #475569; }

.room-card__body {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: 0.85rem 0.85rem 0.9rem 0;
}

.room-card__title-row {
  display: flex;
  justify-content: space-between;
  gap: 0.6rem;
  align-items: flex-start;
}

.room-card__title-row h4 {
  margin: 0;
  font-size: 0.95rem;
  color: #1c2830;
}

.room-card__title-row p {
  margin: 0.2rem 0 0;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.78rem;
  color: #7b8d9a;
}

.room-card__badge {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.15rem 0.45rem;
  border-radius: 999px;
  background: #fee2e2;
  color: #b91c1c;
  font-size: 0.68rem;
  font-weight: 700;
}

.room-card__hk p {
  margin: 0 0 0.4rem;
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.75rem;
  font-weight: 650;
  color: #475569;
}

.room-card__hk-options {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.room-card__hk-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.28rem;
  border: 1px solid transparent;
  border-radius: 999px;
  background: #f8fafc;
  padding: 0.28rem 0.55rem;
  font-size: 0.7rem;
  cursor: pointer;
  color: #334155;
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}

.room-card__hk-btn--clean { background: #ecfdf5; color: #047857; border-color: #a7f3d0; }
.room-card__hk-btn--dirty { background: #fef2f2; color: #b91c1c; border-color: #fecaca; }
.room-card__hk-btn--cleaning { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.room-card__hk-btn--inspected { background: #f0fdfa; color: #0f766e; border-color: #99f6e4; }
.room-card__hk-btn--maintenance { background: #fffbeb; color: #b45309; border-color: #fde68a; }
.room-card__hk-btn--oos { background: #f1f5f9; color: #475569; border-color: #cbd5e1; }

.room-card__hk-btn--on {
  box-shadow: 0 0 0 2px color-mix(in srgb, currentColor 28%, transparent);
  font-weight: 700;
  transform: translateY(-1px);
}

.room-card__hk-btn:disabled {
  opacity: 0.6;
  cursor: wait;
}

.room-card__facts {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem 0.85rem;
  font-size: 0.78rem;
  color: #475569;
}

.room-card__facts span {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

.room-card__facts :deep(svg) {
  color: var(--color-brand-600, #4a6d86);
}

.room-card__desc-label {
  margin: 0 0 0.2rem;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #94a3b8;
}

.room-card__desc p {
  margin: 0;
  font-size: 0.82rem;
  color: #334155;
  line-height: 1.4;
}

.room-card__desc-empty {
  color: #94a3b8 !important;
}

.room-card__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  align-items: center;
}

.room-card__actions .btn-secondary,
.room-card__actions .btn-danger {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

.room-card__type-link {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-brand-700, #3d5c73);
  text-decoration: none;
}

.room-card__type-link:hover {
  text-decoration: underline;
}

.btn-danger {
  border-radius: 0.5rem;
  padding: 0.45rem 0.85rem;
  font-weight: 600;
  font-size: 0.8125rem;
  cursor: pointer;
  border: 1px solid #fecaca;
  background: #fff;
  color: #b91c1c;
}

@media (max-width: 720px) {
  .room-card {
    grid-template-columns: 1fr;
  }
  .room-card__body {
    padding: 0 0.85rem 0.9rem;
  }
}

.rooms__block h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.92rem;
  color: #1c2830;
}

.rooms__block h3 :deep(svg) {
  color: var(--color-brand-600, #4a6d86);
}

.rooms__hk-picks {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.35rem;
}

.rooms__hk-pick {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  border: 1px solid transparent;
  border-radius: 999px;
  padding: 0.35rem 0.6rem;
  font-size: 0.75rem;
  cursor: pointer;
  background: #f8fafc;
}

.rooms__hk-pick--clean { background: #ecfdf5; color: #047857; border-color: #a7f3d0; }
.rooms__hk-pick--dirty { background: #fef2f2; color: #b91c1c; border-color: #fecaca; }
.rooms__hk-pick--cleaning { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.rooms__hk-pick--inspected { background: #f0fdfa; color: #0f766e; border-color: #99f6e4; }
.rooms__hk-pick--maintenance { background: #fffbeb; color: #b45309; border-color: #fde68a; }
.rooms__hk-pick--oos { background: #f1f5f9; color: #475569; border-color: #cbd5e1; }

.rooms__hk-pick--on {
  box-shadow: 0 0 0 2px color-mix(in srgb, currentColor 25%, transparent);
  font-weight: 700;
}

.rooms__space-icon {
  display: inline-grid;
  place-items: center;
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 0.4rem;
  background: #eef4f8;
  color: #3d5c73;
  margin-bottom: 0.15rem;
}
.rooms__error { margin: 0; padding: 0.7rem 0.85rem; border-radius: 0.7rem; background: #fef2f2; color: #b91c1c; font-size: 0.85rem; }
.rooms__block { margin-top: 1.2rem; display: flex; flex-direction: column; gap: 0.7rem; }
.rooms__block:first-of-type { margin-top: 0.85rem; }
.rooms__label { margin: 0; font-size: 0.78rem; font-weight: 650; color: #64748b; text-transform: uppercase; letter-spacing: 0.03em; }
.rooms__grid { display: grid; gap: 0.85rem 1rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rooms__grid { grid-template-columns: 1fr 1fr; }
  .rooms__span { grid-column: 1 / -1; }
}
.field {
  width: 100%;
  min-height: 2.45rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.55rem;
  padding: 0.45rem 0.7rem;
  background: #fff;
}
textarea.field { min-height: 5rem; resize: vertical; }
.rooms__hint { margin: 0.3rem 0 0; font-size: 0.72rem; color: #94a3b8; }
.rooms__modes { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.rooms__mode {
  display: inline-flex; align-items: center; gap: 0.35rem;
  padding: 0.4rem 0.7rem; border: 1px solid #d7e2ea; border-radius: 999px;
  font-size: 0.8rem; cursor: pointer; background: #fff;
}
.rooms__mode input { accent-color: var(--color-brand-600); }
.rooms__mode--on { border-color: var(--color-brand-500); background: #f3f6f8; }
.rooms__spaces { display: grid; gap: 0.55rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rooms__spaces { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.rooms__space {
  display: flex; flex-direction: column; gap: 0.2rem;
  padding: 0.7rem; border: 1px solid #d7e2ea; border-radius: 0.7rem; cursor: pointer;
}
.rooms__space input { position: absolute; opacity: 0; pointer-events: none; }
.rooms__space strong { font-size: 0.82rem; color: #1c2830; }
.rooms__space span { font-size: 0.72rem; color: #7b8d9a; line-height: 1.35; }
.rooms__space--on { border-color: var(--color-brand-500); background: #f3f6f8; }
.rooms__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.rooms__money span { font-weight: 700; color: #3d5c73; }
.rooms-switch {
  display: inline-flex; align-items: center; gap: 0.55rem;
  margin-top: 0.35rem; font-size: 0.875rem; color: #1c2830; cursor: pointer;
}
.rooms-switch input { position: absolute; opacity: 0; pointer-events: none; }
.rooms-switch__track {
  width: 2.2rem; height: 1.2rem; border-radius: 999px; background: #d7e2ea; position: relative;
}
.rooms-switch__track::after {
  content: ""; position: absolute; top: 0.15rem; left: 0.15rem;
  width: 0.9rem; height: 0.9rem; border-radius: 50%; background: #fff; transition: transform 0.15s ease;
}
.rooms-switch input:checked + .rooms-switch__track { background: var(--color-brand-600, #4a6d86); }
.rooms-switch input:checked + .rooms-switch__track::after { transform: translateX(1rem); }
.rooms__section-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }
.rooms__section-head p { margin: 0.25rem 0 0; color: #7b8d9a; font-size: 0.8rem; }
.rooms__photos { display: grid; grid-template-columns: repeat(auto-fill, minmax(6.5rem, 1fr)); gap: 0.55rem; }
.rooms__photo { position: relative; margin: 0; aspect-ratio: 1; border-radius: 0.65rem; overflow: hidden; border: 1px solid #e4e8ec; }
.rooms__photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
.rooms__photo button {
  position: absolute; top: 0.3rem; right: 0.3rem; width: 1.4rem; height: 1.4rem;
  border: 0; border-radius: 999px; background: rgba(15,23,42,0.7); color: #fff; cursor: pointer;
}
.rooms__cover {
  position: absolute; left: 0.3rem; bottom: 0.3rem; padding: 0.1rem 0.35rem;
  border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 0.65rem; font-weight: 700;
}
.rooms__empty-photos { padding: 0.9rem; border: 1px dashed #d7e2ea; border-radius: 0.75rem; background: #f8fafc; }
.rooms__empty-photos p { margin: 0; font-weight: 600; color: #1c2830; }
.rooms__empty-photos small { color: #7b8d9a; }
.rooms__actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.1rem; }
.rooms__row-actions { text-align: right; white-space: nowrap; }
.rooms__row-actions button + button { margin-left: 0.7rem; }
.rooms__muted, .rooms__empty { margin: 0; padding: 1.2rem; text-align: center; color: #7b8d9a; font-size: 0.875rem; }
.rooms__gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr)); gap: 0.65rem; max-height: 24rem; overflow: auto; }
.rooms__gallery-item {
  display: flex; flex-direction: column; gap: 0.35rem; border: 1px solid #e2e8f0;
  border-radius: 0.65rem; overflow: hidden; background: #fff; padding: 0; text-align: left; cursor: pointer;
}
.rooms__gallery-item img { aspect-ratio: 1; width: 100%; object-fit: cover; }
.rooms__gallery-item span { padding: 0 0.5rem 0.5rem; font-size: 0.75rem; color: #334155; }
.rooms__gallery-item--on { border-color: var(--color-brand-500); box-shadow: 0 0 0 1px color-mix(in srgb, var(--color-brand-500) 40%, transparent); }
.btn-primary, .btn-secondary {
  border-radius: 0.5rem; padding: 0.45rem 0.85rem; font-weight: 600; font-size: 0.8125rem; cursor: pointer;
}
.btn-primary { border: 0; color: #fff; background: var(--color-brand-600, #4a6d86); }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { border: 1px solid #d7e2ea; background: #fff; color: #334155; }
.font-semibold { font-weight: 600; }
.text-brand-600 { color: var(--color-brand-600); }
.text-red-600 { color: #dc2626; }
</style>
