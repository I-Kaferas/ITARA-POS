<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRouter } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Customer } from '../../../types'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { computeStayTaxes, findHotelSettings, moneyFromSettingsCents } from '../../../utils/hotelSettings'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type SpaceKind = 'guest_room' | 'conference' | 'reception'
type ClientMode = 'new' | 'existing'
type Channel = 'direct' | 'phone' | 'walk_in' | 'booking_com' | 'expedia' | 'other'

const { t } = useI18n()
const router = useRouter()
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

const filteredReservations = computed(() => {
  const q = listSearch.value.trim().toLowerCase()
  const from = dateFrom.value
  const to = dateTo.value
  const today = todayIso()
  const next7 = addDaysIso(7)

  return reservations.value.filter((row) => {
    const history = isHistory(row)
    if (listScope.value === 'active' && history) return false
    if (listScope.value === 'history' && !history) return false

    if (statusFilter.value !== 'all' && reservationBucket(row) !== statusFilter.value) return false

    const arrive = String(row.arrive_on || '').slice(0, 10)
    if (datePreset.value === 'today' && arrive !== today) return false
    if (datePreset.value === 'arrivals_today' && arrive !== today) return false
    if (datePreset.value === 'next7' && (arrive < today || arrive > next7)) return false

    if (from && arrive < from) return false
    if (to && arrive > to) return false

    if (!q) return true
    const hay = `${row.guest_name || ''} ${row.guest_email || ''} ${row.stay_code || ''} ${row.reservation_no || ''} ${row.id || ''} ${row.guest_phone || ''} ${row.type_name || ''} ${row.room_number || ''}`.toLowerCase()
    return hay.includes(q)
  })
})

const activeFilterCount = computed(() => {
  let n = 0
  if (statusFilter.value !== 'all') n += 1
  if (datePreset.value !== 'all') n += 1
  if (dateFrom.value) n += 1
  if (dateTo.value) n += 1
  if (listSearch.value.trim()) n += 1
  return n
})

const scopeTabs = computed(() => ([
  { id: 'active' as const, label: t('hotel.reservations.filters.active') },
  { id: 'history' as const, label: t('hotel.reservations.filters.history') },
]))

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
})

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
  const currency = String(type.currency ?? 'USD')
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

function rowCurrency(row: Doc) {
  return String(row.type_currency || 'USD')
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

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>('/hospitality')).data.docs
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
  const ok = await confirmDialog({
    title: t('hotel.reservations.deleteTitle'),
    message: t('hotel.reservations.deleteConfirm', { name: row.guest_name }),
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
  } catch (err) {
    const message = extractApiErrorMessage(err)
    if (message.toLowerCase().includes('force=1') || message.toLowerCase().includes('pénalité') || message.toLowerCase().includes('penalty')) {
      const force = await confirmDialog({
        title: t('hotel.reservations.deleteTitle'),
        message: `${message}\n\n${t('hotel.settings.cancelForceHint')}`,
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
      return
    }
    error.value = message
  }
}
</script>

<template>
  <HotelChrome scroll-body>
    <div class="rsv">
      <div class="rsv__toolbar">
        <div class="rsv__toolbar-top">
          <input
            v-model="listSearch"
            class="field rsv__search"
            :placeholder="t('hotel.reservations.filters.searchPh')"
          >
          <div class="rsv__scope">
            <button
              v-for="tab in scopeTabs"
              :key="tab.id"
              type="button"
              class="rsv__scope-btn"
              :class="{ 'rsv__scope-btn--on': listScope === tab.id }"
              @click="listScope = tab.id"
            >
              {{ tab.label }}
            </button>
          </div>
          <button
            type="button"
            class="btn-secondary rsv__filters-toggle"
            :class="{ 'rsv__filters-toggle--on': filtersOpen }"
            :aria-expanded="filtersOpen"
            @click="filtersOpen = !filtersOpen"
          >
            <AppIcon name="layers" :size="13" />
            {{ filtersOpen ? t('filters.hide') : t('filters.show') }}
            <em v-if="activeFilterCount">{{ activeFilterCount }}</em>
            <AppIcon
              name="chevron-right"
              :size="12"
              class="rsv__filters-caret"
              :class="{ 'rsv__filters-caret--open': filtersOpen }"
            />
          </button>
          <span class="rsv__count">{{ t('hotel.reservations.listHint', { count: filteredReservations.length }) }}</span>
          <button type="button" class="btn-primary rsv__new" @click="openCreate">
            {{ t('hotel.reservations.createTitle') }}
          </button>
        </div>

        <div v-show="filtersOpen" class="rsv__filters">
          <div class="rsv__chips">
            <button
              v-for="item in statusFilters"
              :key="item.id"
              type="button"
              class="rsv__chip"
              :class="{ 'rsv__chip--on': statusFilter === item.id }"
              @click="statusFilter = item.id"
            >
              {{ item.label }}
            </button>
          </div>

          <div class="rsv__chips">
            <button
              v-for="item in datePresets"
              :key="item.id"
              type="button"
              class="rsv__chip"
              :class="{ 'rsv__chip--on': datePreset === item.id }"
              @click="setDatePreset(item.id)"
            >
              {{ item.label }}
            </button>
          </div>

          <div class="rsv__dates">
            <div>
              <FieldLabel icon="calendar">{{ t('hotel.reservations.filters.from') }}</FieldLabel>
              <input v-model="dateFrom" class="field" type="date" @change="datePreset = 'all'">
            </div>
            <div>
              <FieldLabel icon="calendar">{{ t('hotel.reservations.filters.to') }}</FieldLabel>
              <input v-model="dateTo" class="field" type="date" @change="datePreset = 'all'">
            </div>
            <button
              v-if="activeFilterCount"
              type="button"
              class="btn-secondary rsv__clear"
              @click="clearFilters"
            >
              {{ t('hotel.reservations.filters.clear') }}
            </button>
          </div>
        </div>
      </div>

      <div class="rsv__list">
        <div class="rsv__list-head">
          <div>
            <h3>
              <AppIcon name="calendar" :size="15" />
              {{ t('hotel.reservations.listTitle') }}
            </h3>
            <p>{{ t('hotel.reservations.listHint', { count: filteredReservations.length }) }}</p>
          </div>
        </div>

        <p v-if="error && !formOpen && !detailOpen" class="rsv__error rsv__error--inline">{{ error }}</p>
        <div v-if="loading" class="rsv__muted">{{ t('common.loading') }}</div>
        <div v-else class="rsv__table-wrap">
          <table class="ui-table rsv__table">
            <thead>
              <tr>
                <th>{{ t('hotel.reservations.cols.reference') }}</th>
                <th>{{ t('hotel.reservations.cols.client') }}</th>
                <th>{{ t('hotel.reservations.cols.category') }}</th>
                <th>{{ t('hotel.reservations.cols.typeSpace') }}</th>
                <th>{{ t('hotel.reservations.cols.duration') }}</th>
                <th>{{ t('hotel.reservations.cols.arrive') }}</th>
                <th>{{ t('hotel.reservations.cols.depart') }}</th>
                <th>{{ t('hotel.reservations.cols.total') }}</th>
                <th>{{ t('hotel.reservations.cols.status') }}</th>
                <th>{{ t('hotel.reservations.cols.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredReservations" :key="row.id">
                <td>
                  <div class="rsv__ref">
                    <strong>{{ bookingCode(row) }}</strong>
                    <small>{{ reservationNo(row) }}</small>
                  </div>
                </td>
                <td>
                  <div class="rsv__client">
                    <span class="rsv__avatar">{{ initials(row.guest_name) }}</span>
                    <div>
                      <strong>{{ row.guest_name || '—' }}</strong>
                      <small v-if="row.guest_email">{{ row.guest_email }}</small>
                    </div>
                  </div>
                </td>
                <td>{{ spaceLabel(row.space_kind) }}</td>
                <td>
                  <div class="rsv__type">
                    <strong>{{ row.type_name || '—' }}</strong>
                    <small v-if="row.room_number">#{{ row.room_number }}</small>
                    <small v-else>{{ t('hotel.reservations.roomAtCheckin') }}</small>
                  </div>
                </td>
                <td>{{ nightsOf(row) }} {{ t('hotel.reservations.nights') }}</td>
                <td>{{ String(row.arrive_on || '').slice(0, 10) || '—' }}</td>
                <td>{{ String(row.depart_on || '').slice(0, 10) || '—' }}</td>
                <td>
                  <strong>{{ formatMoney(rowTotalCents(row), rowCurrency(row)) }}</strong>
                </td>
                <td>
                  <div class="rsv__status-stack">
                    <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(row)}`">
                      {{ bookingStatusLabel(row) }}
                    </span>
                    <span class="rsv-pill" :class="`rsv-pill--${progressKey(row)}`">
                      {{ progressLabel(row) }}
                    </span>
                  </div>
                </td>
                <td class="rsv__row-actions">
                  <button type="button" class="rsv__detail-btn" @click="openDetail(row)">
                    {{ t('hotel.reservations.cols.detail') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!filteredReservations.length" class="rsv__empty">{{ t('hotel.reservations.empty') }}</p>
        </div>
      </div>
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

        <div class="rsv__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
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
        <header class="rd__hero">
          <div class="rd__hero-main">
            <span class="rd__eyebrow">{{ spaceLabel(detailRow.space_kind) }}</span>
            <h3>{{ bookingCode(detailRow) }}</h3>
            <p class="rd__guest">{{ detailRow.guest_name || '—' }}</p>
            <div class="rd__pills">
              <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(detailRow)}`">{{ bookingStatusLabel(detailRow) }}</span>
              <span class="rsv-pill" :class="`rsv-pill--${progressKey(detailRow)}`">{{ progressLabel(detailRow) }}</span>
            </div>
          </div>
          <div class="rd__hero-actions">
            <button type="button" class="btn-secondary" @click="notifyGuest(detailRow)">
              {{ t('hotel.reservations.detail.notify') }}
            </button>
            <button
              v-if="canOpenStay(detailRow)"
              type="button"
              class="btn-primary"
              @click="openStay(detailRow)"
            >
              {{ t('hotel.reservations.detail.openStay') }}
            </button>
            <button
              v-if="!['checked_in', 'checked_out'].includes(String(detailRow.status))"
              type="button"
              class="btn-secondary"
              @click="editFromDetail"
            >
              {{ t('common.edit') }}
            </button>
          </div>
        </header>

        <p class="rd__note">{{ t('hotel.reservations.detail.statusLockedNote') }}</p>

        <section class="rd__card">
          <h4>{{ t('hotel.reservations.detail.stayDetails') }}</h4>
          <dl class="rd__kv">
            <div><dt>{{ t('hotel.reservations.roomType') }}</dt><dd>{{ detailRow.type_name || '—' }}</dd></div>
            <div>
              <dt>{{ t('hotel.reservations.detail.assignedRoom') }}</dt>
              <dd>{{ detailRow.room_number ? `#${detailRow.room_number}` : t('hotel.reservations.roomAtCheckin') }}</dd>
            </div>
            <div><dt>{{ t('hotel.reservations.arriveOn') }}</dt><dd>{{ String(detailRow.arrive_on || '').slice(0, 10) || '—' }}</dd></div>
            <div><dt>{{ t('hotel.reservations.departOn') }}</dt><dd>{{ String(detailRow.depart_on || '').slice(0, 10) || '—' }}</dd></div>
            <div><dt>{{ t('hotel.reservations.detail.stayLength') }}</dt><dd>{{ nightsOf(detailRow) }} {{ t('hotel.reservations.nights') }}</dd></div>
            <div><dt>{{ t('hotel.reservations.adults') }}</dt><dd>{{ detailRow.adults ?? 1 }}</dd></div>
            <div><dt>{{ t('hotel.reservations.children') }}</dt><dd>{{ detailRow.children ?? 0 }}</dd></div>
            <div><dt>{{ t('hotel.stays.detail.source') }}</dt><dd>{{ channelLabel(detailRow.channel) }}</dd></div>
            <div><dt>{{ t('hotel.reservations.cols.total') }}</dt><dd>{{ formatMoney(rowTotalCents(detailRow), rowCurrency(detailRow)) }}</dd></div>
            <div>
              <dt>{{ t('hotel.stays.detail.depositRequired') }}</dt>
              <dd>{{ formatMoney(Number(detailRow.deposit_cents || 0), rowCurrency(detailRow)) }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.reservations.detail.collected') }}</dt>
              <dd>{{ formatMoney(Number(detailRow.deposit_collected_cents || 0), rowCurrency(detailRow)) }}</dd>
            </div>
          </dl>
        </section>

        <section class="rd__card">
          <h4>{{ t('hotel.reservations.detail.contact') }}</h4>
          <dl class="rd__kv">
            <div><dt>{{ t('hotel.reservations.email') }}</dt><dd>{{ detailRow.guest_email || '—' }}</dd></div>
            <div><dt>{{ t('hotel.reservations.phone') }}</dt><dd>{{ detailRow.guest_phone || '—' }}</dd></div>
            <div v-if="detailRow.special_requests" class="rd__span">
              <dt>{{ t('hotel.reservations.specialRequests') }}</dt>
              <dd>{{ detailRow.special_requests }}</dd>
            </div>
          </dl>
        </section>

        <section class="rd__card">
          <h4>{{ t('hotel.reservations.detail.historyTitle') }}</h4>
          <div class="rd__table-wrap">
            <table class="ui-table rd__table">
              <thead>
                <tr>
                  <th>{{ t('hotel.reservations.cols.reference') }}</th>
                  <th>{{ t('hotel.reservations.detail.colImage') }}</th>
                  <th>{{ t('hotel.reservations.detail.colType') }}</th>
                  <th>{{ t('hotel.rooms.room') }}</th>
                  <th>{{ t('hotel.reservations.arriveOn') }}</th>
                  <th>{{ t('hotel.reservations.departOn') }}</th>
                  <th>{{ t('hotel.stays.detail.guests') }}</th>
                  <th>{{ t('hotel.reservations.cols.status') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in detailHistory" :key="item.id">
                  <td>
                    <div class="rsv__ref">
                      <strong>{{ bookingCode(item) }}</strong>
                      <small>{{ reservationNo(item) }}</small>
                    </div>
                  </td>
                  <td>
                    <div class="rd__thumb">
                      <img v-if="typeCover(item)" :src="typeCover(item)" alt="">
                      <span v-else>{{ t('hotel.reservations.detail.noPhoto') }}</span>
                    </div>
                  </td>
                  <td>{{ item.type_name || '—' }}</td>
                  <td>{{ item.room_number ? `#${item.room_number}` : '—' }}</td>
                  <td>{{ String(item.arrive_on || '').slice(0, 10) || '—' }}</td>
                  <td>{{ String(item.depart_on || '').slice(0, 10) || '—' }}</td>
                  <td>{{ Number(item.adults || 0) + Number(item.children || 0) }}</td>
                  <td>
                    <div class="rsv__status-stack">
                      <span class="rsv-pill" :class="`rsv-pill--${bookingStatusKey(item)}`">{{ bookingStatusLabel(item) }}</span>
                      <span class="rsv-pill" :class="`rsv-pill--${progressKey(item)}`">{{ progressLabel(item) }}</span>
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
  gap: 0.75rem;
  margin-top: 0;
  width: 100%;
}

.rsv__toolbar {
  flex-shrink: 0;
  padding: 0.85rem 1rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  background: #fff;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.rsv__toolbar-top {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  align-items: center;
}

.rsv__search {
  flex: 1 1 14rem;
  min-width: 12rem;
}

.rsv__count {
  margin-left: auto;
  font-size: 0.8rem;
  color: #7b8d9a;
  font-weight: 650;
}

.rsv__new {
  flex-shrink: 0;
}

.rsv__list {
  padding: 0;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  background: #fff;
  display: flex;
  flex-direction: column;
}

.rsv__form--modal {
  padding: 0.15rem 0 0.25rem;
}

.rsv__intro-text {
  margin: 0 0 0.35rem;
  font-size: 0.875rem;
  color: #66727c;
  line-height: 1.45;
}

.rsv__list-head h3,
.rsv__block h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  color: #1c2830;
}

.rsv__error {
  margin: 0.85rem 0 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 0.85rem;
}
.rsv__error--inline {
  margin: 0 1.2rem 0.85rem;
}

.rsv__block { margin-top: 1.2rem; display: flex; flex-direction: column; gap: 0.7rem; }
.rsv__block h3 { font-size: 0.92rem; }
.rsv__block h3 :deep(svg) { color: var(--color-brand-600, #4a6d86); }
.rsv__label {
  margin: 0;
  font-size: 0.78rem;
  font-weight: 650;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.rsv__hint { margin: 0; font-size: 0.72rem; color: #94a3b8; }
.rsv__link { color: var(--color-brand-600, #4a6d86); font-weight: 600; text-decoration: none; }
.rsv__grid { display: grid; gap: 0.85rem 1rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rsv__grid { grid-template-columns: 1fr 1fr; }
  .rsv__span { grid-column: 1 / -1; }
}

.rsv__modes { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.rsv__mode {
  display: inline-flex; align-items: center; gap: 0.35rem;
  border: 1px solid #d7e2ea; border-radius: 999px; padding: 0.35rem 0.7rem;
  font-size: 0.8rem; cursor: pointer; background: #fff;
}
.rsv__mode input { accent-color: var(--color-brand-600); }
.rsv__mode--on { border-color: var(--color-brand-500); background: #f3f6f8; }

.rsv__spaces { display: grid; gap: 0.55rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .rsv__spaces { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.rsv__space {
  position: relative; display: flex; flex-direction: column; gap: 0.2rem;
  border: 1px solid #d7e2ea; border-radius: 0.75rem; padding: 0.7rem 0.75rem; cursor: pointer;
}
.rsv__space input { position: absolute; opacity: 0; pointer-events: none; }
.rsv__space strong { font-size: 0.82rem; color: #1c2830; }
.rsv__space span { font-size: 0.72rem; color: #7b8d9a; line-height: 1.35; }
.rsv__space--on { border-color: var(--color-brand-500); background: #f3f6f8; }
.rsv__space-icon {
  display: inline-flex; width: 1.6rem; height: 1.6rem; align-items: center; justify-content: center;
  border-radius: 0.4rem; background: #eef4f8; color: var(--color-brand-600, #4a6d86); margin-bottom: 0.15rem;
}

.rsv__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.rsv__money span { font-weight: 700; color: #3d5c73; }
.rsv__status-pill {
  display: inline-flex; align-items: center; min-height: 2.4rem;
  padding: 0.45rem 0.75rem; border-radius: 0.65rem;
  background: #ecfdf5; color: #047857; border: 1px solid #a7f3d0; font-size: 0.85rem; font-weight: 650;
}

.rsv__pick { display: flex; flex-direction: column; gap: 0.45rem; }
.rsv__picked {
  display: flex; flex-direction: column; gap: 0.15rem;
  padding: 0.65rem 0.75rem; border-radius: 0.7rem; background: #f3f6f8; border: 1px solid #d7e2ea;
}
.rsv__picked strong { font-size: 0.9rem; color: #1c2830; }
.rsv__picked small { color: #7b8d9a; }
.rsv__customer-list {
  max-height: 10rem; overflow: auto; border: 1px solid #e4e8ec; border-radius: 0.7rem;
  display: flex; flex-direction: column;
}
.rsv__customer {
  display: flex; flex-direction: column; gap: 0.1rem; text-align: left;
  padding: 0.55rem 0.7rem; border: 0; border-bottom: 1px solid #eef2f6; background: #fff; cursor: pointer;
}
.rsv__customer:hover { background: #f8fafc; }
.rsv__customer strong { font-size: 0.84rem; color: #1c2830; }
.rsv__customer small { font-size: 0.72rem; color: #7b8d9a; }

.rsv__actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.1rem; }

.rsv__filters-toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.8rem;
  padding: 0.35rem 0.7rem;
  flex-shrink: 0;
}
.rsv__filters-toggle--on {
  border-color: var(--color-brand-500, #4a6d86);
  background: #f3f6f8;
}
.rsv__filters-caret {
  transition: transform 0.15s ease;
  transform: rotate(90deg);
  color: #64748b;
}
.rsv__filters-caret--open {
  transform: rotate(-90deg);
}
.rsv__filters-toggle em {
  font-style: normal;
  font-weight: 750;
  min-width: 1.2rem;
  height: 1.2rem;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--color-brand-600, #4a6d86);
  color: #fff;
  font-size: 0.7rem;
}
.rsv__filters {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  flex-shrink: 0;
  padding-top: 0.15rem;
  border-top: 1px solid #eef2f6;
}
.rsv__scope {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.2rem;
  border-radius: 0.7rem;
  background: #eef3f7;
  width: fit-content;
  flex-shrink: 0;
}
.rsv__scope-btn {
  border: 0;
  background: transparent;
  border-radius: 0.55rem;
  padding: 0.35rem 0.75rem;
  font-size: 0.8rem;
  font-weight: 650;
  color: #64748b;
  cursor: pointer;
}
.rsv__scope-btn--on {
  background: #fff;
  color: #1c2830;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.rsv__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}
.rsv__chip {
  border: 1px solid #d7e2ea;
  border-radius: 999px;
  background: #fff;
  padding: 0.3rem 0.65rem;
  font-size: 0.78rem;
  color: #4b5d6b;
  cursor: pointer;
}
.rsv__chip--on {
  border-color: var(--color-brand-500, #4a6d86);
  background: #eef4f8;
  color: #1c2830;
  font-weight: 650;
}
.rsv__dates {
  display: grid;
  gap: 0.65rem;
  grid-template-columns: 1fr;
  align-items: end;
}
@media (min-width: 640px) {
  .rsv__dates { grid-template-columns: 1fr 1fr auto; max-width: 36rem; }
}
.rsv__clear { height: 2.4rem; }

.rsv__list-head {
  display: flex; justify-content: space-between; gap: 0.75rem; align-items: flex-start;
  padding: 1.15rem 1.2rem 0.85rem; flex-shrink: 0;
}
.rsv__list-head h3 { font-size: 1rem; }
.rsv__list-head h3 :deep(svg) { color: var(--color-brand-600, #4a6d86); }
.rsv__list-head p { margin: 0.25rem 0 0; font-size: 0.8rem; color: #7b8d9a; }

.rsv__table-wrap {
  overflow-x: auto;
  padding: 0 0.35rem 1.1rem;
}
.rsv__table {
  width: 100%;
  min-width: 64rem;
  border-collapse: separate;
  border-spacing: 0;
}
.rsv__table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #64748b;
  font-weight: 700;
  white-space: nowrap;
}
.rsv__table td {
  vertical-align: top;
  padding-top: 0.85rem;
  padding-bottom: 0.85rem;
}
.rsv__ref,
.rsv__type {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}
.rsv__ref strong,
.rsv__type strong {
  font-size: 0.86rem;
  color: #1c2830;
}
.rsv__ref small,
.rsv__type small {
  font-size: 0.72rem;
  color: #7b8d9a;
}
.rsv__client {
  display: flex;
  align-items: flex-start;
  gap: 0.55rem;
  min-width: 10rem;
}
.rsv__avatar {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  background: #eef4f8;
  color: var(--color-brand-600, #4a6d86);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.72rem;
  font-weight: 750;
  flex-shrink: 0;
}
.rsv__client strong {
  display: block;
  font-size: 0.86rem;
  color: #1c2830;
}
.rsv__client small {
  display: block;
  margin-top: 0.1rem;
  font-size: 0.72rem;
  color: #7b8d9a;
}
.rsv__status-stack {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  align-items: flex-start;
}
.rsv-pill {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 0.18rem 0.55rem;
  font-size: 0.7rem;
  font-weight: 650;
  white-space: nowrap;
}
.rsv-pill--guaranteed { background: #ecfdf5; color: #047857; }
.rsv-pill--confirmed { background: #eff6ff; color: #1d4ed8; }
.rsv-pill--pending { background: #fff7ed; color: #c2410c; }
.rsv-pill--in_progress { background: #fef3c7; color: #b45309; }
.rsv-pill--upcoming { background: #f1f5f9; color: #475569; }
.rsv-pill--done { background: #ecfdf5; color: #047857; }
.rsv-pill--closed { background: #f1f5f9; color: #64748b; }
.rsv__row-actions { white-space: nowrap; }
.rsv__detail-btn {
  border: 0;
  background: none;
  color: var(--color-brand-600, #4a6d86);
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
  padding: 0;
}
.rsv__detail-btn:hover { text-decoration: underline; }

.rd { display: flex; flex-direction: column; gap: 1rem; }
.rd__hero {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  align-items: flex-start;
}
.rd__eyebrow {
  display: inline-block;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #7b8d9a;
}
.rd__hero h3 {
  margin: 0.2rem 0 0;
  font-size: 1.25rem;
  color: #1c2830;
}
.rd__guest {
  margin: 0.25rem 0 0;
  font-size: 1rem;
  font-weight: 650;
  color: #334155;
}
.rd__pills { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.55rem; }
.rd__hero-actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.rd__note {
  margin: 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  color: #64748b;
  font-size: 0.82rem;
  line-height: 1.45;
}
.rd__card {
  border: 1px solid #d7e2ea;
  border-radius: 0.85rem;
  padding: 1rem 1.05rem;
  background: #fff;
}
.rd__card h4 {
  margin: 0 0 0.75rem;
  font-size: 0.95rem;
  color: #1c2830;
}
.rd__kv {
  margin: 0;
  display: grid;
  gap: 0.75rem 1.1rem;
  grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr));
}
.rd__kv > div { display: flex; flex-direction: column; gap: 0.2rem; }
.rd__kv dt { font-size: 0.72rem; color: #7b8d9a; font-weight: 650; }
.rd__kv dd { margin: 0; font-size: 0.88rem; color: #1c2830; font-weight: 600; }
.rd__span { grid-column: 1 / -1; }
.rd__table-wrap { overflow-x: auto; }
.rd__table { width: 100%; min-width: 48rem; }
.rd__thumb {
  width: 3.4rem;
  height: 2.5rem;
  border-radius: 0.45rem;
  overflow: hidden;
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.62rem;
  color: #94a3b8;
  text-align: center;
  padding: 0.15rem;
}
.rd__thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }

.rsv__muted, .rsv__empty {
  margin: 0; padding: 1.2rem; text-align: center; color: #7b8d9a; font-size: 0.875rem;
}
</style>
