<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath } from '../../../api/hospitality'
import AppIcon from '../../../components/ui/AppIcon.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { formatMoney } from '../../../utils/money'
import { addDaysIso, buildHotelReport, toIsoDate } from '../../../utils/hotelReport'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>

const { t, locale } = useI18n()

const docs = ref<Doc[]>([])
const loading = ref(true)
const error = ref('')

const todayLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(new Date()),
)

const today = computed(() => toIsoDate(new Date()))

const rooms = computed(() => docs.value.filter(d => d.kind === 'room' && d.is_active !== false && d.status !== 'inactive'))
const reservations = computed(() => docs.value.filter(d => d.kind === 'reservation'))

const availability = computed(() => {
  const day = today.value
  const occupiedIds = new Set<string>()
  const reservedIds = new Set<string>()

  for (const row of reservations.value) {
    const arrive = dayKey(row.arrive_on)
    const depart = dayKey(row.depart_on)
    const roomId = String(row.room_id ?? '')
    if (!roomId || !arrive || !depart || arrive > day || depart <= day) continue
    const status = String(row.status ?? '')
    if (status === 'cancelled' || status === 'checked_out') continue
    if (status === 'checked_in') occupiedIds.add(roomId)
    else reservedIds.add(roomId)
  }

  let occupied = 0
  let reserved = 0
  let notReady = 0
  let available = 0

  for (const room of rooms.value) {
    const id = String(room.id)
    const status = String(room.status ?? '')
    const hk = String(room.housekeeping_status ?? 'clean')
    if (status === 'occupied' || occupiedIds.has(id)) occupied += 1
    else if (status === 'reserved' || reservedIds.has(id)) reserved += 1
    else if (['dirty', 'cleaning', 'maintenance', 'out_of_service'].includes(hk)) notReady += 1
    else available += 1
  }

  const total = Math.max(1, occupied + reserved + available + notReady)
  return { occupied, reserved, available, notReady, total }
})

const availabilityBar = computed(() => {
  const row = availability.value
  const slice = (count: number) => `${(count / row.total) * 100}%`
  return [
    { key: 'occupied', width: slice(row.occupied), color: 'var(--color-brand-600)' },
    { key: 'reserved', width: slice(row.reserved), color: 'var(--color-warning)' },
    { key: 'available', width: slice(row.available), color: 'var(--color-success)' },
    { key: 'notReady', width: slice(row.notReady), color: 'var(--color-danger)' },
  ]
})

const thisWeek = computed(() => weekRange(0))
const lastWeek = computed(() => weekRange(1))

const kpis = computed(() => {
  const current = thisWeek.value
  const previous = lastWeek.value
  const bookingsNow = countCreated(current.from, current.to, () => true)
  const bookingsPrev = countCreated(previous.from, previous.to, () => true)
  const checkInNow = countCheckIns(current.from, current.to)
  const checkInPrev = countCheckIns(previous.from, previous.to)
  const checkOutNow = countCheckOuts(current.from, current.to)
  const checkOutPrev = countCheckOuts(previous.from, previous.to)
  const revenueNow = revenueBetween(current.from, current.to)
  const revenuePrev = revenueBetween(previous.from, previous.to)

  return [
    { key: 'bookings', label: t('hotel.dashboard.newBookings'), value: String(bookingsNow), ...comparison(bookingsNow, bookingsPrev), icon: 'calendar' },
    { key: 'in', label: t('hotel.dashboard.checkIn'), value: String(checkInNow), ...comparison(checkInNow, checkInPrev), icon: 'key' },
    { key: 'out', label: t('hotel.dashboard.checkOut'), value: String(checkOutNow), ...comparison(checkOutNow, checkOutPrev), icon: 'logout' },
    { key: 'revenue', label: t('hotel.dashboard.totalRevenue'), value: formatMoney(revenueNow), ...comparison(revenueNow, revenuePrev), icon: 'receipt' },
  ]
})

const revenueBars = computed(() => {
  const end = new Date()
  const buckets: { key: string; label: string; cents: number }[] = []
  for (let i = 5; i >= 0; i -= 1) {
    const cursor = new Date(end.getFullYear(), end.getMonth() - i, 1)
    const from = toIsoDate(cursor)
    const to = toIsoDate(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0))
    buckets.push({
      key: from.slice(0, 7),
      label: cursor.toLocaleDateString(locale.value, { month: 'short' }),
      cents: revenueBetween(from, to),
    })
  }
  const max = niceMax(Math.max(0, ...buckets.map(row => row.cents / 100)))
  return {
    max,
    ticks: axisTicks(max, false),
    rows: buckets.map(row => ({
      ...row,
      pct: max ? Math.max(row.cents / 100 / max, 0) : 0,
    })),
  }
})

const reservationBars = computed(() => {
  const rows = []
  for (let i = 6; i >= 0; i -= 1) {
    const date = new Date()
    date.setDate(date.getDate() - i)
    const key = toIsoDate(date)
    let booked = 0
    let cancelled = 0
    for (const row of reservations.value) {
      if (dayKey(row.created_at) !== key) continue
      if (String(row.status) === 'cancelled') cancelled += 1
      else booked += 1
    }
    rows.push({
      key,
      label: date.toLocaleDateString(locale.value, { weekday: 'short' }),
      booked,
      cancelled,
    })
  }
  const peak = Math.max(0, ...rows.flatMap(row => [row.booked, row.cancelled]))
  const max = peak ? niceMax(peak) : 0
  return {
    empty: peak === 0,
    max,
    ticks: axisTicks(max, true),
    rows: rows.map(row => ({
      ...row,
      bookedPct: max ? row.booked / max : 0,
      cancelledPct: max ? row.cancelled / max : 0,
    })),
  }
})

const openTasks = computed(() => {
  const roomNumber = new Map(rooms.value.map(room => [String(room.id), String(room.number ?? room.name ?? '')]))
  return docs.value
    .filter(d => d.kind === 'housekeeping_task' && !['done', 'cancelled'].includes(String(d.status ?? 'pending')))
    .slice(0, 5)
    .map(task => ({
      id: String(task.id),
      title: String(task.title || task.task_no || t('hotel.dashboard.tasks')),
      meta: roomNumber.get(String(task.room_id ?? '')) || String(task.status ?? ''),
    }))
})

async function load(silent?: boolean) {
  if (silent !== true) loading.value = true
  error.value = ''
  try {
    const kinds = ['reservation', 'folio', 'room', 'room_type', 'housekeeping_task']
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath(kinds))).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

onMounted(() => load())
useRealtimeSync(realtimeTopics.hotel, () => load(true))

function dayKey(value?: string | null) {
  return value ? String(value).slice(0, 10) : ''
}

function weekRange(weeksAgo: number) {
  const end = new Date()
  end.setDate(end.getDate() - weeksAgo * 7)
  const to = toIsoDate(end)
  return { from: addDaysIso(to, -6), to }
}

function countCreated(from: string, to: string, accept: (row: Doc) => boolean) {
  return reservations.value.filter(row => {
    const created = dayKey(row.created_at)
    return created >= from && created <= to && accept(row)
  }).length
}

function countCheckIns(from: string, to: string) {
  return reservations.value.filter(row => {
    const status = String(row.status ?? '')
    if (status !== 'checked_in' && status !== 'checked_out') return false
    const day = dayKey(row.checked_in_at) || dayKey(row.arrive_on)
    return day >= from && day <= to
  }).length
}

function countCheckOuts(from: string, to: string) {
  return reservations.value.filter(row => {
    if (String(row.status ?? '') !== 'checked_out') return false
    const day = dayKey(row.checked_out_at) || dayKey(row.depart_on)
    return day >= from && day <= to
  }).length
}

const reportHorizon = computed(() => buildHotelReport(docs.value, addDaysIso(today.value, -200), today.value))

function revenueBetween(from: string, to: string) {
  return reportHorizon.value.daily
    .filter(point => point.date >= from && point.date <= to)
    .reduce((sum, point) => sum + point.cents, 0)
}

function comparison(current: number, previous: number) {
  if (current === 0 && previous === 0) {
    return { delta: null as string | null, deltaTone: 'flat' as const }
  }
  const delta = deltaPct(current, previous)
  return {
    delta: `${formatPct(delta)} ${t('hotel.dashboard.vsLastWeek')}`,
    deltaTone: deltaTone(delta),
  }
}

function deltaPct(current: number, previous: number) {
  if (!previous) return current ? null : 0
  return Math.round(((current - previous) / previous) * 1000) / 10
}

function axisTicks(max: number, integer: boolean) {
  if (max <= 0) return [0]
  if (integer) {
    const top = Math.max(1, Math.ceil(max))
    const mid = Math.round(top / 2)
    return mid > 0 && mid < top ? [top, mid, 0] : [top, 0]
  }
  return [max, max / 2, 0]
}

function formatPct(value: number | null) {
  if (value == null) return '—'
  const body = new Intl.NumberFormat(locale.value, { maximumFractionDigits: 1 }).format(Math.abs(value))
  if (value > 0) return `+${body}%`
  if (value < 0) return `−${body}%`
  return `${body}%`
}

function deltaTone(value: number | null) {
  if (value == null || value === 0) return 'flat'
  return value > 0 ? 'up' : 'down'
}

function niceMax(value: number) {
  if (value <= 1) return 1
  const steps = 4
  const raw = value / steps
  const mag = 10 ** Math.floor(Math.log10(raw))
  const unit = [1, 2, 2.5, 5, 10].map(n => n * mag).find(n => n >= raw) ?? mag * 10
  return unit * steps
}

function compactNumber(value: number) {
  const abs = Math.abs(value)
  const format = (n: number) => new Intl.NumberFormat(locale.value, {
    maximumFractionDigits: Math.abs(n) >= 10 ? 0 : 1,
  }).format(n)
  if (abs >= 1_000_000) return `${format(value / 1_000_000)}M`
  if (abs >= 1_000) return `${format(value / 1_000)}k`
  return new Intl.NumberFormat(locale.value, { maximumFractionDigits: Number.isInteger(value) ? 0 : 1 }).format(value)
}
</script>

<template>
  <HotelChrome scroll-body :subtitle="t('hotel.dashboard.subtitle')">
    <div class="hd">
      <div class="hd__toolbar">
        <p class="text-caption">{{ todayLabel }}</p>
        <div class="hd__actions">
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="recycle" :size="15" />
            {{ t('common.refresh') }}
          </button>
          <RouterLink class="btn-primary" to="/admin/hotel/reservations?new=1">
            <AppIcon name="plus" :size="15" />
            {{ t('hotel.dashboard.newBooking') }}
          </RouterLink>
        </div>
      </div>

      <p v-if="error" class="hd__error">{{ error }}</p>
      <LoadingBlock v-else-if="loading && !docs.length" variant="cards" :rows="4" :label="t('common.loading')" />

      <template v-else>
        <section class="hd-kpis stagger-in">
          <KpiCard
            v-for="card in kpis"
            :key="card.key"
            :label="card.label"
            :value="card.value"
            :icon="card.icon"
            :delta="card.delta"
            :delta-tone="card.deltaTone"
          />
        </section>

        <div class="hd-grid">
          <section class="ui-card">
            <header class="ui-card__header">
              <h3 class="ui-card__title">{{ t('hotel.dashboard.roomAvailability') }}</h3>
              <RouterLink to="/admin/hotel/rooms" class="hd-link">{{ t('hotel.dashboard.viewAll') }}</RouterLink>
            </header>
            <div class="ui-card__body">
              <div class="avail__bar" aria-hidden="true">
                <span
                  v-for="slice in availabilityBar"
                  :key="slice.key"
                  :style="{ width: slice.width, background: slice.color }"
                />
              </div>
              <ul class="avail__list">
                <li><span class="avail__dot avail__dot--occupied" />{{ t('hotel.dashboard.occupied') }}<strong>{{ availability.occupied }}</strong></li>
                <li><span class="avail__dot avail__dot--reserved" />{{ t('hotel.dashboard.reserved') }}<strong>{{ availability.reserved }}</strong></li>
                <li><span class="avail__dot avail__dot--available" />{{ t('hotel.dashboard.available') }}<strong>{{ availability.available }}</strong></li>
                <li><span class="avail__dot avail__dot--not-ready" />{{ t('hotel.dashboard.notReady') }}<strong>{{ availability.notReady }}</strong></li>
              </ul>
            </div>
          </section>

          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.dashboard.revenue') }}</h3>
                <p class="text-caption">{{ t('hotel.dashboard.last6Months') }}</p>
              </div>
            </header>
            <div class="ui-card__body">
              <div class="chart" role="img" :aria-label="t('hotel.dashboard.revenue')">
                <div class="chart__y">
                  <span v-for="(tick, index) in revenueBars.ticks" :key="index">{{ compactNumber(tick) }}</span>
                </div>
                <div class="chart__plot">
                  <div v-for="bar in revenueBars.rows" :key="bar.key" class="chart__col">
                    <div class="chart__track">
                      <span class="chart__bar" :style="{ transform: `scaleY(${bar.pct})` }" />
                    </div>
                    <span class="chart__label">{{ bar.label }}</span>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>

        <div class="hd-grid">
          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.dashboard.reservations') }}</h3>
                <p class="text-caption">{{ t('hotel.dashboard.last7Days') }}</p>
              </div>
              <p v-if="!reservationBars.empty" class="hd-legend">
                <span><i class="avail__dot avail__dot--occupied" />{{ t('hotel.dashboard.booked') }}</span>
                <span><i class="avail__dot avail__dot--not-ready" />{{ t('hotel.dashboard.cancelled') }}</span>
              </p>
            </header>
            <div class="ui-card__body">
              <p v-if="reservationBars.empty" class="hd-empty">{{ t('hotel.dashboard.noReservations') }}</p>
              <div v-else class="chart" role="img" :aria-label="t('hotel.dashboard.reservations')">
                <div class="chart__y">
                  <span v-for="(tick, index) in reservationBars.ticks" :key="index">{{ compactNumber(tick) }}</span>
                </div>
                <div class="chart__plot">
                  <div v-for="bar in reservationBars.rows" :key="bar.key" class="chart__col">
                    <div class="chart__track chart__track--pair">
                      <span class="chart__bar" :style="{ transform: `scaleY(${bar.bookedPct})` }" />
                      <span class="chart__bar chart__bar--danger" :style="{ transform: `scaleY(${bar.cancelledPct})` }" />
                    </div>
                    <span class="chart__label">{{ bar.label }}</span>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <div class="hd-stack">
            <section class="ui-card">
              <header class="ui-card__header">
                <h3 class="ui-card__title">{{ t('hotel.dashboard.tasks') }}</h3>
                <RouterLink to="/admin/hotel/housekeeping" class="hd-link">{{ t('hotel.dashboard.viewAll') }}</RouterLink>
              </header>
              <div class="ui-card__body">
                <p v-if="!openTasks.length" class="hd-empty">{{ t('hotel.dashboard.noTasks') }}</p>
                <ul v-else class="task-list">
                  <li v-for="task in openTasks" :key="task.id">
                    <strong>{{ task.title }}</strong>
                    <span>{{ task.meta }}</span>
                  </li>
                </ul>
              </div>
            </section>

            <section class="ui-card">
              <header class="ui-card__header">
                <h3 class="ui-card__title">{{ t('hotel.dashboard.overallRating') }}</h3>
              </header>
              <div class="ui-card__body">
                <p class="hd-empty">{{ t('hotel.dashboard.ratingNone') }}</p>
              </div>
            </section>
          </div>
        </div>
      </template>
    </div>
  </HotelChrome>
</template>

<style scoped>
.hd {
  display: flex;
  flex-direction: column;
  gap: var(--section-gap);
}

.hd__toolbar,
.hd__actions,
.hd-legend {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.hd__toolbar {
  justify-content: space-between;
}

.hd__actions {
  margin-left: auto;
}

.hd__error {
  margin: 0;
  color: var(--color-danger);
}

.hd-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--card-gap);
}

.hd-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--card-gap);
  align-items: start;
}

.hd-stack {
  display: flex;
  flex-direction: column;
  gap: var(--card-gap);
}

.hd-link {
  color: var(--color-ink-brand, var(--color-brand-700));
  font-size: var(--text-sm);
  font-weight: 600;
  text-decoration: none;}

.hd-link:hover { text-decoration: underline; }

.hd-empty {
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.avail__bar {
  display: flex;
  height: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--color-table-header);
}

.avail__list,
.task-list {
  list-style: none;
  margin: var(--space-4) 0 0;
  padding: 0;
}

.avail__list li,
.task-list li {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 40px;
  border-top: 1px solid var(--color-border);
  font-size: var(--text-sm);
  color: var(--color-text-secondary);
}

.avail__list strong,
.task-list span {
  margin-left: auto;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
}

.avail__dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  flex-shrink: 0;
}

.avail__dot--occupied { background: var(--color-brand-600); }
.avail__dot--reserved { background: var(--color-warning); }
.avail__dot--available { background: var(--color-success); }
.avail__dot--not-ready { background: var(--color-danger); }

.chart {
  display: grid;
  grid-template-columns: 4.25rem 1fr;
  gap: var(--space-3);
  min-height: 180px;
}

.chart__y {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.chart__plot {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  gap: var(--space-2);
  align-items: end;
}

.chart__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  min-width: 0;
}

.chart__track {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 3px;
  width: 100%;
  height: 140px;
}

.chart__bar {
  display: block;
  width: 14px;
  height: 100%;
  border-radius: 5px 5px 0 0;
  background: var(--color-brand-600);
  transform-origin: bottom;
  transform: scaleY(0);
}

.chart__bar--danger { background: var(--color-danger); }

.chart__label {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
}

.task-list strong {
  font-weight: 600;
  color: var(--color-text-primary);
}

@media (max-width: 1100px) {
  .hd-kpis,
  .hd-grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 720px) {
  .hd-kpis,
  .hd-grid {
    grid-template-columns: 1fr;
  }
}
</style>
