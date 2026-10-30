<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_ROOM_KINDS } from '../../../api/hospitality'
import { useConfirm } from '../../../composables/useConfirm'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { getAppCurrency } from '../../../utils/currency'
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
const selectedCategoryId = ref('')
const search = ref('')
const hkFilter = ref<HkStatus | 'all'>('all')
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
const amenities = computed(() =>
  docs.value
    .filter(d => d.kind === 'amenity' && d.is_active !== false && d.status !== 'inactive')
    .slice()
    .sort((a, b) => Number(a.display_order ?? 0) - Number(b.display_order ?? 0)
      || String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })),
)

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
  formatMoney(Number(selectedType.value?.base_price_cents ?? selectedType.value?.rate ?? 0)),
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
const summary = computed(() => {
  const counts = { total: rooms.value.length, active: 0, ready: 0, toClean: 0, blocked: 0 }
  for (const room of rooms.value) {
    if (room.is_active !== false) counts.active += 1
    const status = normalizeHk(room.housekeeping_status)
    if (status === 'clean' || status === 'inspected') counts.ready += 1
    else if (status === 'dirty' || status === 'cleaning') counts.toClean += 1
    else counts.blocked += 1
  }
  return counts
})

const hkTabs = computed(() => {
  const counts = new Map<HkStatus, number>()
  for (const room of filteredRooms.value) {
    const status = normalizeHk(room.housekeeping_status)
    counts.set(status, (counts.get(status) ?? 0) + 1)
  }
  return [
    { key: 'all' as const, label: t('hotel.rooms.allStatuses'), count: filteredRooms.value.length, tone: 'all' },
    ...housekeepingStatuses.map(status => ({
      key: status,
      label: hkLabel(status),
      count: counts.get(status) ?? 0,
      tone: hkTone(status),
    })),
  ]
})

const visibleRooms = computed(() => {
  const query = search.value.trim().toLowerCase()
  return filteredRooms.value.filter((room) => {
    if (hkFilter.value !== 'all' && normalizeHk(room.housekeeping_status) !== hkFilter.value) return false
    if (!query) return true
    return [room.number, room.display_name, typeNameOf(room)]
      .some(value => String(value ?? '').toLowerCase().includes(query))
  })
})

const floorGroups = computed(() => {
  const map = new Map<string, { key: string; title: string; subtitle: string; rooms: Doc[] }>()
  for (const room of visibleRooms.value) {
    const key = `${room.building_id ?? ''}|${room.floor_id ?? ''}`
    let group = map.get(key)
    if (!group) {
      const floorDoc = floors.value.find(item => item.id === room.floor_id)
      const building = room.building_name || buildings.value.find(item => item.id === room.building_id)?.name || ''
      const wing = room.wing_name || wings.value.find(item => item.id === room.wing_id)?.name || ''
      const floorTitle = floorDoc
        ? floorLabel(floorDoc)
        : room.floor_number != null ? `${t('hotel.rooms.floor')} ${room.floor_number}` : ''
      group = {
        key,
        title: floorTitle || building || t('hotel.rooms.noLocation'),
        subtitle: floorTitle ? [building, wing].filter(Boolean).join(' · ') : wing,
        rooms: [],
      }
      map.set(key, group)
    }
    group.rooms.push(room)
  }
  return [...map.values()]
})

const hasFilters = computed(() =>
  Boolean(search.value.trim()) || Boolean(selectedCategoryId.value) || hkFilter.value !== 'all',
)

function clearFilters() {
  search.value = ''
  selectedCategoryId.value = ''
  hkFilter.value = 'all'
}

const galleryItems = computed(() => {
  const loose = store.galleryImages.map(image => ({
    url: image.cdn_url,
    label: image.original_filename || '',
  }))
  const linked = store.products.flatMap(product => (product.images ?? []).map(image => ({
    url: image.cdn_url,
    label: product.name,
  })))
  return [...loose, ...linked].filter(item => Boolean(item.url))
})

onMounted(async () => {
  await Promise.all([load(), loadGallery()])
})
useRealtimeSync(['hotel.room.updated', 'hotel.reservation.created', 'hotel.reservation.updated'], () => load(true))

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
    amenity_ids: [] as string[],
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

async function load(silent?: boolean) {
  if (silent !== true) loading.value = true
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
    if (catalog) {
      await Promise.all([
        store.loadProducts(catalog.id),
        store.loadGalleryImages(catalog.id),
      ])
    }
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
    amenity_ids: Array.isArray(row.amenity_ids) ? [...row.amenity_ids] : [],
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
      amenity_ids: form.value.amenity_ids,
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

function normalizeHk(status?: string): HkStatus {
  return (status && housekeepingStatuses.includes(status as HkStatus) ? status : 'clean') as HkStatus
}

function hkLabel(status?: string) {
  return t(`hotel.rooms.hk.${normalizeHk(status)}`)
}

function hkTone(status?: string) {
  return hkMeta[normalizeHk(status)].tone
}

function hkIcon(status?: string) {
  return hkMeta[normalizeHk(status)].icon
}

function typeNameOf(row: Doc) {
  return String(row.type_name || roomTypeOf(row)?.name || t('hotel.rooms.otherCategory'))
}

function roomName(row: Doc) {
  const name = String(row.display_name ?? '').trim()
  return name && name !== String(row.number ?? '') ? name : ''
}

function nightlyPrice(row: Doc) {
  const type = roomTypeOf(row)
  const cents = row.price_override_cents != null
    ? Number(row.price_override_cents)
    : Number(type?.base_price_cents ?? type?.rate ?? 0)
  return formatMoney(cents, getAppCurrency())
}

function onHkChange(row: Doc, event: Event) {
  setHousekeeping(row, (event.target as HTMLSelectElement).value as HkStatus)
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
  const currency = getAppCurrency()
  return `${formatMoney(cents, currency)}/${t('hotel.rooms.perNight')}`
}

function descriptionOf(row: Doc) {
  const type = roomTypeOf(row)
  return String(type?.description ?? '').trim()
}

const amenityQuery = ref('')

const selectedTypeAmenityIds = computed(() =>
  Array.isArray(selectedType.value?.amenity_ids) ? selectedType.value.amenity_ids.map(String) : [],
)

const typeAmenities = computed(() =>
  selectedTypeAmenityIds.value
    .map(id => amenities.value.find(item => item.id === id))
    .filter((item): item is Doc => Boolean(item)),
)

const extraAmenityOptions = computed(() => {
  const q = amenityQuery.value.trim().toLowerCase()
  return amenities.value.filter((item) => {
    if (selectedTypeAmenityIds.value.includes(String(item.id))) return false
    if (!q) return true
    return String(item.name ?? '').toLowerCase().includes(q)
      || String(item.code ?? '').toLowerCase().includes(q)
  })
})

function toggleExtraAmenity(id: string) {
  const idx = form.value.amenity_ids.indexOf(id)
  if (idx >= 0) form.value.amenity_ids.splice(idx, 1)
  else form.value.amenity_ids.push(id)
}

function amenitiesOf(row: Doc) {
  const type = roomTypeOf(row)
  const typeIds = Array.isArray(type?.amenity_ids) ? type.amenity_ids.map(String) : []
  const extraIds = Array.isArray(row.amenity_ids) ? row.amenity_ids.map(String) : []
  const ids = [...new Set([...typeIds, ...extraIds])]
  return ids
    .map(id => amenities.value.find(item => item.id === id))
    .filter((item): item is Doc => Boolean(item))
}

</script>

<template>
  <HotelChrome scroll-body>
    <div class="rooms">
      <header class="rm-head">
        <p>{{ t('hotel.rooms.locationHint') }}</p>
        <button type="button" class="btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('hotel.rooms.createTitle') }}
        </button>
      </header>

      <dl class="rm-stats">
        <div class="rm-stat rm-stat--navy">
          <span class="rm-stat__icon" aria-hidden="true"><AppIcon name="bed" :size="18" /></span>
          <div>
            <dt>{{ t('hotel.rooms.statTotal') }}</dt>
            <dd>{{ summary.total }}</dd>
            <p>{{ t('hotel.rooms.statActive', { count: summary.active }) }}</p>
          </div>
        </div>
        <div class="rm-stat rm-stat--clean">
          <span class="rm-stat__icon" aria-hidden="true"><AppIcon name="check" :size="18" /></span>
          <div>
            <dt>{{ t('hotel.rooms.statReady') }}</dt>
            <dd>{{ summary.ready }}</dd>
            <p>{{ t('hotel.rooms.statReadyHint') }}</p>
          </div>
        </div>
        <div class="rm-stat rm-stat--dirty">
          <span class="rm-stat__icon" aria-hidden="true"><AppIcon name="broom" :size="18" /></span>
          <div>
            <dt>{{ t('hotel.rooms.statToClean') }}</dt>
            <dd>{{ summary.toClean }}</dd>
            <p>{{ t('hotel.rooms.statToCleanHint') }}</p>
          </div>
        </div>
        <div class="rm-stat rm-stat--maintenance">
          <span class="rm-stat__icon" aria-hidden="true"><AppIcon name="adjust" :size="18" /></span>
          <div>
            <dt>{{ t('hotel.rooms.statBlocked') }}</dt>
            <dd>{{ summary.blocked }}</dd>
            <p>{{ t('hotel.rooms.statBlockedHint') }}</p>
          </div>
        </div>
      </dl>

      <div class="rm-filters">
        <label class="rm-search">
          <AppIcon name="search" :size="16" />
          <input
            v-model="search"
            type="search"
            :placeholder="t('hotel.rooms.searchPlaceholder')"
            :aria-label="t('hotel.rooms.searchPlaceholder')"
          >
        </label>
        <label class="rm-type">
          <AppIcon name="catalog" :size="16" />
          <select v-model="selectedCategoryId" :aria-label="t('hotel.rooms.roomType')">
            <option value="">{{ t('hotel.rooms.allTypes') }}</option>
            <option v-for="cat in categories" :key="cat.id" :value="cat.id">
              {{ cat.name }} ({{ cat.count }})
            </option>
          </select>
        </label>
      </div>

      <div class="rm-chips" role="group" :aria-label="t('hotel.rooms.hkTitle')">
        <button
          v-for="tab in hkTabs"
          :key="tab.key"
          type="button"
          class="rm-chip"
          :class="[`rm-tone--${tab.tone}`, { 'is-active': hkFilter === tab.key }]"
          :aria-pressed="hkFilter === tab.key"
          @click="hkFilter = tab.key"
        >
          <i v-if="tab.key !== 'all'" aria-hidden="true" />
          {{ tab.label }}
          <span>{{ tab.count }}</span>
        </button>
      </div>

      <p v-if="error && !formOpen" class="rm-error" role="alert">
        <AppIcon name="alert" :size="16" />
        {{ error }}
      </p>

      <LoadingBlock v-if="loading" variant="cards" :rows="8" :label="t('common.loading')" />

      <div v-else-if="!rooms.length" class="rm-empty">
        <span class="rm-empty__icon" aria-hidden="true"><AppIcon name="bed" :size="26" /></span>
        <p class="rm-empty__title">{{ t('hotel.rooms.empty') }}</p>
        <p class="rm-empty__desc">{{ t('hotel.rooms.emptyHint') }}</p>
        <button type="button" class="btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('hotel.rooms.createTitle') }}
        </button>
      </div>

      <div v-else-if="!visibleRooms.length" class="rm-empty">
        <span class="rm-empty__icon" aria-hidden="true"><AppIcon name="search" :size="24" /></span>
        <p class="rm-empty__title">{{ t('hotel.rooms.noResults') }}</p>
        <button v-if="hasFilters" type="button" class="btn-secondary" @click="clearFilters">
          {{ t('hotel.rooms.clearFilters') }}
        </button>
      </div>

      <template v-else>
        <section v-for="group in floorGroups" :key="group.key" class="rm-floor">
          <header class="rm-floor__head">
            <span class="rm-floor__icon" aria-hidden="true"><AppIcon name="floors" :size="16" /></span>
            <h3>{{ group.title }}</h3>
            <span v-if="group.subtitle" class="rm-floor__sub">{{ group.subtitle }}</span>
            <span class="rm-floor__count">{{ t('hotel.rooms.categoryRooms', { count: group.rooms.length }) }}</span>
          </header>

          <ul class="rm-grid">
            <li
              v-for="row in group.rooms"
              :key="row.id"
              class="rm-tile"
              :class="[`rm-tone--${hkTone(row.housekeeping_status)}`, { 'is-off': row.is_active === false }]"
            >
              <div class="rm-tile__top">
                <span class="rm-tile__thumb">
                  <img v-if="roomPhotos(row)[0]" :src="roomPhotos(row)[0]" :alt="roomTitle(row)" loading="lazy">
                  <AppIcon v-else :name="spaceIcon(row.space_kind || roomTypeOf(row)?.space_kind)" :size="20" />
                </span>
                <div class="rm-tile__id">
                  <strong>{{ row.number }}</strong>
                  <span :title="spaceLabel(row.space_kind || roomTypeOf(row)?.space_kind)">{{ typeNameOf(row) }}</span>
                </div>
                <span v-if="row.is_active === false" class="rm-off">
                  <AppIcon name="pause" :size="12" />
                  {{ t('hotel.rooms.unavailable') }}
                </span>
              </div>

              <p v-if="roomName(row)" class="rm-tile__name">{{ roomName(row) }}</p>

              <ul class="rm-tile__facts">
                <li><AppIcon name="bed" :size="14" />{{ bedLabel(row) }}</li>
                <li><AppIcon name="account" :size="14" />{{ guestsLabel(row) }}</li>
              </ul>

              <p class="rm-tile__price">
                <strong>{{ nightlyPrice(row) }}</strong>
                <span>/ {{ t('hotel.rooms.perNight') }}</span>
              </p>

              <div v-if="amenitiesOf(row).length" class="rm-tile__amenities" :title="amenitiesOf(row).map(item => item.name).join(', ')">
                <span v-for="item in amenitiesOf(row).slice(0, 5)" :key="item.id" class="rm-amenity">
                  <AppIcon :name="item.icon_key || 'sparkles'" :size="14" />
                </span>
                <span v-if="amenitiesOf(row).length > 5" class="rm-amenity rm-amenity--more">
                  +{{ amenitiesOf(row).length - 5 }}
                </span>
              </div>

              <div class="rm-tile__foot">
                <label class="rm-hk" :class="{ 'is-busy': hkSavingId === row.id }">
                  <AppIcon :name="hkIcon(row.housekeeping_status)" :size="14" />
                  <select
                    :value="row.housekeeping_status || 'clean'"
                    :disabled="hkSavingId === row.id"
                    :aria-label="`${t('hotel.rooms.changeHk')} — ${row.number}`"
                    @change="onHkChange(row, $event)"
                  >
                    <option v-for="status in housekeepingStatuses" :key="status" :value="status">
                      {{ hkLabel(status) }}
                    </option>
                  </select>
                </label>
                <div class="rm-tile__actions">
                  <button
                    type="button"
                    class="rm-icon-btn"
                    :title="t('common.edit')"
                    :aria-label="`${t('common.edit')} ${row.number}`"
                    @click="openEdit(row)"
                  >
                    <AppIcon name="edit" :size="16" />
                  </button>
                  <button
                    type="button"
                    class="rm-icon-btn rm-icon-btn--danger"
                    :title="t('common.delete')"
                    :aria-label="`${t('common.delete')} ${row.number}`"
                    @click="remove(row)"
                  >
                    <AppIcon name="trash" :size="16" />
                  </button>
                </div>
              </div>
            </li>
          </ul>
        </section>
      </template>
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
                <span>{{ getAppCurrency() }}</span>
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
              <AppIcon name="plus" :size="16" />
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
          <div class="rooms__section-head">
            <div>
              <h3>
                <AppIcon name="sparkles" :size="15" />
                {{ t('hotel.rooms.amenities') }}
              </h3>
              <p>{{ t('hotel.rooms.amenitiesHint') }}</p>
            </div>
            <RouterLink to="/admin/hotel/room-config/amenities" class="room-card__type-link">
              {{ t('hotel.roomConfig.amenities') }}
            </RouterLink>
          </div>

          <div v-if="typeAmenities.length">
            <p class="rooms__label">{{ t('hotel.rooms.amenitiesFromType') }}</p>
            <div class="rooms__amenities">
              <span v-for="item in typeAmenities" :key="item.id" class="rooms__amenity rooms__amenity--type">
                <AppIcon :name="item.icon_key || 'sparkles'" :size="12" />
                {{ item.name }}
              </span>
            </div>
          </div>

          <div>
            <p class="rooms__label">{{ t('hotel.rooms.amenitiesExtra') }}</p>
            <input
              v-model="amenityQuery"
              class="field"
              :placeholder="t('hotel.rooms.amenitiesSearch')"
            >
            <div v-if="extraAmenityOptions.length" class="rooms__amenities">
              <label
                v-for="item in extraAmenityOptions"
                :key="item.id"
                class="rooms__amenity"
                :class="{ 'rooms__amenity--on': form.amenity_ids.includes(item.id) }"
              >
                <input
                  type="checkbox"
                  :checked="form.amenity_ids.includes(item.id)"
                  @change="toggleExtraAmenity(item.id)"
                >
                <AppIcon :name="item.icon_key || 'sparkles'" :size="12" />
                {{ item.name }}
              </label>
            </div>
            <p v-else-if="!typeAmenities.length" class="rooms__hint">{{ t('hotel.rooms.amenitiesEmpty') }}</p>
          </div>
        </section>

        <section class="rooms__block">
          <h3><AppIcon name="note" :size="15" /> {{ t('hotel.rooms.notes') }}</h3>
          <textarea v-model="form.notes" class="field" rows="3" :placeholder="t('hotel.rooms.notesPh')" />
        </section>

        <div class="rooms__actions">
          <button type="button" class="btn-secondary" @click="closeForm"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
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
        <button type="button" class="btn-primary" @click="galleryOpen = false"><AppIcon name="check" :size="16" /> {{ t('common.ok') }}</button>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.rooms {
  --hk-clean: #10a36b;
  --hk-dirty: #e0533a;
  --hk-cleaning: #2f6fed;
  --hk-inspected: #0f9f8f;
  --hk-maintenance: #ea8a12;
  --hk-oos: #64748b;

  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  width: 100%;
  margin-top: var(--space-2);
}

.rm-tone--all { --tone: var(--color-brand-500); }
.rm-tone--clean { --tone: var(--hk-clean); }
.rm-tone--dirty { --tone: var(--hk-dirty); }
.rm-tone--cleaning { --tone: var(--hk-cleaning); }
.rm-tone--inspected { --tone: var(--hk-inspected); }
.rm-tone--maintenance { --tone: var(--hk-maintenance); }
.rm-tone--oos { --tone: var(--hk-oos); }

/* ─── Header ──────────────────────────────────────────────────────── */
.rm-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
}

.rm-head p,
.rooms__intro {
  max-width: 62ch;
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  line-height: 1.55;
}

.rooms__form {
  display: flex;
  flex-direction: column;
}

/* ─── Summary ─────────────────────────────────────────────────────── */
.rm-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-3);
  margin: 0;
}

.rm-stat {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  min-width: 0;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}

.rm-stat > div {
  min-width: 0;
}

.rm-stat--navy { --tone: var(--color-brand-500); }
.rm-stat--clean { --tone: #10a36b; }
.rm-stat--dirty { --tone: #e0533a; }
.rm-stat--maintenance { --tone: #ea8a12; }

.rm-stat__icon {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
  color: var(--tone);
}

.rm-stat dt {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
}

.rm-stat dd {
  margin: 2px 0 0;
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}

.rm-stat p {
  margin: 2px 0 0;
  overflow: hidden;
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ─── Filters ─────────────────────────────────────────────────────── */
.rm-filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.rm-search,
.rm-type {
  display: flex;
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

.rm-search {
  flex: 1 1 280px;
}

.rm-type {
  flex: 0 1 280px;
}

.rm-search:focus-within,
.rm-type:focus-within {
  border-color: var(--color-brand-500);
  box-shadow: 0 0 0 3px var(--color-focus-ring);
}

.rooms .rm-search input,
.rooms .rm-type select {
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

.rm-type select {
  cursor: pointer;
}

.rm-chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.rm-chip {
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

.rm-chip i {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--tone);
}

.rm-chip span {
  min-width: 20px;
  padding: 0 6px;
  border-radius: 999px;
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
  font-size: var(--text-2xs);
  line-height: 18px;
  text-align: center;
}

.rm-chip:hover {
  border-color: color-mix(in srgb, var(--tone) 45%, var(--color-border));
}

.rm-chip.is-active {
  border-color: color-mix(in srgb, var(--tone) 55%, transparent);
  background: color-mix(in srgb, var(--tone) 10%, var(--color-surface));
  color: var(--color-text-primary);
}

.rm-chip.is-active span {
  background: var(--tone);
  color: #fff;
}

.rm-chip:focus-visible,
.rm-icon-btn:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.rm-error {
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
.rm-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  padding: 2.5rem var(--space-6);
  border: 1px dashed var(--color-border-strong);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  text-align: center;
}

.rm-empty__icon {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  margin-bottom: var(--space-2);
  border-radius: 18px;
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
}

.rm-empty__title {
  margin: 0;
  color: var(--color-text-primary);
  font-size: var(--text-md);
  font-weight: 600;
}

.rm-empty__desc {
  max-width: 52ch;
  margin: 0 0 var(--space-3);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

/* ─── Floor groups ────────────────────────────────────────────────── */
.rm-floor {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.rm-floor__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-3);
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--color-border);
}

.rm-floor__icon {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  border-radius: var(--radius-sm);
  background: var(--color-surface-muted);
  color: var(--color-text-secondary);
}

.rm-floor__head h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: var(--text-md);
  font-weight: 700;
}

.rm-floor__sub {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
}

.rm-floor__count {
  margin-left: auto;
  padding: 2px 10px;
  border-radius: 999px;
  background: var(--color-surface-muted);
  color: var(--color-text-muted);
  font-size: var(--text-2xs);
  font-weight: 600;
}

/* ─── Room tiles ──────────────────────────────────────────────────── */
.rm-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}

.rm-tile {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  min-width: 0;
  padding: var(--space-4);
  padding-top: calc(var(--space-4) + 3px);
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  transition:
    border-color var(--motion-normal) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.rm-tile::before {
  content: '';
  position: absolute;
  inset: 0 0 auto;
  height: 4px;
  background: var(--tone);
}

.rm-tile:hover {
  border-color: color-mix(in srgb, var(--tone) 40%, var(--color-border));
  box-shadow: var(--shadow-md);
  transform: var(--lift);
}

.rm-tile.is-off {
  background: var(--color-surface-muted);
}

.rm-tile.is-off .rm-tile__thumb {
  filter: grayscale(1);
  opacity: 0.7;
}

.rm-tile__top {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.rm-tile__thumb {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 48px;
  height: 48px;
  overflow: hidden;
  border-radius: 14px;
  background: color-mix(in srgb, var(--tone) 10%, var(--color-surface-muted));
  color: var(--tone);
}

.rm-tile__thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.rm-tile__id {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 0;
}

.rm-tile__id strong {
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: 1.375rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

.rm-tile__id span {
  overflow: hidden;
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rm-off {
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: 4px;
  align-self: flex-start;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--color-danger-bg);
  color: var(--color-danger);
  font-size: var(--text-2xs);
  font-weight: 700;
}

.rm-tile__name {
  margin: calc(var(--space-1) * -1) 0 0;
  overflow: hidden;
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rm-tile__facts {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1) var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--color-text-secondary);
  font-size: var(--text-xs);
}

.rm-tile__facts li {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.rm-tile__facts :deep(svg) {
  color: var(--color-text-faint);
}

.rm-tile__price {
  display: flex;
  align-items: baseline;
  gap: 4px;
  margin: 0;
}

.rm-tile__price strong {
  color: var(--color-text-primary);
  font-size: var(--text-base);
  font-variant-numeric: tabular-nums;
}

.rm-tile__price span {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
}

.rm-tile__amenities {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.rm-amenity {
  display: grid;
  place-items: center;
  min-width: 28px;
  height: 28px;
  padding: 0 6px;
  border-radius: var(--radius-sm);
  background: var(--color-surface-muted);
  color: var(--color-text-secondary);
}

.rm-amenity--more {
  color: var(--color-text-muted);
  font-size: var(--text-2xs);
  font-weight: 700;
}

.rm-tile__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  margin-top: auto;
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-table-border, var(--color-border));
}

.rm-hk {
  position: relative;
  display: inline-flex;
  flex: 1;
  align-items: center;
  gap: 6px;
  min-width: 0;
  height: 34px;
  padding: 0 var(--space-2) 0 10px;
  border: 1px solid color-mix(in srgb, var(--tone) 30%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--tone) 10%, var(--color-surface));
  color: color-mix(in srgb, var(--tone) 85%, var(--color-text-primary));
  transition: border-color var(--motion-fast) var(--ease-out);
}

.rm-hk:hover,
.rm-hk:focus-within {
  border-color: var(--tone);
}

.rooms .rm-hk select {
  flex: 1;
  min-width: 0;
  min-height: 0 !important;
  padding: 0 !important;
  border: 0 !important;
  outline: 0 !important;
  box-shadow: none !important;
  background: transparent !important;
  color: inherit;
  font-size: var(--text-xs);
  font-weight: 700;
  cursor: pointer;
}

.rm-hk select option {
  color: var(--color-text-primary);
}

.rm-hk.is-busy {
  opacity: 0.6;
}

.rm-tile__actions {
  display: flex;
  flex-shrink: 0;
  gap: var(--space-1);
}

.rm-icon-btn {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
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

.rm-icon-btn:hover {
  border-color: var(--color-brand-300);
  background: var(--color-brand-50);
  color: var(--color-ink-brand);
}

.rm-icon-btn--danger:hover {
  border-color: color-mix(in srgb, var(--color-danger) 35%, transparent);
  background: var(--color-danger-bg);
  color: var(--color-danger);
}

.room-card__type-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  margin-left: auto;
  color: var(--color-ink-brand, var(--color-brand-700));
  font-size: 0.75rem;
  font-weight: 600;
  text-decoration: none;
}

.room-card__type-link:hover {
  text-decoration: underline;
}

@media (max-width: 1100px) {
  .rm-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .rm-stats {
    grid-template-columns: 1fr;
  }

  .rm-type {
    flex-basis: 100%;
  }
}

@media (prefers-reduced-motion: reduce) {
  .rm-tile:hover {
    transform: none;
  }
}

.rooms__block h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.92rem;
  color: var(--color-text-primary);}

.rooms__block h3 :deep(svg) {
  color: var(--color-ink-brand, var(--color-brand-600, var(--color-brand-600)));}

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
  background: var(--color-table-header);}

.rooms__hk-pick--clean { background: var(--color-success-bg); color: light-dark(#047857, #96c6b8); border-color: #a7f3d0;}
.rooms__hk-pick--dirty { background: var(--color-danger-bg); color: light-dark(#b91c1c, #e2a0a0); border-color: #fecaca;}
.rooms__hk-pick--cleaning { background: var(--color-info-bg); color: light-dark(#1d4ed8, #a0b5ef); border-color: #bfdbfe;}
.rooms__hk-pick--inspected { background: #f0fdfa; color: light-dark(#0f766e, #9ac5c2); border-color: #99f6e4;}
.rooms__hk-pick--maintenance { background: var(--color-warning-bg); color: light-dark(#b45309, #d49b70); border-color: #fde68a;}
.rooms__hk-pick--oos { background: var(--color-table-header); color: var(--color-text-secondary); border-color: #cbd5e1;}

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
  color: var(--color-ink-brand, var(--color-brand-600));
  margin-bottom: 0.15rem;}
.rooms__error { margin: 0; padding: 0.7rem 0.85rem; border-radius: 0.7rem; background: var(--color-danger-bg); color: light-dark(#b91c1c, #e2a0a0); font-size: 0.85rem;}
.rooms__block { margin-top: 1.2rem; display: flex; flex-direction: column; gap: 0.7rem; }
.rooms__block:first-of-type { margin-top: 0.85rem; }
.rooms__label { margin: 0; font-size: 0.78rem; font-weight: 650; color: var(--color-text-muted); text-transform: uppercase; letter-spacing: 0.03em;}
.rooms__grid { display: grid; gap: 0.85rem 1rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rooms__grid { grid-template-columns: 1fr 1fr; }
  .rooms__span { grid-column: 1 / -1; }
}

.rooms__hint { margin: 0.3rem 0 0; font-size: 0.72rem; color: var(--color-text-faint);}
.rooms__modes { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.rooms__mode {
  display: inline-flex; align-items: center; gap: 0.35rem;
  padding: 0.4rem 0.7rem; border: 1px solid #d7e2ea; border-radius: 999px;
  font-size: 0.8rem; cursor: pointer; background: var(--color-surface);}
.rooms__mode input { accent-color: var(--color-brand-600); }
.rooms__mode--on { border-color: var(--color-brand-500); background: var(--color-brand-50); }
.rooms__spaces { display: grid; gap: 0.55rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rooms__spaces { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.rooms__space {
  display: flex; flex-direction: column; gap: 0.2rem;
  padding: 0.7rem; border: 1px solid #d7e2ea; border-radius: 0.7rem; cursor: pointer;
}
.rooms__space input { position: absolute; opacity: 0; pointer-events: none; }
.rooms__space strong { font-size: 0.82rem; color: var(--color-text-primary);}
.rooms__space span { font-size: 0.72rem; color: var(--color-text-muted); line-height: 1.35;}
.rooms__space--on { border-color: var(--color-brand-500); background: var(--color-brand-50); }
.rooms__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.rooms__money span { font-weight: 700; color: var(--color-ink-brand, var(--color-brand-600));}
.rooms-switch {
  display: inline-flex; align-items: center; gap: 0.55rem;
  margin-top: 0.35rem; font-size: 0.875rem; color: var(--color-text-primary); cursor: pointer;}
.rooms-switch input { position: absolute; opacity: 0; pointer-events: none; }
.rooms-switch__track {
  width: 2.2rem; height: 1.2rem; border-radius: 999px; background: #d7e2ea; position: relative;
}
.rooms-switch__track::after {
  content: ""; position: absolute; top: 0.15rem; left: 0.15rem;
  width: 0.9rem; height: 0.9rem; border-radius: 50%; background: var(--color-surface); transition: transform 0.15s ease;}
.rooms-switch input:checked + .rooms-switch__track { background: var(--color-brand-600, var(--color-brand-600)); }
.rooms-switch input:checked + .rooms-switch__track::after { transform: translateX(1rem); }
.rooms__section-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }
.rooms__section-head p { margin: 0.25rem 0 0; color: var(--color-text-muted); font-size: 0.8rem;}
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
.rooms__empty-photos { padding: 0.9rem; border: 1px dashed #d7e2ea; border-radius: 0.75rem; background: var(--color-table-header);}
.rooms__empty-photos p { margin: 0; font-weight: 600; color: var(--color-text-primary);}
.rooms__empty-photos small { color: var(--color-text-muted);}
.room-card__amenity-list,
.rooms__amenities {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.4rem;
}

.room-card__amenity,
.rooms__amenity {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.28rem 0.55rem;
  border: 1px solid #d7e2ea;
  border-radius: 999px;
  font-size: 0.74rem;
  background: var(--color-surface);
  color: var(--color-text-secondary);}

.rooms__amenity { cursor: pointer; }
.rooms__amenity input { accent-color: var(--color-brand-600); }
.rooms__amenity--on,
.rooms__amenity--type {
  border-color: var(--color-brand-500);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-700));}

.rooms__actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.1rem; }
.rooms__row-actions { text-align: right; white-space: nowrap; }
.rooms__row-actions button + button { margin-left: 0.7rem; }
.rooms__muted, .rooms__empty { margin: 0; padding: 1.2rem; text-align: center; color: var(--color-text-muted); font-size: 0.875rem;}
.rooms__gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr)); gap: 0.65rem; max-height: 24rem; overflow: auto; }
.rooms__gallery-item {
  display: flex; flex-direction: column; gap: 0.35rem; border: 1px solid #e2e8f0;
  border-radius: 0.65rem; overflow: hidden; background: var(--color-surface); padding: 0; text-align: left; cursor: pointer;}
.rooms__gallery-item img { aspect-ratio: 1; width: 100%; object-fit: cover; }
.rooms__gallery-item span { padding: 0 0.5rem 0.5rem; font-size: 0.75rem; color: var(--color-text-secondary);}
.rooms__gallery-item--on { border-color: var(--color-brand-500); box-shadow: 0 0 0 1px color-mix(in srgb, var(--color-brand-500) 40%, transparent); }


.font-semibold { font-weight: 600; }
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}
.text-red-600 { color: light-dark(#dc2626, #f0a4a4);}
</style>
