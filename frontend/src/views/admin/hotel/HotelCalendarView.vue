<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_CALENDAR_KINDS } from '../../../api/hospitality'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useContextStore } from '../../../stores/context'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type EventCategory = 'training' | 'meeting' | 'maintenance' | 'housekeeping' | 'reservation'
type CalEvent = {
  id: string
  title: string
  category: EventCategory
  start: string
  end: string
  notes?: string
  source?: 'local' | 'reservation'
  reservation_id?: string
}

const { t, locale } = useI18n()
const ctx = useContextStore()

const docs = ref<Doc[]>([])
const localEvents = ref<CalEvent[]>([])
const loading = ref(false)
const error = ref('')
const formOpen = ref(false)
const saving = ref(false)
const editingId = ref<string | null>(null)
const cursor = ref(startOfMonth(new Date()))
const selectedDate = ref(toDateInput(new Date()))
const activeCategory = ref<EventCategory | 'all'>('all')
const dragEventId = ref<string | null>(null)
const resizeEventId = ref<string | null>(null)

const categories: { id: EventCategory; color: string }[] = [
  { id: 'training', color: '#2563eb' },
  { id: 'meeting', color: '#7c3aed' },
  { id: 'maintenance', color: '#d97706' },
  { id: 'housekeeping', color: '#059669' },
  { id: 'reservation', color: 'var(--color-brand-600)' },
]

const form = ref(blankForm())

const storageKey = computed(() => `itara.hotel.calendar.${ctx.currentStoreId || 'default'}`)

function blankForm() {
  const day = selectedDate.value || toDateInput(new Date())
  return {
    title: '',
    category: 'meeting' as EventCategory,
    start: day,
    end: day,
    notes: '',
  }
}

function toDateInput(d: Date) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** Normalize any API / form date to local YYYY-MM-DD without shifting pure dates. */
function normalizeDay(value: unknown): string {
  const raw = String(value ?? '').trim()
  if (!raw) return ''
  const pure = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (pure) return `${pure[1]}-${pure[2]}-${pure[3]}`
  const withTime = raw.match(/^(\d{4}-\d{2}-\d{2})[T\s]/)
  if (withTime) {
    // Datetime with timezone → local calendar day
    if (/Z|[+-]\d{2}:?\d{2}$/.test(raw)) {
      const d = new Date(raw)
      if (!Number.isNaN(d.getTime())) return toDateInput(d)
    }
    return withTime[1]
  }
  const d = new Date(raw)
  if (!Number.isNaN(d.getTime())) return toDateInput(d)
  return raw.slice(0, 10)
}

function parseDate(iso: string) {
  const day = normalizeDay(iso)
  const [y, m, d] = day.split('-').map(Number)
  return new Date(y, (m || 1) - 1, d || 1)
}

function startOfMonth(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), 1)
}

function addMonths(d: Date, n: number) {
  return new Date(d.getFullYear(), d.getMonth() + n, 1)
}

function categoryLabel(id: EventCategory) {
  return t(`hotel.calendar.categories.${id}`)
}

function categoryColor(id: EventCategory) {
  return categories.find(c => c.id === id)?.color || '#64748b'
}

const reservationEvents = computed<CalEvent[]>(() =>
  docs.value
    .filter(d => d.kind === 'reservation')
    .map((d) => {
      const start = normalizeDay(d.arrive_on || d.checked_in_at)
      let end = normalizeDay(d.depart_on || d.arrive_on || d.checked_in_at)
      if (!start) return null
      // Checkout day is exclusive for hotel stays spanning multiple nights
      if (end && end > start) {
        const lastNight = parseDate(end)
        lastNight.setDate(lastNight.getDate() - 1)
        end = toDateInput(lastNight)
      }
      if (!end || end < start) end = start
      return {
        id: `rsv-${d.id}`,
        title: String(d.guest_name || d.stay_code || d.reservation_no || t('hotel.tabs.reservations')),
        category: 'reservation' as const,
        start,
        end,
        notes: String(d.special_requests || d.room_number || ''),
        source: 'reservation' as const,
        reservation_id: String(d.id),
      }
    })
    .filter((ev): ev is CalEvent => Boolean(ev)),
)

const events = computed(() => [...localEvents.value, ...reservationEvents.value])

const categoryCounts = computed(() => {
  const counts: Record<EventCategory, number> = {
    training: 0,
    meeting: 0,
    maintenance: 0,
    housekeeping: 0,
    reservation: 0,
  }
  for (const ev of events.value) {
    if (counts[ev.category] != null) counts[ev.category] += 1
  }
  return counts
})

const filteredEvents = computed(() =>
  activeCategory.value === 'all'
    ? events.value
    : events.value.filter(ev => ev.category === activeCategory.value),
)

const monthLabel = computed(() =>
  cursor.value.toLocaleDateString(locale.value || undefined, { month: 'long', year: 'numeric' }),
)

const selectedDayLabel = computed(() => {
  const d = parseDate(selectedDate.value)
  return d.toLocaleDateString(locale.value || undefined, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  })
})

const selectedDayEvents = computed(() => eventsOnDay(selectedDate.value))

const weekdayLabels = computed(() => {
  const base = startOfWeek(new Date(2024, 0, 7)) // Sunday
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(base)
    d.setDate(base.getDate() + i)
    return d.toLocaleDateString(locale.value || undefined, { weekday: 'short' })
  })
})

function startOfWeek(d: Date) {
  const copy = new Date(d)
  copy.setDate(copy.getDate() - copy.getDay())
  copy.setHours(0, 0, 0, 0)
  return copy
}

const calendarCells = computed(() => {
  const first = startOfMonth(cursor.value)
  const start = startOfWeek(first)
  const cells: Array<{
    date: Date
    iso: string
    inMonth: boolean
    isToday: boolean
    isSelected: boolean
    events: CalEvent[]
  }> = []
  const todayIso = toDateInput(new Date())
  for (let i = 0; i < 42; i++) {
    const date = new Date(start)
    date.setDate(start.getDate() + i)
    const iso = toDateInput(date)
    cells.push({
      date,
      iso,
      inMonth: date.getMonth() === cursor.value.getMonth(),
      isToday: iso === todayIso,
      isSelected: iso === selectedDate.value,
      events: eventsOnDay(iso),
    })
  }
  return cells
})

function eventsOnDay(iso: string) {
  const day = normalizeDay(iso)
  return filteredEvents.value
    .filter((ev) => {
      const start = normalizeDay(ev.start)
      const end = normalizeDay(ev.end) || start
      if (!start || !day) return false
      return start <= day && day <= end
    })
    .slice()
    .sort((a, b) => normalizeDay(a.start).localeCompare(normalizeDay(b.start)) || a.title.localeCompare(b.title))
}

function goToday() {
  const now = new Date()
  cursor.value = startOfMonth(now)
  selectedDate.value = toDateInput(now)
}

function prevPeriod() {
  cursor.value = addMonths(cursor.value, -1)
}

function nextPeriod() {
  cursor.value = addMonths(cursor.value, 1)
}

function onDateInput(value: string) {
  if (!value) return
  selectedDate.value = value
  cursor.value = startOfMonth(parseDate(value))
}

function selectDay(iso: string) {
  selectedDate.value = iso
}

function openCreate(dayIso?: string) {
  editingId.value = null
  form.value = blankForm()
  if (dayIso) {
    form.value.start = dayIso
    form.value.end = dayIso
    selectedDate.value = dayIso
  }
  formOpen.value = true
}

function openEdit(ev: CalEvent) {
  if (ev.source === 'reservation') return
  editingId.value = ev.id
  form.value = {
    title: ev.title,
    category: ev.category === 'reservation' ? 'meeting' : ev.category,
    start: ev.start.slice(0, 10),
    end: ev.end.slice(0, 10),
    notes: ev.notes || '',
  }
  formOpen.value = true
}

function closeForm() {
  formOpen.value = false
  editingId.value = null
  form.value = blankForm()
  error.value = ''
}

function persistLocal() {
  try {
    localStorage.setItem(storageKey.value, JSON.stringify(localEvents.value))
  } catch {
    // ignore quota / private mode
  }
}

function loadLocal() {
  try {
    const raw = localStorage.getItem(storageKey.value)
    if (!raw) {
      localEvents.value = []
      return
    }
    const parsed = JSON.parse(raw)
    localEvents.value = (Array.isArray(parsed) ? parsed : [])
      .map((ev: CalEvent) => ({
        ...ev,
        start: normalizeDay(ev.start),
        end: normalizeDay(ev.end) || normalizeDay(ev.start),
        source: ev.source || 'local',
      }))
      .filter((ev: CalEvent) => Boolean(ev.id && ev.start))
  } catch {
    localEvents.value = []
  }
}

async function loadReservations() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_CALENDAR_KINDS]))).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function saveEvent() {
  if (!form.value.title.trim()) {
    error.value = t('hotel.calendar.errors.title')
    return
  }
  if (!form.value.start || !form.value.end) {
    error.value = t('hotel.calendar.errors.dates')
    return
  }
  if (form.value.end < form.value.start) {
    error.value = t('hotel.calendar.errors.order')
    return
  }
  saving.value = true
  error.value = ''
  try {
    const start = normalizeDay(form.value.start)
    const end = normalizeDay(form.value.end) || start
    if (editingId.value) {
      localEvents.value = localEvents.value.map((ev) =>
        ev.id === editingId.value
          ? {
              ...ev,
              title: form.value.title.trim(),
              category: form.value.category,
              start,
              end,
              notes: form.value.notes.trim() || undefined,
            }
          : ev,
      )
    } else {
      localEvents.value = [
        ...localEvents.value,
        {
          id: `evt-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
          title: form.value.title.trim(),
          category: form.value.category,
          start,
          end,
          notes: form.value.notes.trim() || undefined,
          source: 'local',
        },
      ]
    }
    persistLocal()
    selectedDate.value = start
    cursor.value = startOfMonth(parseDate(start))
    closeForm()
  } finally {
    saving.value = false
  }
}

function removeEvent() {
  if (!editingId.value) return
  localEvents.value = localEvents.value.filter(ev => ev.id !== editingId.value)
  persistLocal()
  closeForm()
}

function onEventDragStart(ev: CalEvent, e: DragEvent) {
  if (ev.source === 'reservation') {
    e.preventDefault()
    return
  }
  dragEventId.value = ev.id
  e.dataTransfer?.setData('text/plain', ev.id)
  e.dataTransfer!.effectAllowed = 'move'
}

function onDayDrop(iso: string, e: DragEvent) {
  e.preventDefault()
  const id = dragEventId.value || e.dataTransfer?.getData('text/plain')
  dragEventId.value = null
  if (!id) return
  const event = localEvents.value.find(item => item.id === id)
  if (!event) return
  const span = Math.max(0, Math.round((parseDate(event.end).getTime() - parseDate(event.start).getTime()) / 86400000))
  const start = iso
  const endDate = parseDate(iso)
  endDate.setDate(endDate.getDate() + span)
  localEvents.value = localEvents.value.map(item =>
    item.id === id ? { ...item, start, end: toDateInput(endDate) } : item,
  )
  persistLocal()
  selectedDate.value = iso
}

function onDayDragOver(e: DragEvent) {
  e.preventDefault()
  if (e.dataTransfer) e.dataTransfer.dropEffect = 'move'
}

function beginResize(ev: CalEvent, e: MouseEvent) {
  if (ev.source === 'reservation') return
  e.stopPropagation()
  e.preventDefault()
  resizeEventId.value = ev.id
}

function onDayEnterDuringResize(iso: string) {
  if (!resizeEventId.value) return
  const event = localEvents.value.find(item => item.id === resizeEventId.value)
  if (!event) return
  const start = event.start.slice(0, 10)
  const end = iso >= start ? iso : start
  localEvents.value = localEvents.value.map(item =>
    item.id === resizeEventId.value ? { ...item, end } : item,
  )
}

function endResize() {
  if (!resizeEventId.value) return
  resizeEventId.value = null
  persistLocal()
}

watch(storageKey, () => {
  loadLocal()
})

onMounted(async () => {
  loadLocal()
  await loadReservations()
  window.addEventListener('mouseup', endResize)
})

onUnmounted(() => {
  window.removeEventListener('mouseup', endResize)
})

watch(() => ctx.currentStoreId, () => {
  loadLocal()
  void loadReservations()
})
</script>

<template>
  <HotelChrome scroll-body>
    <div class="cal" @mouseup="endResize">
      <header class="cal__top">
        <div class="cal__intro">
          <h2>{{ t('hotel.calendar.title') }}</h2>
          <p>{{ t('hotel.calendar.subtitle') }}</p>
        </div>
        <div class="cal__top-actions">
          <button type="button" class="btn-secondary" :disabled="loading" @click="loadReservations">
            {{ t('common.refresh') }}
          </button>
          <button type="button" class="btn-primary" @click="openCreate()">
            <AppIcon name="plus" :size="14" />
            {{ t('hotel.calendar.addEvent') }}
          </button>
        </div>
      </header>

      <p v-if="error && !formOpen" class="cal__error">{{ error }}</p>

      <div class="cal__shell">
        <section class="cal__main">
          <div class="cal__toolbar">
            <div class="cal__nav">
              <button type="button" class="cal__nav-btn" :title="t('hotel.calendar.prev')" @click="prevPeriod">‹</button>
              <button type="button" class="cal__nav-btn" :title="t('hotel.calendar.next')" @click="nextPeriod">›</button>
              <strong class="cal__month">{{ monthLabel }}</strong>
              <button type="button" class="cal__today" @click="goToday">{{ t('hotel.calendar.today') }}</button>
            </div>
            <div class="cal__filters">
              <button
                type="button"
                class="cal__chip"
                :class="{ 'cal__chip--on': activeCategory === 'all' }"
                @click="activeCategory = 'all'"
              >
                {{ t('hotel.calendar.all') }}
                <em>{{ events.length }}</em>
              </button>
              <button
                v-for="cat in categories"
                :key="cat.id"
                type="button"
                class="cal__chip"
                :class="{ 'cal__chip--on': activeCategory === cat.id }"
                :style="{ '--cat': cat.color }"
                @click="activeCategory = activeCategory === cat.id ? 'all' : cat.id"
              >
                <i />
                {{ categoryLabel(cat.id) }}
                <em>{{ categoryCounts[cat.id] }}</em>
              </button>
            </div>
          </div>

          <p v-if="loading" class="cal__muted">{{ t('common.loading') }}</p>

          <div class="cal__board">
            <div class="cal__weekdays">
              <span v-for="label in weekdayLabels" :key="label">{{ label }}</span>
            </div>
            <div class="cal__grid">
              <button
                v-for="cell in calendarCells"
                :key="cell.iso"
                type="button"
                class="cal__day"
                :class="{
                  'cal__day--out': !cell.inMonth,
                  'cal__day--today': cell.isToday,
                  'cal__day--selected': cell.isSelected,
                  'cal__day--busy': cell.events.length > 0,
                }"
                @click="selectDay(cell.iso)"
                @dblclick="openCreate(cell.iso)"
                @dragover="onDayDragOver"
                @drop="onDayDrop(cell.iso, $event)"
                @mouseenter="onDayEnterDuringResize(cell.iso)"
              >
                <header class="cal__day-head">
                  <span class="cal__day-num">{{ cell.date.getDate() }}</span>
                  <span v-if="cell.events.length" class="cal__day-count">{{ cell.events.length }}</span>
                </header>
                <div class="cal__events">
                  <article
                    v-for="ev in cell.events.slice(0, 3)"
                    :key="`${cell.iso}-${ev.id}`"
                    class="cal__event"
                    :class="{
                      'cal__event--locked': ev.source === 'reservation',
                      'cal__event--start': normalizeDay(ev.start) === cell.iso,
                      'cal__event--span': normalizeDay(ev.start) !== cell.iso,
                    }"
                    :style="{ '--cat': categoryColor(ev.category) }"
                    :title="`${ev.title} · ${normalizeDay(ev.start)}${normalizeDay(ev.end) !== normalizeDay(ev.start) ? ` → ${normalizeDay(ev.end)}` : ''}`"
                    :draggable="ev.source !== 'reservation'"
                    @click.stop="openEdit(ev)"
                    @dragstart="onEventDragStart(ev, $event)"
                  >
                    <strong>{{ ev.title }}</strong>
                    <span
                      v-if="ev.source !== 'reservation'"
                      class="cal__resize"
                      :title="t('hotel.calendar.resize')"
                      @mousedown="beginResize(ev, $event)"
                    />
                  </article>
                  <span v-if="cell.events.length > 3" class="cal__more">
                    +{{ cell.events.length - 3 }} {{ t('hotel.calendar.more') }}
                  </span>
                </div>
              </button>
            </div>
          </div>
        </section>

        <aside class="cal__agenda">
          <div class="cal__agenda-head">
            <div>
              <p class="cal__agenda-kicker">{{ t('hotel.calendar.agenda') }}</p>
              <h3>{{ selectedDayLabel }}</h3>
            </div>
            <button type="button" class="cal__agenda-add" :title="t('hotel.calendar.addEvent')" @click="openCreate(selectedDate)">
              <AppIcon name="plus" :size="16" />
            </button>
          </div>

          <div v-if="!selectedDayEvents.length" class="cal__agenda-empty">
            <AppIcon name="calendar" :size="28" />
            <p>{{ t('hotel.calendar.emptyDay') }}</p>
            <button type="button" class="btn-secondary" @click="openCreate(selectedDate)">
              {{ t('hotel.calendar.addEvent') }}
            </button>
          </div>

          <ul v-else class="cal__agenda-list">
            <li
              v-for="ev in selectedDayEvents"
              :key="ev.id"
              class="cal__agenda-item"
              :style="{ '--cat': categoryColor(ev.category) }"
              @click="openEdit(ev)"
            >
              <span class="cal__agenda-dot" />
              <div class="cal__agenda-body">
                <strong>{{ ev.title }}</strong>
                <p>
                  <span class="cal__agenda-cat">{{ categoryLabel(ev.category) }}</span>
                  <span v-if="normalizeDay(ev.end) !== normalizeDay(ev.start)">
                    · {{ normalizeDay(ev.start) }} → {{ normalizeDay(ev.end) }}
                  </span>
                  <span v-else-if="ev.source === 'reservation'">· {{ t('hotel.calendar.categories.reservation') }}</span>
                </p>
                <p v-if="ev.notes" class="cal__agenda-notes">{{ ev.notes }}</p>
              </div>
              <span v-if="ev.source === 'reservation'" class="cal__agenda-lock">{{ t('hotel.calendar.locked') }}</span>
            </li>
          </ul>
        </aside>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.calendar.editEvent') : t('hotel.calendar.addEvent')"
      icon="calendar"
      size="md"
      @close="closeForm"
    >
      <p v-if="error" class="cal__error">{{ error }}</p>
      <div class="cal__form">
        <div class="cal__span">
          <FieldLabel icon="sparkles">{{ t('hotel.calendar.eventTitle') }} *</FieldLabel>
          <input v-model="form.title" class="field" :placeholder="t('hotel.calendar.eventTitlePh')">
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('hotel.calendar.category') }}</FieldLabel>
          <select v-model="form.category" class="field">
            <option v-for="cat in categories.filter(c => c.id !== 'reservation')" :key="cat.id" :value="cat.id">
              {{ categoryLabel(cat.id) }}
            </option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('hotel.calendar.start') }} *</FieldLabel>
          <input v-model="form.start" class="field" type="date">
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('hotel.calendar.end') }} *</FieldLabel>
          <input v-model="form.end" class="field" type="date">
        </div>
        <div class="cal__span">
          <FieldLabel icon="sparkles">{{ t('hotel.calendar.notes') }}</FieldLabel>
          <textarea v-model="form.notes" class="field" rows="3" :placeholder="t('hotel.calendar.notesPh')" />
        </div>
      </div>
      <div class="cal__actions">
        <button v-if="editingId" type="button" class="btn-secondary" @click="removeEvent">{{ t('common.delete') }}</button>
        <div class="cal__actions-end">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="button" class="btn-primary" :disabled="saving" @click="saveEvent">{{ t('common.save') }}</button>
        </div>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.cal {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  width: 100%;
  min-height: 0;
}

.cal__top {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  flex-wrap: wrap;
}

.cal__intro h2 {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 750;
  letter-spacing: -0.02em;
  color: var(--color-text-primary, #1c2830);
}

.cal__intro p {
  margin: 0.25rem 0 0;
  font-size: 0.85rem;
  color: var(--color-text-muted, #66727c);
}

.cal__top-actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.cal__top-actions .btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.cal__error {
  margin: 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 0.85rem;
}

.cal__shell {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(16rem, 19rem);
  gap: 0.85rem;
  align-items: start;
  min-height: 0;
}

.cal__main {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  min-width: 0;
}

.cal__toolbar {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  padding: 0.85rem 1rem;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 1rem;
  background: #fff;
  box-shadow: var(--shadow-xs, 0 1px 2px rgba(15, 23, 42, 0.04));
}

.cal__nav {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.4rem;
}

.cal__nav-btn {
  width: 2.15rem;
  height: 2.15rem;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 0.65rem;
  background: #fff;
  font-size: 1.25rem;
  line-height: 1;
  cursor: pointer;
  color: var(--color-text-secondary, #334155);
}

.cal__nav-btn:hover {
  border-color: var(--color-brand-300, #c4b5fd);
  color: var(--color-brand-700);
}

.cal__month {
  margin: 0 0.35rem 0 0.25rem;
  font-size: 1.05rem;
  font-weight: 750;
  color: var(--color-text-primary, #1c2830);
  text-transform: capitalize;
}

.cal__today {
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 999px;
  background: #fff;
  padding: 0.35rem 0.8rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--color-text-secondary, #475569);
  cursor: pointer;
}

.cal__today:hover {
  border-color: var(--color-brand-400);
  color: var(--color-brand-700);
  background: var(--color-brand-50, #f5f3ff);
}

.cal__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.cal__chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border: 1px solid transparent;
  border-radius: 999px;
  background: #eef1f5;
  padding: 0.35rem 0.7rem;
  font-size: 0.78rem;
  font-weight: 650;
  color: var(--color-text-secondary, #334155);
  cursor: pointer;
}

.cal__chip i {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 999px;
  background: var(--cat, #94a3b8);
}

.cal__chip em {
  font-style: normal;
  opacity: 0.7;
  font-weight: 700;
}

.cal__chip--on {
  background: color-mix(in srgb, var(--cat, var(--color-brand-600)) 14%, #fff);
  border-color: color-mix(in srgb, var(--cat, var(--color-brand-600)) 40%, #fff);
  color: color-mix(in srgb, var(--cat, var(--color-brand-700)) 75%, #0f172a);
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--cat, var(--color-brand-600)) 18%, transparent);
}

.cal__board {
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 1rem;
  background: #fff;
  overflow: hidden;
  box-shadow: var(--shadow-xs, 0 1px 2px rgba(15, 23, 42, 0.04));
}

.cal__weekdays {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  background: #f8fafc;
  border-bottom: 1px solid var(--color-border, #e2e8f0);
}

.cal__weekdays span {
  padding: 0.7rem 0.35rem;
  text-align: center;
  font-size: 0.72rem;
  font-weight: 750;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--color-text-muted, #64748b);
}

.cal__grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
}

.cal__day {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.3rem;
  min-height: 7.5rem;
  border: 0;
  border-right: 1px solid #eef2f6;
  border-bottom: 1px solid #eef2f6;
  background: #fff;
  padding: 0.4rem 0.35rem 0.45rem;
  text-align: left;
  cursor: pointer;
  overflow: hidden;
  transition: background var(--motion-fast, 120ms) ease;
}

.cal__day:nth-child(7n) { border-right: 0; }

.cal__day:hover {
  background: #fafbff;
}

.cal__day--out {
  background: #f8fafc;
  color: #94a3b8;
}

.cal__day--out:hover {
  background: #f1f5f9;
}

.cal__day--today .cal__day-num {
  background: var(--color-brand-600);
  color: #fff;
  box-shadow: 0 4px 10px color-mix(in srgb, var(--color-brand-600) 35%, transparent);
}

.cal__day--selected {
  background: color-mix(in srgb, var(--color-brand-600) 7%, #fff);
  box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--color-brand-600) 45%, transparent);
  z-index: 1;
}

.cal__day--busy .cal__day-count {
  opacity: 1;
}

.cal__day-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.25rem;
  flex-shrink: 0;
}

.cal__day-num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.55rem;
  height: 1.55rem;
  padding: 0 0.3rem;
  border-radius: 999px;
  font-size: 0.78rem;
  font-weight: 750;
  color: inherit;
}

.cal__day-count {
  font-size: 0.65rem;
  font-weight: 700;
  color: var(--color-text-faint, #94a3b8);
  opacity: 0.85;
}

.cal__events {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.cal__event {
  position: relative;
  border-radius: 0.4rem;
  padding: 0.18rem 0.4rem 0.18rem 0.45rem;
  background: color-mix(in srgb, var(--cat) 16%, #fff);
  border: 1px solid color-mix(in srgb, var(--cat) 28%, #fff);
  border-left: 3px solid var(--cat);
  cursor: grab;
  flex-shrink: 0;
}

.cal__event--start {
  background: color-mix(in srgb, var(--cat) 26%, #fff);
}

.cal__event--span {
  opacity: 0.88;
  border-left-style: dashed;
}

.cal__event--locked {
  cursor: pointer;
}

.cal__event strong {
  display: block;
  font-size: 0.68rem;
  font-weight: 700;
  line-height: 1.25;
  color: color-mix(in srgb, var(--cat) 70%, #0f172a);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.cal__resize {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 0.5rem;
  height: 0.5rem;
  cursor: ew-resize;
  background: var(--cat);
  border-top-left-radius: 0.2rem;
  opacity: 0.8;
}

.cal__more {
  font-size: 0.65rem;
  color: var(--color-text-muted, #7b8d9a);
  font-weight: 650;
  padding: 0 0.15rem;
}

.cal__muted {
  margin: 0;
  color: var(--color-text-muted, #7b8d9a);
  font-size: 0.85rem;
}

.cal__agenda {
  position: sticky;
  top: 0.5rem;
  display: flex;
  flex-direction: column;
  min-height: 22rem;
  max-height: calc(100vh - 10rem);
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 1rem;
  background: #fff;
  box-shadow: var(--shadow-xs, 0 1px 2px rgba(15, 23, 42, 0.04));
  overflow: hidden;
}

.cal__agenda-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 1rem 1rem 0.85rem;
  border-bottom: 1px solid var(--color-border, #eef2f6);
}

.cal__agenda-kicker {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-brand-600);
}

.cal__agenda-head h3 {
  margin: 0.2rem 0 0;
  font-size: 0.95rem;
  font-weight: 750;
  color: var(--color-text-primary, #1c2830);
  text-transform: capitalize;
  line-height: 1.3;
}

.cal__agenda-add {
  width: 2.15rem;
  height: 2.15rem;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 0.7rem;
  background: var(--color-brand-600);
  color: #fff;
  cursor: pointer;
  flex-shrink: 0;
}

.cal__agenda-add:hover {
  filter: brightness(1.05);
}

.cal__agenda-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.55rem;
  padding: 1.5rem 1rem;
  color: var(--color-text-faint, #94a3b8);
  text-align: center;
}

.cal__agenda-empty p {
  margin: 0;
  font-size: 0.85rem;
  max-width: 12rem;
  line-height: 1.4;
}

.cal__agenda-list {
  list-style: none;
  margin: 0;
  padding: 0.65rem;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.cal__agenda-item {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.55rem;
  align-items: start;
  padding: 0.7rem 0.75rem;
  border: 1px solid color-mix(in srgb, var(--cat) 22%, #e2e8f0);
  border-radius: 0.75rem;
  background: color-mix(in srgb, var(--cat) 8%, #fff);
  cursor: pointer;
  transition: transform var(--motion-fast, 120ms) ease;
}

.cal__agenda-item:hover {
  transform: translateY(-1px);
}

.cal__agenda-dot {
  width: 0.55rem;
  height: 0.55rem;
  margin-top: 0.3rem;
  border-radius: 999px;
  background: var(--cat);
}

.cal__agenda-body strong {
  display: block;
  font-size: 0.84rem;
  font-weight: 750;
  color: var(--color-text-primary, #0f172a);
  line-height: 1.25;
}

.cal__agenda-body p {
  margin: 0.2rem 0 0;
  font-size: 0.72rem;
  color: var(--color-text-muted, #64748b);
}

.cal__agenda-cat {
  font-weight: 650;
  color: color-mix(in srgb, var(--cat) 65%, #334155);
}

.cal__agenda-notes {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.cal__agenda-lock {
  font-size: 0.62rem;
  font-weight: 750;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--color-brand-700, #6d28d9);
  background: var(--color-brand-50, #f5f3ff);
  border-radius: 999px;
  padding: 0.15rem 0.4rem;
}

.cal__form {
  display: grid;
  gap: 0.85rem;
  grid-template-columns: 1fr 1fr;
}

.cal__span { grid-column: 1 / -1; }

.cal__actions {
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
  margin-top: 1rem;
  flex-wrap: wrap;
}

.cal__actions-end {
  display: flex;
  gap: 0.5rem;
  margin-left: auto;
}

@media (max-width: 1100px) {
  .cal__shell {
    grid-template-columns: 1fr;
  }

  .cal__agenda {
    position: static;
    max-height: none;
    min-height: 0;
  }
}

@media (max-width: 720px) {
  .cal__day { min-height: 5.75rem; }
  .cal__form { grid-template-columns: 1fr; }
  .cal__event:nth-child(n + 3) { display: none; }
}
</style>
