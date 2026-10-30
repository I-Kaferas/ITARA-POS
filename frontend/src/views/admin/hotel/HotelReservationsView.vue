<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_RESERVATION_KINDS } from '../../../api/hospitality'
import { useConfirm } from '../../../composables/useConfirm'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Customer } from '../../../types'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { getAppCurrency } from '../../../utils/currency'
import { computeStayTaxes, findHotelSettings, moneyFromSettingsCents } from '../../../utils/hotelSettings'
import HotelChrome from './HotelChrome.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'

type Doc = Record<string, any>
type SpaceKind = 'guest_room' | 'conference' | 'reception'
type ClientMode = 'new' | 'existing'
type Channel = 'direct' | 'phone' | 'walk_in' | 'booking_com' | 'expedia' | 'other'

const { t, locale } = useI18n()
const router = useRouter()
const route = useRoute()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const docs = ref<Doc[]>([])
const hotelSettings = computed(() => findHotelSettings(docs.value))
const editingId = ref<string | null>(null)
const formOpen = ref(false)
const detailOpen = ref(false)
const detailRow = ref<Doc | null>(null)
const saving = ref(false)
const loading = ref(false)
const error = ref('')
const customerSearch = ref('')
const form = ref(blankForm())

type ListScope = 'active' | 'history'
type StatusFilter = 'all' | 'pending' | 'confirmed' | 'guaranteed'
type DatePreset = 'all' | 'today' | 'next7' | 'arrivals_today'

const listSearch = ref('')
const listScope = ref<ListScope>('active')
const statusFilter = ref<StatusFilter>('all')
const datePreset = ref<DatePreset>('all')
const dateFrom = ref('')
const dateTo = ref('')
const filtersOpen = ref(false)

const formTitle = computed(() =>
  editingId.value ? t('hotel.reservations.editTitle') : t('hotel.reservations.createTitle'),
)

const spaceKinds: { id: SpaceKind; titleKey: string; hintKey: string; icon: string }[] = [
  { id: 'guest_room', titleKey: 'hotel.roomTypes.space.guest', hintKey: 'hotel.reservations.spaceGuestHint', icon: 'bed' },
  { id: 'conference', titleKey: 'hotel.roomTypes.space.conference', hintKey: 'hotel.roomTypes.space.conferenceHint', icon: 'organization' },
  { id: 'reception', titleKey: 'hotel.roomTypes.space.reception', hintKey: 'hotel.roomTypes.space.receptionHint', icon: 'sparkles' },
]

const channels: Channel[] = ['direct', 'phone', 'walk_in', 'booking_com', 'expedia', 'other']

const roomTypes = computed(() => docs.value.filter(d => d.kind === 'room_type'))
const reservations = computed(() =>
  docs.value
    .filter(d => d.kind === 'reservation' && !d.walk_in)
    .slice()
    .sort((a, b) => String(b.arrive_on ?? '').localeCompare(String(a.arrive_on ?? ''))),
)

function todayIso() {
  return toDateInput(new Date())
}

function addDaysIso(days: number) {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return toDateInput(d)
}

function reservationBucket(row: Doc): StatusFilter {
  const status = String(row.status || 'confirmed')
  if (Number(row.deposit_cents || 0) > 0 || status === 'guaranteed') return 'guaranteed'
  if (status === 'reserved' || status === 'pending') return 'pending'
  if (status === 'confirmed') return 'confirmed'
  return 'confirmed'
}

function isHistory(row: Doc) {
  const status = String(row.status || '')
  return ['checked_out', 'cancelled', 'no_show'].includes(status)
}

function dayOf(value: unknown) {
  return String(value || '').slice(0, 10)
}

function matchesSearchAndDates(row: Doc) {
  const today = todayIso()
  const arrive = dayOf(row.arrive_on)
  if (datePreset.value === 'today' && arrive !== today) return false
  if (datePreset.value === 'arrivals_today' && arrive !== today) return false
  if (datePreset.value === 'next7' && (arrive < today || arrive > addDaysIso(7))) return false
  if (dateFrom.value && arrive < dateFrom.value) return false
  if (dateTo.value && arrive > dateTo.value) return false

  const q = listSearch.value.trim().toLowerCase()
  if (!q) return true
  const hay = `${row.guest_name || ''} ${row.guest_email || ''} ${row.stay_code || ''} ${row.reservation_no || ''} ${row.id || ''} ${row.guest_phone || ''} ${row.type_name || ''} ${row.room_number || ''}`.toLowerCase()
  return hay.includes(q)
}

const baseRows = computed(() =>
  reservations.value.filter(row =>
    (listScope.value === 'history') === isHistory(row) && matchesSearchAndDates(row),
  ),
)

const filteredReservations = computed(() =>
  statusFilter.value === 'all'
    ? baseRows.value
    : baseRows.value.filter(row => reservationBucket(row) === statusFilter.value),
)
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filteredReservations)

const statusCounts = computed(() => {
  const counts: Record<StatusFilter, number> = { all: baseRows.value.length, pending: 0, confirmed: 0, guaranteed: 0 }
  for (const row of baseRows.value) counts[reservationBucket(row)] += 1
  return counts
})

const dateFilterCount = computed(() =>
  (datePreset.value !== 'all' ? 1 : 0) + (dateFrom.value ? 1 : 0) + (dateTo.value ? 1 : 0),
)

const activeFilterCount = computed(() =>
  dateFilterCount.value
  + (statusFilter.value !== 'all' ? 1 : 0)
  + (listSearch.value.trim() ? 1 : 0),
)

const scopeTabs = computed(() => {
  const history = reservations.value.filter(isHistory).length
  return [
    { id: 'active' as const, label: t('hotel.reservations.filters.active'), count: reservations.value.length - history },
    { id: 'history' as const, label: t('hotel.reservations.filters.history'), count: history },
  ]
})

const kpis = computed(() => {
  const today = todayIso()
  const next7 = addDaysIso(7)
  let arrivals = 0
  let departures = 0
  let inHouse = 0
  let upcoming = 0
  let valueCents = 0
  for (const row of reservations.value) {
    if (isHistory(row)) continue
    const arrive = dayOf(row.arrive_on)
    const depart = dayOf(row.depart_on)
    if (arrive === today) arrivals += 1
    if (depart === today) departures += 1
    if (progressKey(row) === 'in_progress') inHouse += 1
    if (arrive >= today && arrive <= next7) upcoming += 1
    valueCents += rowTotalCents(row)
  }
  return { arrivals, departures, inHouse, upcoming, valueCents }
})

function applyKpi(preset: DatePreset) {
  listScope.value = 'active'
  statusFilter.value = 'all'
  dateFrom.value = ''
  dateTo.value = ''
  datePreset.value = datePreset.value === preset ? 'all' : preset
}

const statusFilters = computed(() => ([
  { id: 'all' as const, label: t('hotel.reservations.filters.allStatuses') },
  { id: 'pending' as const, label: t('hotel.reservations.filters.pending') },
  { id: 'confirmed' as const, label: t('hotel.reservations.filters.confirmed') },
  { id: 'guaranteed' as const, label: t('hotel.reservations.filters.guaranteed') },
]))

const datePresets = computed(() => ([
  { id: 'today' as const, label: t('hotel.reservations.filters.today') },
  { id: 'next7' as const, label: t('hotel.reservations.filters.next7') },
  { id: 'arrivals_today' as const, label: t('hotel.reservations.filters.arrivalsToday') },
]))

function clearFilters() {
  listSearch.value = ''
  statusFilter.value = 'all'
  datePreset.value = 'all'
  dateFrom.value = ''
  dateTo.value = ''
}

function setDatePreset(preset: DatePreset) {
  datePreset.value = datePreset.value === preset ? 'all' : preset
  if (datePreset.value !== 'all') {
    dateFrom.value = ''
    dateTo.value = ''
  }
}

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

const customers = computed(() => store.customers.filter(c => c.is_active !== false))

const filteredCustomers = computed(() => {
  const q = customerSearch.value.trim().toLowerCase()
  if (!q) return customers.value.slice(0, 40)
  return customers.value
    .filter((c) => {
      const hay = `${c.name} ${c.email ?? ''} ${c.phone ?? ''}`.toLowerCase()
      return hay.includes(q)
    })
    .slice(0, 40)
})

const selectedCustomer = computed(() =>
  customers.value.find(c => c.id === form.value.customer_id) ?? null,
)

watch(() => form.value.space_kind, () => {
  if (form.value.type_id && !typeOptions.value.some(t => t.id === form.value.type_id)) {
    form.value.type_id = typeOptions.value[0]?.id ?? ''
  }
})

watch(() => form.value.client_mode, (mode) => {
  if (mode === 'new') {
    form.value.customer_id = ''
  }
})

onMounted(async () => {
  await Promise.all([load(), store.loadCustomers().catch(() => undefined)])
  if (route.query.new === '1') openCreate()
})
useRealtimeSync(realtimeTopics.hotel, () => load(true))

function blankForm() {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  const dayAfter = new Date(tomorrow)
  dayAfter.setDate(dayAfter.getDate() + 1)
  const depositDefault = moneyFromSettingsCents(hotelSettings.value.deposit_amount_cents)
  return {
    client_mode: 'new' as ClientMode,
    customer_id: '',
    guest_name: '',
    guest_email: '',
    guest_phone: '',
    space_kind: 'guest_room' as SpaceKind,
    type_id: '',
    arrive_on: toDateInput(tomorrow),
    depart_on: toDateInput(dayAfter),
    adults: '2',
    children: '0',
    deposit: depositDefault > 0 ? String(depositDefault) : '',
    channel: 'direct' as Channel,
    special_requests: '',
  }
}

function toDateInput(d: Date) {
  return d.toISOString().slice(0, 10)
}

function typePriceLabel(type: Doc) {
  const cents = Number(type.base_price_cents ?? type.rate ?? 0)
  const currency = getAppCurrency()
  return `${type.name} — ${formatMoney(cents, currency)}/${t('hotel.rooms.perNight')}`
}

function statusLabel(status?: string) {
  const key = String(status || 'confirmed')
  const path = `hotel.reservations.status.${key}`
  return t(path) !== path ? t(path) : key
}

function bookingStatusKey(row: Doc) {
  return reservationBucket(row)
}

function bookingStatusLabel(row: Doc) {
  return t(`hotel.reservations.filters.${bookingStatusKey(row)}`)
}

function progressKey(row: Doc) {
  const status = String(row.status || '')
  if (status === 'checked_in') return 'in_progress'
  if (status === 'checked_out') return 'done'
  if (status === 'cancelled' || status === 'no_show') return 'closed'
  const today = todayIso()
  const arrive = String(row.arrive_on || '').slice(0, 10)
  const depart = String(row.depart_on || '').slice(0, 10)
  if (arrive && depart && arrive <= today && today < depart) return 'in_progress'
  if (arrive && arrive > today) return 'upcoming'
  return 'upcoming'
}

function progressLabel(row: Doc) {
  return t(`hotel.reservations.progress.${progressKey(row)}`)
}

function channelLabel(channel?: string) {
  const key = String(channel || 'direct')
  return t(`hotel.reservations.channels.${key}`)
}

function spaceLabel(kind?: string) {
  if (kind === 'conference') return t('hotel.roomTypes.space.conference')
  if (kind === 'reception') return t('hotel.roomTypes.space.reception')
  return t('hotel.roomTypes.space.guest')
}

function nightsOf(row: Doc) {
  if (row.nights != null) return Number(row.nights)
  if (!row.arrive_on || !row.depart_on) return 0
  const a = new Date(String(row.arrive_on))
  const b = new Date(String(row.depart_on))
  return Math.max(0, Math.round((b.getTime() - a.getTime()) / 86400000))
}

function bookingCode(row: Doc) {
  return String(row.stay_code || '').trim() || '—'
}

function reservationNo(row: Doc) {
  const no = String(row.reservation_no || '').trim()
  if (no) return no
  const id = String(row.id || '')
  return id ? `RES-${id.slice(0, 3).toUpperCase()}` : '—'
}

function initials(name?: string) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return `${parts[0][0] ?? ''}${parts[1][0] ?? ''}`.toUpperCase()
}

const AVATAR_TONES = 6

function avatarTone(name?: string) {
  const key = String(name || '')
  let hash = 0
  for (let i = 0; i < key.length; i += 1) hash = (hash * 31 + key.charCodeAt(i)) >>> 0
  return hash % AVATAR_TONES
}

function dayParts(value: unknown) {
  const iso = dayOf(value)
  if (!iso) return null
  const date = new Date(`${iso}T00:00:00`)
  if (Number.isNaN(date.getTime())) return null
  const loc = String(locale.value || 'fr')
  const clean = (s: string) => s.replace(/\.$/, '')
  return {
    iso,
    day: date.getDate(),
    month: clean(date.toLocaleDateString(loc, { month: 'short' })),
    weekday: clean(date.toLocaleDateString(loc, { weekday: 'short' })),
    long: date.toLocaleDateString(loc, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }),
  }
}

function canEdit(row: Doc) {
  return !['checked_in', 'checked_out'].includes(String(row.status || ''))
}

function balanceCents(row: Doc) {
  return Math.max(0, rowTotalCents(row) - Number(row.deposit_collected_cents || 0))
}

const formNights = computed(() => {
  const { arrive_on, depart_on } = form.value
  if (!arrive_on || !depart_on) return 0
  return Math.max(0, Math.round((new Date(depart_on).getTime() - new Date(arrive_on).getTime()) / 86400000))
})

const formEstimateCents = computed(() => {
  const type = selectedType.value
  if (!type) return 0
  const rate = Number(type.base_price_cents ?? type.rate ?? 0)
  return computeStayTaxes(Math.max(0, formNights.value * rate), hotelSettings.value).totalCents
})

function rowCurrency(_row?: Doc) {
  return getAppCurrency()
}

function rowTotalCents(row: Doc) {
  const nights = nightsOf(row)
  const rate = Number(row.type_rate_cents ?? 0)
  const subtotal = Math.max(0, nights * rate)
  return computeStayTaxes(subtotal, hotelSettings.value).totalCents
}

function typeCover(row: Doc) {
  const type = roomTypes.value.find(item => item.id === row.type_id)
  const urls = Array.isArray(type?.photo_urls) ? type.photo_urls : []
  return urls[0] ? String(urls[0]) : ''
}

function openDetail(row: Doc) {
  detailRow.value = row
  detailOpen.value = true
}

function closeDetail() {
  detailOpen.value = false
  detailRow.value = null
}

function editFromDetail() {
  const row = detailRow.value
  if (!row) return
  closeDetail()
  openEdit(row)
}

const detailHistory = computed(() => {
  const row = detailRow.value
  if (!row) return []
  const customerId = String(row.customer_id || '')
  const email = String(row.guest_email || '').trim().toLowerCase()
  const name = String(row.guest_name || '').trim().toLowerCase()
  return reservations.value.filter((item) => {
    if (item.id === row.id) return true
    if (customerId && String(item.customer_id || '') === customerId) return true
    if (email && String(item.guest_email || '').trim().toLowerCase() === email) return true
    if (name && String(item.guest_name || '').trim().toLowerCase() === name) return true
    return false
  })
})

function notifyGuest(row: Doc) {
  const email = String(row.guest_email || '').trim()
  if (!email) {
    error.value = t('hotel.reservations.detail.noEmail')
    return
  }
  const subject = encodeURIComponent(
    t('hotel.reservations.detail.notifySubject', { code: bookingCode(row) }),
  )
  window.location.href = `mailto:${email}?subject=${subject}`
}

function openStay(row: Doc) {
  closeDetail()
  router.push({ path: '/admin/hotel/stays', query: { reservation: String(row.id || '') } })
}

function canOpenStay(row: Doc) {
  return ['checked_in', 'confirmed', 'reserved'].includes(String(row.status || ''))
}

async function load(silent?: boolean) {
  if (silent !== true) loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_RESERVATION_KINDS]))).data.docs
    if (!form.value.type_id) {
      form.value.type_id = typeOptions.value[0]?.id ?? ''
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function pickCustomer(customer: Customer) {
  form.value.customer_id = customer.id
  form.value.guest_name = customer.name
  form.value.guest_email = customer.email ?? ''
  form.value.guest_phone = customer.phone ?? ''
  customerSearch.value = ''
}

function resetForm() {
  editingId.value = null
  form.value = blankForm()
  form.value.type_id = typeOptions.value[0]?.id ?? ''
  customerSearch.value = ''
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

function openEdit(row: Doc) {
  editingId.value = row.id
  form.value = {
    client_mode: row.customer_id ? 'existing' : 'new',
    customer_id: row.customer_id ?? '',
    guest_name: String(row.guest_name ?? ''),
    guest_email: String(row.guest_email ?? ''),
    guest_phone: String(row.guest_phone ?? ''),
    space_kind: (row.space_kind as SpaceKind) || 'guest_room',
    type_id: row.type_id ?? '',
    arrive_on: String(row.arrive_on ?? '').slice(0, 10),
    depart_on: String(row.depart_on ?? '').slice(0, 10),
    adults: String(row.adults ?? 2),
    children: String(row.children ?? 0),
    deposit: row.deposit_cents != null ? String(Number(row.deposit_cents) / 100) : '',
    channel: (row.channel as Channel) || 'direct',
    special_requests: String(row.special_requests ?? ''),
  }
  customerSearch.value = ''
  error.value = ''
  formOpen.value = true
}

async function save() {
  if (!form.value.guest_name.trim()) {
    error.value = t('hotel.reservations.errors.guestName')
    return
  }
  if (!form.value.type_id) {
    error.value = t('hotel.reservations.errors.type')
    return
  }
  if (!form.value.arrive_on || !form.value.depart_on) {
    error.value = t('hotel.reservations.errors.dates')
    return
  }

  saving.value = true
  error.value = ''
  try {
    let customerId = form.value.customer_id
    if (form.value.client_mode === 'new') {
      const created = await store.saveCustomer({
        name: form.value.guest_name.trim(),
        email: form.value.guest_email.trim() || null,
        phone: form.value.guest_phone.trim() || null,
        is_active: true,
      })
      customerId = created.id
      await store.loadCustomers().catch(() => undefined)
    } else if (!customerId) {
      error.value = t('hotel.reservations.errors.pickCustomer')
      saving.value = false
      return
    }

    const depositCents = form.value.deposit.trim()
      ? parseMoneyInput(form.value.deposit)
      : null

    const payload: Record<string, unknown> = {
      action: 'upsert_reservation',
      customer_id: customerId,
      guest_name: form.value.guest_name.trim(),
      guest_email: form.value.guest_email.trim() || null,
      guest_phone: form.value.guest_phone.trim() || null,
      space_kind: form.value.space_kind,
      type_id: form.value.type_id,
      arrive_on: form.value.arrive_on,
      depart_on: form.value.depart_on,
      adults: Number(form.value.adults) || 1,
      children: Number(form.value.children) || 0,
      deposit_cents: depositCents,
      channel: form.value.channel,
      special_requests: form.value.special_requests.trim() || null,
    }
    if (editingId.value) payload.id = editingId.value

    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', payload)).data.docs
    formOpen.value = false
    resetForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function remove(row: Doc) {
  const ok = await confirmDialog(t('hotel.reservations.deleteConfirm', { name: row.guest_name }), {
    title: t('hotel.reservations.deleteTitle'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'delete_reservation',
      id: row.id,
    })).data.docs
    if (editingId.value === row.id) closeForm()
    if (detailRow.value?.id === row.id) closeDetail()
  } catch (err) {
    const message = extractApiErrorMessage(err)
    if (message.toLowerCase().includes('force=1') || message.toLowerCase().includes('pénalité') || message.toLowerCase().includes('penalty')) {
      const force = await confirmDialog(`${message}\n\n${t('hotel.settings.cancelForceHint')}`, {
        title: t('hotel.reservations.deleteTitle'),
        confirmLabel: t('common.delete'),
        danger: true,
      })
      if (!force) return
      docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
        action: 'delete_reservation',
        id: row.id,
        force: 1,
      })).data.docs
      if (editingId.value === row.id) closeForm()
      if (detailRow.value?.id === row.id) closeDetail()
      return
    }
    error.value = message
  }
}
</script>

<template>
  <HotelChrome scroll-body>
    <div class="rsv">
      <section class="rsv-kpis" :aria-label="t('hotel.reservations.listTitle')">
        <button
          type="button"
          class="rsv-kpi"
          :class="{ 'rsv-kpi--on': datePreset === 'arrivals_today' }"
          @click="applyKpi('arrivals_today')"
        >
          <span class="rsv-kpi__icon rsv-kpi__icon--in"><AppIcon name="key" :size="16" /></span>
          <span class="rsv-kpi__body">
            <small>{{ t('hotel.reservations.kpi.arrivalsToday') }}</small>
            <strong>{{ kpis.arrivals }}</strong>
          </span>
        </button>
        <div class="rsv-kpi rsv-kpi--static">
          <span class="rsv-kpi__icon rsv-kpi__icon--out"><AppIcon name="logout" :size="16" /></span>
          <span class="rsv-kpi__body">
            <small>{{ t('hotel.reservations.kpi.departuresToday') }}</small>
            <strong>{{ kpis.departures }}</strong>
          </span>
        </div>
        <div class="rsv-kpi rsv-kpi--static">
          <span class="rsv-kpi__icon rsv-kpi__icon--house"><AppIcon name="bed" :size="16" /></span>
          <span class="rsv-kpi__body">
            <small>{{ t('hotel.reservations.kpi.inHouse') }}</small>
            <strong>{{ kpis.inHouse }}</strong>
          </span>
        </div>
        <button
          type="button"
          class="rsv-kpi"
          :class="{ 'rsv-kpi--on': datePreset === 'next7' }"
          @click="applyKpi('next7')"
        >
          <span class="rsv-kpi__icon rsv-kpi__icon--next"><AppIcon name="calendar" :size="16" /></span>
          <span class="rsv-kpi__body">
            <small>{{ t('hotel.reservations.kpi.next7') }}</small>
            <strong>{{ kpis.upcoming }}</strong>
          </span>
        </button>
        <div class="rsv-kpi rsv-kpi--static rsv-kpi--feature">
          <span class="rsv-kpi__icon"><AppIcon name="coins" :size="16" /></span>
          <span class="rsv-kpi__body">
            <small>{{ t('hotel.reservations.kpi.pipeline') }}</small>
            <strong>{{ formatMoney(kpis.valueCents, rowCurrency()) }}</strong>
          </span>
        </div>
      </section>

      <section class="rsv-panel">
        <header class="rsv-panel__head">
          <div class="rsv-panel__title">
            <h3>{{ t('hotel.reservations.listTitle') }}</h3>
            <span class="rsv-panel__count">{{ filteredReservations.length }}</span>
          </div>
          <div class="rsv-seg" role="tablist">
            <button
              v-for="tab in scopeTabs"
              :key="tab.id"
              type="button"
              role="tab"
              class="rsv-seg__btn"
              :class="{ 'rsv-seg__btn--on': listScope === tab.id }"
              :aria-selected="listScope === tab.id"
              @click="listScope = tab.id"
            >
              {{ tab.label }}
              <em>{{ tab.count }}</em>
            </button>
          </div>
          <button type="button" class="btn-primary rsv-panel__new" @click="openCreate">
            <AppIcon name="plus" :size="16" />
            {{ t('hotel.reservations.createTitle') }}
          </button>
        </header>

        <div class="rsv-toolbar">
          <label class="rsv-search">
            <AppIcon name="search" :size="15" class="rsv-search__icon" />
            <input
              v-model="listSearch"
              class="field field--compact rsv-search__input"
              type="search"
              :aria-label="t('hotel.reservations.searchAria')"
              :placeholder="t('hotel.reservations.filters.searchPh')"
            >
            <button
              v-if="listSearch"
              type="button"
              class="rsv-search__clear"
              :aria-label="t('hotel.reservations.filters.clear')"
              @click="listSearch = ''"
            >
              <AppIcon name="close" :size="13" />
            </button>
          </label>

          <div class="rsv-status">
            <button
              v-for="item in statusFilters"
              :key="item.id"
              type="button"
              class="rsv-status__btn"
              :class="[`rsv-status__btn--${item.id}`, { 'rsv-status__btn--on': statusFilter === item.id }]"
              @click="statusFilter = item.id"
            >
              <i v-if="item.id !== 'all'" class="rsv-dot" />
              {{ item.label }}
              <em>{{ statusCounts[item.id] }}</em>
            </button>
          </div>

          <div class="rsv-toolbar__end">
            <button
              type="button"
              class="rsv-filter-btn"
              :class="{ 'rsv-filter-btn--on': filtersOpen || dateFilterCount > 0 }"
              :aria-expanded="filtersOpen"
              @click="filtersOpen = !filtersOpen"
            >
              <AppIcon name="calendar" :size="14" />
              {{ filtersOpen ? t('filters.hide') : t('filters.show') }}
              <em v-if="dateFilterCount">{{ dateFilterCount }}</em>
              <AppIcon
                name="chevron-down"
                :size="13"
                class="rsv-filter-btn__caret"
                :class="{ 'rsv-filter-btn__caret--open': filtersOpen }"
              />
            </button>
            <button
              v-if="activeFilterCount"
              type="button"
              class="rsv-reset"
              @click="clearFilters"
            >
              <AppIcon name="close" :size="13" />
              {{ t('hotel.reservations.filters.clear') }}
            </button>
          </div>
        </div>

        <div class="fold-panel" :class="{ 'is-open': filtersOpen }">
          <div class="fold-panel__body" :inert="!filtersOpen">
            <div class="rsv-filters">
              <div class="rsv-filters__presets">
                <button
                  v-for="item in datePresets"
                  :key="item.id"
                  type="button"
                  class="rsv-chip"
                  :class="{ 'rsv-chip--on': datePreset === item.id }"
                  @click="setDatePreset(item.id)"
                >
                  {{ item.label }}
                </button>
              </div>
              <div class="rsv-filters__range">
                <label>
                  <span>{{ t('hotel.reservations.filters.from') }}</span>
                  <input v-model="dateFrom" class="field field--compact" type="date" @change="datePreset = 'all'">
                </label>
                <AppIcon name="chevron-right" :size="14" class="rsv-filters__arrow" />
                <label>
                  <span>{{ t('hotel.reservations.filters.to') }}</span>
                  <input v-model="dateTo" class="field field--compact" type="date" @change="datePreset = 'all'">
                </label>
              </div>
            </div>
          </div>
        </div>

        <p v-if="error && !formOpen && !detailOpen" class="rsv__error rsv__error--inline">{{ error }}</p>
        <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />
        <template v-else>
          <div v-if="filteredReservations.length" class="rsv-table-wrap">
            <table class="rsv-table">
              <thead>
                <tr>
                  <th>{{ t('hotel.reservations.cols.reference') }}</th>
                  <th>{{ t('hotel.reservations.cols.client') }}</th>
                  <th>{{ t('hotel.reservations.cols.lodging') }}</th>
                  <th>{{ t('hotel.reservations.cols.stay') }}</th>
                  <th class="rsv-table__num">{{ t('hotel.reservations.cols.total') }}</th>
                  <th>{{ t('hotel.guests.cols.status') }}</th>
                  <th class="rsv-table__actions"><span class="sr-only">{{ t('hotel.reservations.cols.actions') }}</span></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in paged"
                  :key="row.id"
                  class="rsv-row"
                  tabindex="0"
                  @click="openDetail(row)"
                  @keydown.enter.self="openDetail(row)"
                >
                  <td class="rsv-row__ref">
                    <strong>{{ bookingCode(row) }}</strong>
                    <small>{{ reservationNo(row) }} · {{ channelLabel(row.channel) }}</small>
                  </td>
                  <td>
                    <div class="rsv-client">
                      <span class="rsv-avatar" :class="`rsv-avatar--${avatarTone(row.guest_name)}`">{{ initials(row.guest_name) }}</span>
                      <div>
                        <strong>{{ row.guest_name || '—' }}</strong>
                        <small>{{ row.guest_phone || row.guest_email || '—' }}</small>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="rsv-lodging">
                      <strong>{{ row.type_name || '—' }}</strong>
                      <small>
                        <span class="rsv-tag">{{ spaceLabel(row.space_kind) }}</span>
                        <span v-if="row.room_number" class="rsv-room">#{{ row.room_number }}</span>
                      </small>
                    </div>
                  </td>
                  <td>
                    <div class="rsv-stay">
                      <span v-if="dayParts(row.arrive_on)" class="rsv-day" :title="dayParts(row.arrive_on)?.long">
                        <b>{{ dayParts(row.arrive_on)?.day }}</b>
                        <small>{{ dayParts(row.arrive_on)?.month }}</small>
                      </span>
                      <span class="rsv-stay__bridge">
                        <em>{{ nightsOf(row) }} {{ t('hotel.reservations.nights') }}</em>
                      </span>
                      <span v-if="dayParts(row.depart_on)" class="rsv-day" :title="dayParts(row.depart_on)?.long">
                        <b>{{ dayParts(row.depart_on)?.day }}</b>
                        <small>{{ dayParts(row.depart_on)?.month }}</small>
                      </span>
                    </div>
                  </td>
                  <td class="rsv-table__num">
                    <strong class="rsv-money">{{ formatMoney(rowTotalCents(row), rowCurrency(row)) }}</strong>
                    <small class="rsv-sub">{{ t('hotel.reservations.guests', { adults: row.adults ?? 1, children: row.children ?? 0 }) }}</small>
                  </td>
                  <td>
                    <div class="rsv-states">
                      <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(row)}`">
                        <i class="rsv-dot" />
                        {{ bookingStatusLabel(row) }}
                      </span>
                      <span class="rsv-progress" :class="`rsv-progress--${progressKey(row)}`">
                        {{ progressLabel(row) }}
                      </span>
                    </div>
                  </td>
                  <td class="rsv-table__actions" @click.stop>
                    <div class="rsv-row__actions">
                      <button
                        v-if="canEdit(row)"
                        type="button"
                        class="row-action row-action--edit"
                        :title="t('common.edit')"
                        :aria-label="t('common.edit')"
                        @click="openEdit(row)"
                      >
                        <AppIcon name="edit" :size="15" />
                      </button>
                      <button
                        v-if="canEdit(row)"
                        type="button"
                        class="row-action row-action--danger"
                        :title="t('common.delete')"
                        :aria-label="t('common.delete')"
                        @click="remove(row)"
                      >
                        <AppIcon name="trash" :size="15" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="rsv-empty">
            <span class="rsv-empty__icon"><AppIcon name="calendar" :size="22" /></span>
            <strong>{{ t('hotel.reservations.empty') }}</strong>
            <p>{{ t('hotel.reservations.emptyHint') }}</p>
            <div class="rsv-empty__actions">
              <button v-if="activeFilterCount" type="button" class="btn-secondary" @click="clearFilters">
                {{ t('hotel.reservations.filters.clear') }}
              </button>
              <button type="button" class="btn-primary" @click="openCreate">
                <AppIcon name="plus" :size="15" />
                {{ t('hotel.reservations.createTitle') }}
              </button>
            </div>
          </div>
          <ListPager
            v-if="filteredReservations.length"
            :page="page"
            :last-page="lastPage"
            :total="total"
            :per-page="perPage"
            @change="setPage"
          />
        </template>
      </section>
    </div>

    <AppModal
      :open="formOpen"
      :title="formTitle"
      icon="calendar"
      size="xl"
      @close="closeForm"
    >
      <form class="rsv__form rsv__form--modal" @submit.prevent="save">
        <p class="rsv__intro-text">{{ t('hotel.reservations.intro') }}</p>
        <p v-if="error" class="rsv__error">{{ error }}</p>

        <section class="rsv__block">
          <h3><AppIcon name="customers" :size="15" /> {{ t('hotel.reservations.clientTitle') }}</h3>
          <p class="rsv__label">{{ t('hotel.reservations.clientRef') }}</p>
          <div class="rsv__modes">
            <label class="rsv__mode" :class="{ 'rsv__mode--on': form.client_mode === 'new' }">
              <input v-model="form.client_mode" type="radio" value="new">
              <AppIcon name="account" :size="13" />
              <span>{{ t('hotel.reservations.newClient') }}</span>
            </label>
            <label class="rsv__mode" :class="{ 'rsv__mode--on': form.client_mode === 'existing' }">
              <input v-model="form.client_mode" type="radio" value="existing">
              <AppIcon name="customers" :size="13" />
              <span>{{ t('hotel.reservations.existingClient') }}</span>
            </label>
          </div>
          <p class="rsv__hint">
            {{ t('hotel.reservations.clientHint') }}
            <RouterLink to="/admin/customers" class="rsv__link">{{ t('hotel.reservations.clientsLink') }}</RouterLink>
          </p>

          <div v-if="form.client_mode === 'existing'" class="rsv__pick">
            <FieldLabel icon="customers">{{ t('hotel.reservations.searchClient') }}</FieldLabel>
            <input
              v-model="customerSearch"
              class="field"
              :placeholder="t('hotel.reservations.searchClientPh')"
            >
            <div v-if="selectedCustomer" class="rsv__picked">
              <strong>{{ selectedCustomer.name }}</strong>
              <small>{{ selectedCustomer.email || selectedCustomer.phone || '—' }}</small>
            </div>
            <div v-else class="rsv__customer-list">
              <button
                v-for="c in filteredCustomers"
                :key="c.id"
                type="button"
                class="rsv__customer"
                @click="pickCustomer(c)"
              >
                <strong>{{ c.name }}</strong>
                <small>{{ c.email || c.phone || '—' }}</small>
              </button>
              <p v-if="!filteredCustomers.length" class="rsv__muted">{{ t('hotel.reservations.noCustomers') }}</p>
            </div>
          </div>

          <div class="rsv__grid">
            <div class="rsv__span">
              <FieldLabel icon="account">{{ t('hotel.reservations.guestName') }} *</FieldLabel>
              <input
                v-model="form.guest_name"
                class="field"
                required
                :readonly="form.client_mode === 'existing' && !!form.customer_id"
                :placeholder="t('hotel.reservations.guestNamePh')"
              >
            </div>
            <div>
              <FieldLabel icon="mail">{{ t('hotel.reservations.email') }}</FieldLabel>
              <input
                v-model="form.guest_email"
                class="field"
                type="email"
                :placeholder="t('hotel.reservations.emailPh')"
              >
            </div>
            <div>
              <FieldLabel icon="phone">{{ t('hotel.reservations.phone') }}</FieldLabel>
              <input
                v-model="form.guest_phone"
                class="field"
                :placeholder="t('hotel.reservations.phonePh')"
              >
            </div>
          </div>
        </section>

        <section class="rsv__block">
          <h3><AppIcon name="bed" :size="15" /> {{ t('hotel.reservations.stayTitle') }}</h3>
          <p class="rsv__label">{{ t('hotel.reservations.spaceTitle') }}</p>
          <div class="rsv__spaces">
            <label
              v-for="kind in spaceKinds"
              :key="kind.id"
              class="rsv__space"
              :class="{ 'rsv__space--on': form.space_kind === kind.id }"
            >
              <input v-model="form.space_kind" type="radio" :value="kind.id">
              <span class="rsv__space-icon"><AppIcon :name="kind.icon" :size="16" /></span>
              <strong>{{ t(kind.titleKey) }}</strong>
              <span>{{ t(kind.hintKey) }}</span>
            </label>
          </div>
          <p class="rsv__hint">{{ t('hotel.reservations.roomAtCheckin') }}</p>

          <div class="rsv__grid">
            <div class="rsv__span">
              <FieldLabel icon="catalog">{{ t('hotel.reservations.roomType') }} *</FieldLabel>
              <select v-model="form.type_id" class="field" required>
                <option disabled value="">{{ t('hotel.reservations.chooseType') }}</option>
                <option v-for="item in typeOptions" :key="item.id" :value="item.id">
                  {{ typePriceLabel(item) }}
                </option>
              </select>
            </div>
            <div>
              <FieldLabel icon="calendar">{{ t('hotel.reservations.arriveOn') }} *</FieldLabel>
              <input v-model="form.arrive_on" class="field" type="date" required>
              <p class="rsv__hint">{{ t('hotel.settings.checkIn') }} · {{ hotelSettings.check_in_time }}</p>
            </div>
            <div>
              <FieldLabel icon="calendar">{{ t('hotel.reservations.departOn') }} *</FieldLabel>
              <input v-model="form.depart_on" class="field" type="date" required>
              <p class="rsv__hint">{{ t('hotel.settings.checkOut') }} · {{ hotelSettings.check_out_time }}</p>
            </div>
            <div>
              <FieldLabel icon="account">{{ t('hotel.reservations.adults') }}</FieldLabel>
              <input v-model="form.adults" class="field" type="number" min="1">
            </div>
            <div>
              <FieldLabel icon="customers">{{ t('hotel.reservations.children') }}</FieldLabel>
              <input v-model="form.children" class="field" type="number" min="0">
            </div>
            <div class="rsv__span">
              <FieldLabel icon="coins">{{ t('hotel.reservations.deposit') }}</FieldLabel>
              <div class="rsv__money">
                <span>$</span>
                <input v-model="form.deposit" class="field" inputmode="decimal" :placeholder="t('hotel.reservations.depositPh')">
              </div>
            </div>
          </div>
        </section>

        <section class="rsv__block">
          <h3><AppIcon name="layers" :size="15" /> {{ t('hotel.reservations.channelTitle') }}</h3>
          <div class="rsv__grid">
            <div>
              <FieldLabel icon="layers">{{ t('hotel.reservations.channelField') }}</FieldLabel>
              <select v-model="form.channel" class="field">
                <option v-for="ch in channels" :key="ch" :value="ch">{{ channelLabel(ch) }}</option>
              </select>
            </div>
            <div>
              <FieldLabel icon="check">{{ t('hotel.reservations.statusAuto') }}</FieldLabel>
              <div class="rsv__status-pill">{{ statusLabel('confirmed') }}</div>
            </div>
          </div>
        </section>

        <section class="rsv__block">
          <h3><AppIcon name="sparkles" :size="15" /> {{ t('hotel.reservations.requestsTitle') }}</h3>
          <FieldLabel icon="sparkles">{{ t('hotel.reservations.specialRequests') }}</FieldLabel>
          <textarea
            v-model="form.special_requests"
            class="field"
            rows="3"
            :placeholder="t('hotel.reservations.specialRequestsPh')"
          />
        </section>

        <div class="rsv__footer">
          <div class="rsv__estimate">
            <small>{{ t('hotel.reservations.estimate') }}</small>
            <strong>{{ formatMoney(formEstimateCents, rowCurrency()) }}</strong>
            <span>{{ formNights }} {{ t('hotel.reservations.nights') }} · {{ t('hotel.reservations.estimateHint') }}</span>
          </div>
          <div class="rsv__actions">
            <button type="button" class="btn-secondary" @click="closeForm"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
            <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
          </div>
        </div>
      </form>
    </AppModal>
    <AppModal
      :open="detailOpen"
      :title="t('hotel.reservations.detail.title')"
      icon="calendar"
      size="xl"
      @close="closeDetail"
    >
      <div v-if="detailRow" class="rd">
        <header class="rd-hero">
          <div class="rd-hero__who">
            <span class="rsv-avatar rsv-avatar--lg" :class="`rsv-avatar--${avatarTone(detailRow.guest_name)}`">{{ initials(detailRow.guest_name) }}</span>
            <div>
              <span class="rd-hero__eyebrow">{{ spaceLabel(detailRow.space_kind) }} · {{ channelLabel(detailRow.channel) }}</span>
              <h3>{{ detailRow.guest_name || '—' }}</h3>
              <p class="rd-hero__code">
                <strong>{{ bookingCode(detailRow) }}</strong>
                <span>{{ reservationNo(detailRow) }}</span>
              </p>
              <div class="rd-hero__pills">
                <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(detailRow)}`"><i class="rsv-dot" />{{ bookingStatusLabel(detailRow) }}</span>
                <span class="rsv-progress" :class="`rsv-progress--${progressKey(detailRow)}`">{{ progressLabel(detailRow) }}</span>
              </div>
            </div>
          </div>
          <div class="rd-hero__total">
            <small>{{ t('hotel.reservations.cols.total') }}</small>
            <strong>{{ formatMoney(rowTotalCents(detailRow), rowCurrency(detailRow)) }}</strong>
            <span>{{ nightsOf(detailRow) }} {{ t('hotel.reservations.nights') }} · {{ t('hotel.reservations.guests', { adults: detailRow.adults ?? 1, children: detailRow.children ?? 0 }) }}</span>
          </div>
        </header>

        <div class="rd-actions">
          <button type="button" class="btn-secondary" @click="notifyGuest(detailRow)">
            <AppIcon name="mail" :size="15" />
            {{ t('hotel.reservations.detail.notify') }}
          </button>
          <button
            v-if="canEdit(detailRow)"
            type="button"
            class="btn-secondary"
            @click="editFromDetail"
          >
            <AppIcon name="edit" :size="15" />
            {{ t('common.edit') }}
          </button>
          <button
            v-if="canOpenStay(detailRow)"
            type="button"
            class="btn-primary"
            @click="openStay(detailRow)"
          >
            <AppIcon name="eye" :size="15" />
            {{ t('hotel.reservations.detail.openStay') }}
          </button>
        </div>

        <section class="rd-timeline" :aria-label="t('hotel.reservations.detail.dates')">
          <div class="rd-timeline__end">
            <small>{{ t('hotel.reservations.arriveOn') }}</small>
            <strong>{{ dayParts(detailRow.arrive_on)?.long || '—' }}</strong>
            <span><AppIcon name="clock" :size="12" /> {{ t('hotel.settings.checkIn') }} · {{ hotelSettings.check_in_time }}</span>
          </div>
          <div class="rd-timeline__bridge">
            <em>{{ nightsOf(detailRow) }} {{ t('hotel.reservations.nights') }}</em>
          </div>
          <div class="rd-timeline__end rd-timeline__end--out">
            <small>{{ t('hotel.reservations.departOn') }}</small>
            <strong>{{ dayParts(detailRow.depart_on)?.long || '—' }}</strong>
            <span><AppIcon name="clock" :size="12" /> {{ t('hotel.settings.checkOut') }} · {{ hotelSettings.check_out_time }}</span>
          </div>
        </section>

        <div class="rd-grid">
          <section class="rd-card">
            <h4><AppIcon name="bed" :size="15" /> {{ t('hotel.reservations.detail.stayDetails') }}</h4>
            <dl class="rd-kv">
              <div><dt>{{ t('hotel.reservations.roomType') }}</dt><dd>{{ detailRow.type_name || '—' }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.source') }}</dt><dd>{{ channelLabel(detailRow.channel) }}</dd></div>
              <div><dt>{{ t('hotel.reservations.adults') }}</dt><dd>{{ detailRow.adults ?? 1 }}</dd></div>
              <div><dt>{{ t('hotel.reservations.children') }}</dt><dd>{{ detailRow.children ?? 0 }}</dd></div>
              <div class="rd-kv__wide">
                <dt>{{ t('hotel.reservations.detail.assignedRoom') }}</dt>
                <dd v-if="detailRow.room_number">#{{ detailRow.room_number }}</dd>
                <dd v-else class="rd-kv__muted">{{ t('hotel.reservations.roomAtCheckin') }}</dd>
              </div>
            </dl>
          </section>

          <section class="rd-card">
            <h4><AppIcon name="coins" :size="15" /> {{ t('hotel.reservations.detail.amounts') }}</h4>
            <dl class="rd-amounts">
              <div><dt>{{ t('hotel.reservations.cols.total') }}</dt><dd>{{ formatMoney(rowTotalCents(detailRow), rowCurrency(detailRow)) }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.depositRequired') }}</dt><dd>{{ formatMoney(Number(detailRow.deposit_cents || 0), rowCurrency(detailRow)) }}</dd></div>
              <div><dt>{{ t('hotel.reservations.detail.collected') }}</dt><dd class="rd-amounts__ok">{{ formatMoney(Number(detailRow.deposit_collected_cents || 0), rowCurrency(detailRow)) }}</dd></div>
              <div class="rd-amounts__total"><dt>{{ t('hotel.reservations.detail.balance') }}</dt><dd>{{ formatMoney(balanceCents(detailRow), rowCurrency(detailRow)) }}</dd></div>
            </dl>
          </section>

          <section class="rd-card">
            <h4><AppIcon name="account" :size="15" /> {{ t('hotel.reservations.detail.contact') }}</h4>
            <ul class="rd-contact">
              <li>
                <AppIcon name="mail" :size="14" />
                <a v-if="detailRow.guest_email" :href="`mailto:${detailRow.guest_email}`">{{ detailRow.guest_email }}</a>
                <span v-else>—</span>
              </li>
              <li>
                <AppIcon name="phone" :size="14" />
                <a v-if="detailRow.guest_phone" :href="`tel:${detailRow.guest_phone}`">{{ detailRow.guest_phone }}</a>
                <span v-else>—</span>
              </li>
            </ul>
            <div v-if="detailRow.special_requests" class="rd-requests">
              <small>{{ t('hotel.reservations.specialRequests') }}</small>
              <p>{{ detailRow.special_requests }}</p>
            </div>
          </section>
        </div>

        <p class="rd-note"><AppIcon name="check" :size="14" /> {{ t('hotel.reservations.detail.statusLockedNote') }}</p>

        <section class="rd-card">
          <h4><AppIcon name="calendar" :size="15" /> {{ t('hotel.reservations.detail.historyTitle') }} <em>{{ detailHistory.length }}</em></h4>
          <div class="rd-table-wrap">
            <table class="rsv-table rd-table">
              <thead>
                <tr>
                  <th>{{ t('hotel.reservations.cols.reference') }}</th>
                  <th>{{ t('hotel.reservations.detail.colType') }}</th>
                  <th>{{ t('hotel.rooms.room') }}</th>
                  <th>{{ t('hotel.reservations.cols.stay') }}</th>
                  <th>{{ t('hotel.stays.detail.guests') }}</th>
                  <th>{{ t('hotel.reservations.cols.status') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in detailHistory" :key="item.id" :class="{ 'rd-table__current': item.id === detailRow.id }">
                  <td class="rsv-row__ref">
                    <strong>{{ bookingCode(item) }}</strong>
                    <small>{{ reservationNo(item) }}</small>
                  </td>
                  <td>
                    <div class="rd-type">
                      <span class="rd-thumb">
                        <img v-if="typeCover(item)" :src="typeCover(item)" :alt="t('hotel.reservations.detail.colImage')">
                        <AppIcon v-else name="bed" :size="14" />
                      </span>
                      {{ item.type_name || '—' }}
                    </div>
                  </td>
                  <td>{{ item.room_number ? `#${item.room_number}` : '—' }}</td>
                  <td class="rd-table__dates">{{ dayOf(item.arrive_on) || '—' }} → {{ dayOf(item.depart_on) || '—' }}</td>
                  <td>{{ Number(item.adults || 0) + Number(item.children || 0) }}</td>
                  <td>
                    <div class="rsv-states">
                      <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(item)}`"><i class="rsv-dot" />{{ bookingStatusLabel(item) }}</span>
                      <span class="rsv-progress" :class="`rsv-progress--${progressKey(item)}`">{{ progressLabel(item) }}</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AppModal>

  </HotelChrome>
</template>

<style scoped>
.rsv {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  padding-bottom: 1.25rem;
}

/* ── KPIs ─────────────────────────────────────────── */
.rsv-kpis {
  display: grid;
  gap: 0.75rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}
@media (min-width: 720px) {
  .rsv-kpis { grid-template-columns: repeat(4, minmax(0, 1fr)); }
}
@media (min-width: 1200px) {
  .rsv-kpis { grid-template-columns: repeat(4, minmax(0, 1fr)) minmax(0, 1.35fr); }
}
.rsv-kpi {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-width: 0;
  padding: 0.75rem 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 0.9rem;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  text-align: left;
  font: inherit;
  color: inherit;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.rsv-kpi:not(.rsv-kpi--static):hover {
  border-color: var(--color-border-strong);
  box-shadow: var(--shadow-md);
  transform: translateY(-1px);
}
.rsv-kpi:focus-visible { outline: none; box-shadow: var(--shadow-glow); }
.rsv-kpi--static { cursor: default; }
.rsv-kpi--on {
  border-color: var(--color-accent);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-accent) 14%, transparent);
}
.rsv-kpi__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.35rem;
  height: 2.35rem;
  flex-shrink: 0;
  border-radius: 0.7rem;
  background: var(--color-table-header);
  color: var(--color-text-secondary);
}
.rsv-kpi__icon--in { background: var(--color-success-bg); color: var(--color-success); }
.rsv-kpi__icon--out { background: var(--color-warning-bg); color: var(--color-warning); }
.rsv-kpi__icon--house { background: var(--color-info-bg); color: var(--color-info); }
.rsv-kpi__icon--next { background: color-mix(in srgb, var(--color-accent) 14%, transparent); color: var(--color-accent); }
.rsv-kpi__body {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}
.rsv-kpi__body small {
  font-size: 0.74rem;
  font-weight: 600;
  color: var(--color-text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rsv-kpi__body strong {
  font-family: var(--font-display);
  font-size: 1.45rem;
  line-height: 1.15;
  font-weight: 750;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rsv-kpi--feature {
  grid-column: 1 / -1;
  padding-block: 0.6rem;
  border-color: transparent;
  background: linear-gradient(135deg, var(--color-brand-600), var(--color-brand-800));
}
@media (min-width: 1200px) {
  .rsv-kpi--feature { grid-column: auto; padding-block: 0.75rem; }
}
.rsv-kpi--feature .rsv-kpi__icon { background: rgba(255, 255, 255, 0.12); color: var(--color-accent); }
.rsv-kpi--feature .rsv-kpi__body small { color: rgba(255, 255, 255, 0.72); }
.rsv-kpi--feature .rsv-kpi__body strong { color: #fff; font-size: 1.3rem; }

/* ── Panel / toolbar ─────────────────────────────── */
.rsv-panel {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-border);
  border-radius: 1rem;
  background: var(--color-surface);
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}
.rsv-panel__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem 1rem;
  padding: 1rem 1.15rem 0.85rem;
}
.rsv-panel__title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-right: auto;
}
.rsv-panel__title h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--color-text-primary);
}
.rsv-panel__count {
  min-width: 1.6rem;
  padding: 0.1rem 0.5rem;
  border-radius: 999px;
  background: var(--color-table-header);
  color: var(--color-text-secondary);
  font-size: 0.75rem;
  font-weight: 700;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.rsv-panel__new { flex-shrink: 0; }

.rsv-seg {
  display: inline-flex;
  gap: 0.2rem;
  padding: 0.2rem;
  border-radius: 0.7rem;
  background: var(--color-table-header);
}
.rsv-seg__btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border: 0;
  border-radius: 0.55rem;
  padding: 0.38rem 0.8rem;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 0.8rem;
  font-weight: 650;
  cursor: pointer;
}
.rsv-seg__btn em {
  font-style: normal;
  font-size: 0.7rem;
  font-weight: 700;
  opacity: 0.75;
  font-variant-numeric: tabular-nums;
}
.rsv-seg__btn--on {
  background: var(--color-surface);
  color: var(--color-text-primary);
  box-shadow: var(--shadow-sm);
}

.rsv-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem;
  padding: 0.75rem 1.15rem;
  border-top: 1px solid var(--color-border);
  background: var(--color-table-row-hover);
}
.rsv-search {
  position: relative;
  display: block;
  flex: 1 1 16rem;
  min-width: 12rem;
  max-width: 26rem;
}
.rsv-search__icon {
  position: absolute;
  top: 50%;
  left: 0.8rem;
  z-index: 1;
  transform: translateY(-50%);
  color: var(--color-text-muted);
  pointer-events: none;
}
.rsv-search .rsv-search__input {
  width: 100%;
  padding-left: 2.3rem !important;
  padding-right: 2.2rem !important;
}
.rsv-search__input::-webkit-search-cancel-button { display: none; }
.rsv-search__clear {
  position: absolute;
  top: 50%;
  right: 0.6rem;
  z-index: 1;
  display: inline-flex;
  transform: translateY(-50%);
  border: 0;
  padding: 0.2rem;
  border-radius: 999px;
  background: var(--color-table-header);
  color: var(--color-text-muted);
  cursor: pointer;
}

.rsv-status {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}
.rsv-status__btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: var(--control-md, 40px);
  padding: 0 0.8rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.rsv-status__btn:hover { border-color: var(--color-border-strong); }
.rsv-status__btn em {
  font-style: normal;
  min-width: 1.3rem;
  padding: 0 0.35rem;
  border-radius: 999px;
  background: var(--color-table-header);
  font-size: 0.68rem;
  font-weight: 700;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.rsv-status__btn--on {
  border-color: var(--color-brand-600);
  background: var(--color-brand-600);
  color: #fff;
}
.rsv-status__btn--on em { background: rgba(255, 255, 255, 0.18); color: #fff; }
.rsv-status__btn--pending { --dot: var(--color-warning); }
.rsv-status__btn--confirmed { --dot: var(--color-info); }
.rsv-status__btn--guaranteed { --dot: var(--color-success); }

.rsv-toolbar__end {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-left: auto;
}
.rsv-filter-btn,
.rsv-reset {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  height: var(--control-md, 40px);
  padding: 0 0.75rem;
  border-radius: 0.6rem;
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
}
.rsv-filter-btn {
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
  color: var(--color-text-secondary);
}
.rsv-filter-btn--on { border-color: var(--color-brand-500); color: var(--color-text-primary); }
.rsv-filter-btn em {
  font-style: normal;
  min-width: 1.15rem;
  height: 1.15rem;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--color-accent);
  color: #fff;
  font-size: 0.66rem;
  font-weight: 750;
}
.rsv-filter-btn__caret { transition: transform 0.2s ease; color: var(--color-text-muted); }
.rsv-filter-btn__caret--open { transform: rotate(180deg); }
.rsv-reset {
  border: 0;
  background: transparent;
  color: var(--color-danger);
}
.rsv-reset:hover { background: var(--color-danger-bg); }

.rsv-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0.75rem 1.25rem;
  padding: 0.85rem 1.15rem;
  border-top: 1px dashed var(--color-border);
  background: var(--color-table-row-hover);
}
.rsv-filters__presets { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.rsv-filters__range { display: flex; align-items: flex-end; gap: 0.5rem; }
.rsv-filters__range label { display: flex; flex-direction: column; gap: 0.25rem; }
.rsv-filters__range span {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
}
.rsv-filters__range .field { width: 10.5rem; }
.rsv-filters__arrow { margin-bottom: 0.65rem; color: var(--color-text-faint); }
.rsv-chip {
  height: 2rem;
  padding: 0 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
}
.rsv-chip--on {
  border-color: var(--color-accent);
  background: color-mix(in srgb, var(--color-accent) 14%, transparent);
  color: var(--color-text-primary);
}

/* ── Table ───────────────────────────────────────── */
.rsv-table-wrap { overflow-x: auto; border-top: 1px solid var(--color-border); }
.rsv-table {
  width: 100%;
  min-width: 52rem;
  border-collapse: separate;
  border-spacing: 0;
}
.rsv-table th,
.rsv-panel .rsv-table th {
  position: sticky;
  top: 0;
  padding: 0.65rem 0.75rem;
  background: var(--color-table-header);
  border-bottom: 1px solid var(--color-border);
  text-align: left;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted);
  white-space: nowrap;
}
.rsv-table td,
.rsv-panel .rsv-table td {
  padding: 0.8rem 0.75rem;
  border-bottom: 1px solid var(--color-border);
  vertical-align: middle;
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}
.rsv-table tbody tr:last-child td { border-bottom: 0; }
.rsv-table__num { text-align: right !important; }
.rsv-table__actions { width: 1%; }
.rsv-row { cursor: pointer; transition: background 0.12s ease; }
.rsv-row:hover td,
.rsv-row:focus-visible td { background: var(--color-table-row-hover); }
.rsv-row:focus-visible { outline: none; }
.rsv-row:focus-visible td:first-child { box-shadow: inset 3px 0 0 var(--color-accent); }

.rsv-row__ref strong {
  display: block;
  font-family: var(--font-mono);
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--color-text-primary);
  letter-spacing: 0.01em;
  white-space: nowrap;
}
.rsv-row__ref small {
  display: block;
  margin-top: 0.15rem;
  font-size: 0.72rem;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.rsv-client { display: flex; align-items: center; gap: 0.6rem; min-width: 8.5rem; }
.rsv-client strong {
  display: block;
  font-size: 0.86rem;
  font-weight: 650;
  color: var(--color-text-primary);
}
.rsv-client small { display: block; margin-top: 0.1rem; font-size: 0.74rem; color: var(--color-text-muted); }
.rsv-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.2rem;
  height: 2.2rem;
  flex-shrink: 0;
  border-radius: 0.7rem;
  font-size: 0.74rem;
  font-weight: 750;
  letter-spacing: 0.02em;
}
.rsv-avatar--lg { width: 3.4rem; height: 3.4rem; border-radius: 1rem; font-size: 1.05rem; }
.rsv-avatar--0 { background: light-dark(#e8f1f7, rgba(47, 111, 154, 0.3)); color: light-dark(#2f6f9a, #a9cbe3); }
.rsv-avatar--1 { background: light-dark(#e8f6ef, rgba(15, 122, 77, 0.3)); color: light-dark(#0f7a4d, #9fd8bd); }
.rsv-avatar--2 { background: light-dark(#fbf3e4, rgba(184, 110, 9, 0.3)); color: light-dark(#b86e09, #ecc48a); }
.rsv-avatar--3 { background: light-dark(#f3ecfb, rgba(124, 77, 186, 0.3)); color: light-dark(#7c4dba, #cdb5ee); }
.rsv-avatar--4 { background: light-dark(#fbedec, rgba(194, 65, 58, 0.3)); color: light-dark(#c2413a, #eeb0ac); }
.rsv-avatar--5 { background: light-dark(#e6f5f6, rgba(14, 124, 134, 0.3)); color: light-dark(#0e7c86, #9fd9de); }

.rsv-lodging strong { display: block; font-size: 0.85rem; font-weight: 650; color: var(--color-text-primary); }
.rsv-lodging small { display: flex; align-items: center; gap: 0.35rem; margin-top: 0.25rem; }
.rsv-tag {
  padding: 0.08rem 0.45rem;
  border-radius: 0.35rem;
  background: var(--color-table-header);
  color: var(--color-text-muted);
  font-size: 0.68rem;
  font-weight: 650;
  white-space: nowrap;
}
.rsv-room {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.rsv-stay { display: flex; align-items: center; gap: 0.15rem; }
.rsv-day {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 2.4rem;
  padding: 0.25rem 0;
  border: 1px solid var(--color-border);
  border-radius: 0.55rem;
  background: var(--color-surface);
  line-height: 1;
}
.rsv-day b {
  font-family: var(--font-display);
  font-size: 0.98rem;
  font-weight: 750;
  color: var(--color-text-primary);
}
.rsv-day small {
  margin-top: 0.15rem;
  font-size: 0.62rem;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.rsv-stay__bridge {
  position: relative;
  display: flex;
  justify-content: center;
  min-width: 3.8rem;
  padding: 0 0.3rem;
}
.rsv-stay__bridge::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  border-top: 1.5px dashed var(--color-border-strong);
}
.rsv-stay__bridge em {
  position: relative;
  padding: 0.05rem 0.45rem;
  border-radius: 999px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  font-style: normal;
  font-size: 0.68rem;
  font-weight: 650;
  color: var(--color-text-secondary);
  white-space: nowrap;
}
.rsv-row:hover .rsv-stay__bridge em,
.rsv-row:hover .rsv-day { background: var(--color-surface); }

.rsv-money {
  display: block;
  font-size: 0.88rem;
  font-weight: 700;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.rsv-sub { display: block; margin-top: 0.15rem; font-size: 0.72rem; color: var(--color-text-muted); white-space: nowrap; }

.rsv-states { display: flex; flex-direction: column; align-items: flex-start; gap: 0.3rem; }
.rsv-dot {
  display: inline-block;
  width: 0.45rem;
  height: 0.45rem;
  border-radius: 999px;
  background: var(--dot, currentColor);
  flex-shrink: 0;
}
.rsv-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 650;
  white-space: nowrap;
}
.rsv-pill--guaranteed { background: var(--color-success-bg); color: light-dark(#047857, #96c6b8); }
.rsv-pill--confirmed { background: var(--color-info-bg); color: light-dark(#1d4ed8, #a0b5ef); }
.rsv-pill--pending { background: var(--color-warning-bg); color: light-dark(#c2410c, #e5af99); }
.rsv-progress {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding-left: 0.2rem;
  font-size: 0.7rem;
  font-weight: 600;
  color: var(--color-text-muted);
  white-space: nowrap;
}
.rsv-progress::before {
  content: '';
  width: 0.35rem;
  height: 0.35rem;
  border-radius: 999px;
  border: 1.5px solid currentColor;
}
.rsv-progress--in_progress { color: var(--color-warning); }
.rsv-progress--in_progress::before { background: currentColor; }
.rsv-progress--done { color: var(--color-success); }
.rsv-progress--done::before { background: currentColor; }

.rsv-row__actions { display: flex; justify-content: flex-end; gap: 0.35rem; }
.rsv-row__actions .row-action { width: var(--control-sm, 32px); padding: 0; }

.rsv-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  padding: 3rem 1.5rem 3.25rem;
  border-top: 1px solid var(--color-border);
  text-align: center;
}
.rsv-empty__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 3.25rem;
  height: 3.25rem;
  margin-bottom: 0.4rem;
  border-radius: 1rem;
  background: color-mix(in srgb, var(--color-accent) 14%, transparent);
  color: var(--color-accent);
}
.rsv-empty strong { font-size: 0.95rem; color: var(--color-text-primary); }
.rsv-empty p { margin: 0; font-size: 0.84rem; color: var(--color-text-muted); }
.rsv-empty__actions { display: flex; flex-wrap: wrap; justify-content: center; gap: 0.5rem; margin-top: 0.9rem; }

.rsv-panel :deep(.list-pager) { padding: 0.75rem 1.15rem; border-top: 1px solid var(--color-border); }

/* Cards on narrow screens */
@media (max-width: 760px) {
  .rsv-panel__head { padding: 0.9rem; }
  .rsv-toolbar, .rsv-filters { padding: 0.75rem 0.9rem; }
  .rsv-search { max-width: none; flex-basis: 100%; }
  .rsv-toolbar__end { margin-left: 0; }
  .rsv-panel__new { width: 100%; justify-content: center; }
  .rsv-table { min-width: 0; }
  .rsv-table thead { display: none; }
  .rsv-table, .rsv-table tbody, .rsv-table tr, .rsv-table td { display: block; }
  .rsv-table tbody { display: flex; flex-direction: column; gap: 0.6rem; padding: 0.75rem; }
  .rsv-row {
    display: grid !important;
    grid-template-columns: 1fr auto;
    gap: 0.55rem 0.75rem;
    padding: 0.85rem;
    border: 1px solid var(--color-border);
    border-radius: 0.85rem;
  }
  .rsv-panel .rsv-table td { padding: 0; border: 0 !important; }
  .rsv-row:hover td { background: transparent; }
  .rsv-row td:nth-child(1) { order: 1; }
  .rsv-row td:nth-child(6) { order: 2; justify-self: end; }
  .rsv-row td:nth-child(2) { order: 3; grid-column: 1 / -1; }
  .rsv-row td:nth-child(3) { order: 4; }
  .rsv-row td:nth-child(5) { order: 5; }
  .rsv-row td:nth-child(4) { order: 6; }
  .rsv-row td:nth-child(7) { order: 7; align-self: end; }
  .rsv-states { align-items: flex-end; }
}

/* ── Detail modal ────────────────────────────────── */
.rd { display: flex; flex-direction: column; gap: 1rem; }
.rd-hero {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.15rem 1.25rem;
  border: 1px solid var(--color-border);
  border-radius: 1rem;
  background:
    radial-gradient(circle at 100% 0%, color-mix(in srgb, var(--color-accent) 14%, transparent), transparent 55%),
    var(--color-table-row-hover);
}
.rd-hero__who { display: flex; gap: 0.95rem; align-items: flex-start; min-width: 0; }
.rd-hero__eyebrow {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted);
}
.rd-hero h3 {
  margin: 0.15rem 0 0;
  font-family: var(--font-display);
  font-size: 1.3rem;
  font-weight: 750;
  color: var(--color-text-primary);
}
.rd-hero__code { display: flex; gap: 0.5rem; align-items: baseline; margin: 0.2rem 0 0; }
.rd-hero__code strong { font-family: var(--font-mono); font-size: 0.85rem; color: var(--color-text-secondary); }
.rd-hero__code span { font-size: 0.75rem; color: var(--color-text-muted); }
.rd-hero__pills { display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; margin-top: 0.6rem; }
.rd-hero__total {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  justify-content: center;
  gap: 0.15rem;
  text-align: right;
}
.rd-hero__total small {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted);
}
.rd-hero__total strong {
  font-family: var(--font-display);
  font-size: 1.6rem;
  font-weight: 750;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
}
.rd-hero__total span { font-size: 0.78rem; color: var(--color-text-muted); }

.rd-actions { display: flex; flex-wrap: wrap; gap: 0.5rem; }

.rd-timeline {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 0.75rem;
}
.rd-timeline__end {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.85rem 1rem;
  border: 1px solid var(--color-border);
  border-left: 3px solid var(--color-success);
  border-radius: 0.8rem;
  background: var(--color-surface);
}
.rd-timeline__end--out { border-left-color: var(--color-warning); }
.rd-timeline__end small {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
}
.rd-timeline__end strong { font-size: 0.92rem; color: var(--color-text-primary); }
.rd-timeline__end strong::first-letter { text-transform: uppercase; }
.rd-timeline__end span { display: inline-flex; align-items: center; gap: 0.3rem; font-size: 0.75rem; color: var(--color-text-muted); }
.rd-timeline__bridge { position: relative; display: flex; justify-content: center; min-width: 5.5rem; }
.rd-timeline__bridge::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 0;
  right: 0;
  border-top: 2px dashed var(--color-border-strong);
}
.rd-timeline__bridge em {
  position: relative;
  padding: 0.25rem 0.7rem;
  border-radius: 999px;
  background: var(--color-brand-600);
  color: #fff;
  font-style: normal;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}
@media (max-width: 640px) {
  .rd-timeline { grid-template-columns: 1fr; }
  .rd-timeline__bridge { min-height: 1.75rem; }
  .rd-timeline__bridge::before { top: 0; bottom: 0; left: 50%; right: auto; border-top: 0; border-left: 2px dashed var(--color-border-strong); }
  .rd-hero__total { align-items: flex-start; text-align: left; }
}

.rd-grid {
  display: grid;
  gap: 0.85rem;
  grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
}
.rd-card {
  padding: 1rem 1.05rem;
  border: 1px solid var(--color-border);
  border-radius: 0.9rem;
  background: var(--color-surface);
}
.rd-card h4 {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin: 0 0 0.8rem;
  font-size: 0.88rem;
  font-weight: 700;
  color: var(--color-text-primary);
}
.rd-card h4 :deep(svg) { color: var(--color-text-muted); }
.rd-card h4 em {
  font-style: normal;
  padding: 0.05rem 0.45rem;
  border-radius: 999px;
  background: var(--color-table-header);
  font-size: 0.7rem;
  color: var(--color-text-secondary);
}
.rd-kv { margin: 0; display: grid; gap: 0.7rem 1rem; grid-template-columns: 1fr 1fr; }
.rd-kv > div { display: flex; flex-direction: column; gap: 0.15rem; min-width: 0; }
.rd-kv dt { font-size: 0.72rem; font-weight: 600; color: var(--color-text-muted); }
.rd-kv dd { margin: 0; font-size: 0.86rem; font-weight: 650; color: var(--color-text-primary); }
.rd-kv dd.rd-kv__muted { font-size: 0.76rem; font-weight: 500; color: var(--color-text-muted); }
.rd-kv__wide { grid-column: 1 / -1; }

.rd-amounts { margin: 0; display: flex; flex-direction: column; }
.rd-amounts > div {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px dashed var(--color-border);
}
.rd-amounts dt { font-size: 0.8rem; color: var(--color-text-muted); }
.rd-amounts dd { margin: 0; font-size: 0.86rem; font-weight: 650; color: var(--color-text-primary); font-variant-numeric: tabular-nums; }
.rd-amounts__ok { color: var(--color-success) !important; }
.rd-amounts .rd-amounts__total { border-bottom: 0; padding-top: 0.6rem; }
.rd-amounts__total dt { font-weight: 700; color: var(--color-text-primary); }
.rd-amounts__total dd { font-size: 1rem; font-weight: 750; }

.rd-contact { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.55rem; }
.rd-contact li { display: flex; align-items: center; gap: 0.55rem; font-size: 0.85rem; color: var(--color-text-secondary); min-width: 0; }
.rd-contact li :deep(svg) { color: var(--color-text-muted); flex-shrink: 0; }
.rd-contact a { color: var(--color-ink-brand, var(--color-brand-600)); font-weight: 600; text-decoration: none; overflow-wrap: anywhere; }
.rd-contact a:hover { text-decoration: underline; }
.rd-requests {
  margin-top: 0.85rem;
  padding: 0.65rem 0.75rem;
  border-radius: 0.65rem;
  background: color-mix(in srgb, var(--color-accent) 14%, transparent);
}
.rd-requests small { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-text-muted); }
.rd-requests p { margin: 0.2rem 0 0; font-size: 0.84rem; color: var(--color-text-primary); line-height: 1.45; }

.rd-note {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin: 0;
  padding: 0.65rem 0.85rem;
  border-radius: 0.7rem;
  background: var(--color-info-bg);
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  line-height: 1.45;
}
.rd-note :deep(svg) { margin-top: 0.1rem; color: var(--color-info); flex-shrink: 0; }

.rd-table-wrap { overflow-x: auto; margin: 0 -1.05rem -1rem; border-top: 1px solid var(--color-border); }
.rd-table { min-width: 44rem; }
.rd-table td { font-size: 0.8rem; }
.rd-table__current td { background: color-mix(in srgb, var(--color-accent) 14%, transparent); }
.rd-table__dates { font-family: var(--font-mono); font-size: 0.74rem !important; white-space: nowrap; }
.rd-type { display: flex; align-items: center; gap: 0.55rem; }
.rd-thumb {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.6rem;
  height: 1.9rem;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 0.4rem;
  background: var(--color-table-header);
  color: var(--color-text-faint);
}
.rd-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }

/* ── Form modal ──────────────────────────────────── */
.rsv__form--modal { padding: 0.15rem 0 0.25rem; }
.rsv__intro-text {
  margin: 0 0 0.35rem;
  font-size: 0.875rem;
  color: var(--color-text-muted);
  line-height: 1.45;
}
.rsv__error {
  margin: 0.85rem 0 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: var(--color-danger-bg);
  color: light-dark(#b91c1c, #e2a0a0);
  font-size: 0.85rem;
}
.rsv__error--inline { margin: 0 1.15rem 0.85rem; }

.rsv__block {
  margin-top: 1rem;
  padding: 1rem 1.05rem;
  border: 1px solid var(--color-border);
  border-radius: 0.9rem;
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}
.rsv__block h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.92rem;
  color: var(--color-text-primary);
}
.rsv__block h3 :deep(svg) { color: var(--color-ink-brand, var(--color-brand-600)); }
.rsv__label {
  margin: 0;
  font-size: 0.74rem;
  font-weight: 700;
  color: var(--color-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.rsv__hint { margin: 0; font-size: 0.72rem; color: var(--color-text-faint); }
.rsv__link { color: var(--color-ink-brand, var(--color-brand-600)); font-weight: 600; text-decoration: none; }
.rsv__grid { display: grid; gap: 0.85rem 1rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rsv__grid { grid-template-columns: 1fr 1fr; }
  .rsv__span { grid-column: 1 / -1; }
}

.rsv__modes { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.rsv__mode {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border: 1px solid var(--color-border-strong);
  border-radius: 999px;
  padding: 0.35rem 0.75rem;
  font-size: 0.8rem;
  cursor: pointer;
  background: var(--color-surface);
}
.rsv__mode input { accent-color: var(--color-brand-600); }
.rsv__mode--on { border-color: var(--color-brand-500); background: var(--color-brand-50); }

.rsv__spaces { display: grid; gap: 0.55rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rsv__spaces { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.rsv__space {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  border: 1px solid var(--color-border-strong);
  border-radius: 0.75rem;
  padding: 0.75rem;
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.rsv__space input { position: absolute; opacity: 0; pointer-events: none; }
.rsv__space strong { font-size: 0.82rem; color: var(--color-text-primary); }
.rsv__space span { font-size: 0.72rem; color: var(--color-text-muted); line-height: 1.35; }
.rsv__space--on { border-color: var(--color-brand-500); background: var(--color-brand-50); box-shadow: inset 0 0 0 1px var(--color-brand-500); }
.rsv__space-icon {
  display: inline-flex;
  width: 1.75rem;
  height: 1.75rem;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.2rem;
  border-radius: 0.5rem;
  background: var(--color-table-header);
  color: var(--color-ink-brand, var(--color-brand-600));
}

.rsv__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.rsv__money span { font-weight: 700; color: var(--color-ink-brand, var(--color-brand-600)); }
.rsv__status-pill {
  display: inline-flex;
  align-items: center;
  min-height: 2.4rem;
  padding: 0.45rem 0.75rem;
  border-radius: 0.65rem;
  background: var(--color-success-bg);
  color: light-dark(#047857, #96c6b8);
  font-size: 0.85rem;
  font-weight: 650;
}

.rsv__pick { display: flex; flex-direction: column; gap: 0.45rem; }
.rsv__picked {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  padding: 0.65rem 0.75rem;
  border-radius: 0.7rem;
  background: var(--color-table-header);
  border: 1px solid var(--color-border);
}
.rsv__picked strong { font-size: 0.9rem; color: var(--color-text-primary); }
.rsv__picked small { color: var(--color-text-muted); }
.rsv__customer-list {
  max-height: 10rem;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: 0.7rem;
  display: flex;
  flex-direction: column;
}
.rsv__customer {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  text-align: left;
  padding: 0.55rem 0.7rem;
  border: 0;
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface);
  cursor: pointer;
}
.rsv__customer:hover { background: var(--color-table-row-hover); }
.rsv__customer strong { font-size: 0.84rem; color: var(--color-text-primary); }
.rsv__customer small { font-size: 0.72rem; color: var(--color-text-muted); }
.rsv__muted { margin: 0; padding: 1.2rem; text-align: center; color: var(--color-text-muted); font-size: 0.875rem; }

.rsv__footer {
  position: sticky;
  bottom: -1.5rem;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem 1rem;
  margin: 1.1rem 0 -1.5rem;
  padding: 0.85rem 0 1.5rem;
  border-top: 1px solid var(--color-border);
  background: var(--color-surface);
}
.rsv__estimate { display: flex; flex-direction: column; gap: 0.1rem; min-width: 0; }
.rsv__estimate small {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);
}
.rsv__estimate strong {
  font-family: var(--font-display);
  font-size: 1.2rem;
  font-weight: 750;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
}
.rsv__estimate span { font-size: 0.72rem; color: var(--color-text-faint); }
.rsv__actions { display: flex; justify-content: flex-end; gap: 0.5rem; }
</style>
