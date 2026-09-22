<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_CONCIERGE_KINDS } from '../../../api/hospitality'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useAuthStore } from '../../../stores/auth'
import { useContextStore } from '../../../stores/context'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type Category = 'room_service' | 'transport' | 'activity' | 'maintenance' | 'special' | 'vip'
type Priority = 'low' | 'normal' | 'high' | 'urgent'
type Status = 'new' | 'acknowledged' | 'in_progress' | 'done' | 'cancelled'
type AssigneeType = 'internal' | 'supplier'
type ClientMode = 'stay' | 'manual'

const { t } = useI18n()
const ctx = useContextStore()
const auth = useAuthStore()

const docs = ref<Doc[]>([])
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const formOpen = ref(false)
const detailOpen = ref(false)
const editingId = ref<string | null>(null)
const detailRow = ref<Doc | null>(null)
const search = ref('')
const categoryFilter = ref<Category | 'all'>('all')
const statusFilter = ref<Status | 'all'>('all')
const filtersOpen = ref(false)

const categories: { id: Category; icon: string; color: string }[] = [
  { id: 'room_service', icon: 'products', color: '#0e7490' },
  { id: 'transport', icon: 'transfer', color: '#2563eb' },
  { id: 'activity', icon: 'sparkles', color: '#7c3aed' },
  { id: 'maintenance', icon: 'adjust', color: '#d97706' },
  { id: 'special', icon: 'tag', color: '#db2777' },
  { id: 'vip', icon: 'sparkles', color: '#b45309' },
]

const priorities: Priority[] = ['low', 'normal', 'high', 'urgent']

const form = ref(blankForm())

function blankForm() {
  return {
    client_mode: 'stay' as ClientMode,
    reservation_id: '',
    guest_name: '',
    room_id: '',
    room_number: '',
    stay_code: '',
    category: 'room_service' as Category,
    title: '',
    description: '',
    priority: 'normal' as Priority,
    scheduled_at: '',
    assignee_type: 'internal' as AssigneeType,
    assignee_name: auth.user?.name || '',
    internal_notes: '',
    status: 'new' as Status,
  }
}

const requests = computed(() =>
  docs.value
    .filter(d => d.kind === 'concierge_request')
    .slice()
    .sort((a, b) => String(b.request_no || '').localeCompare(String(a.request_no || ''))),
)

const rooms = computed(() =>
  docs.value
    .filter(d => d.kind === 'room')
    .slice()
    .sort((a, b) => String(a.number || a.name || '').localeCompare(String(b.number || b.name || ''))),
)

const inHouseStays = computed(() =>
  docs.value
    .filter(d => d.kind === 'reservation' && String(d.status || '') === 'checked_in')
    .slice()
    .sort((a, b) => String(a.guest_name || '').localeCompare(String(b.guest_name || ''))),
)

const stats = computed(() => ({
  total: requests.value.length,
  neu: requests.value.filter(r => r.status === 'new').length,
  inProgress: requests.value.filter(r => r.status === 'in_progress' || r.status === 'acknowledged').length,
  done: requests.value.filter(r => r.status === 'done').length,
  urgent: requests.value.filter(r => r.priority === 'urgent' || r.priority === 'high').length,
}))

const categoryCounts = computed(() => {
  const counts: Record<Category | 'all', number> = {
    all: requests.value.length,
    room_service: 0,
    transport: 0,
    activity: 0,
    maintenance: 0,
    special: 0,
    vip: 0,
  }
  for (const row of requests.value) {
    const cat = row.category as Category
    if (counts[cat] != null) counts[cat] += 1
  }
  return counts
})

const filteredRequests = computed(() => {
  const q = search.value.trim().toLowerCase()
  return requests.value.filter((row) => {
    if (categoryFilter.value !== 'all' && row.category !== categoryFilter.value) return false
    if (statusFilter.value !== 'all' && row.status !== statusFilter.value) return false
    if (!q) return true
    const hay = [
      row.request_no,
      row.guest_name,
      row.room_number,
      row.title,
      row.description,
      row.assignee_name,
      categoryLabel(row.category),
      priorityLabel(row.priority),
      statusLabel(row.status),
    ].join(' ').toLowerCase()
    return hay.includes(q)
  })
})

function categoryLabel(id: string) {
  const key = `hotel.concierge.categories.${id}`
  const translated = t(key)
  return translated === key ? id : translated
}

function categoryHint(id: Category) {
  return t(`hotel.concierge.categoryHints.${id}`)
}

function categoryColor(id: string) {
  return categories.find(c => c.id === id)?.color || '#64748b'
}

function priorityLabel(id: string) {
  const key = `hotel.concierge.priorities.${id}`
  const translated = t(key)
  return translated === key ? id : translated
}

function statusLabel(id: string) {
  const key = `hotel.concierge.statuses.${id}`
  const translated = t(key)
  return translated === key ? id : translated
}

function assigneeTypeLabel(id: string) {
  const key = `hotel.concierge.assigneeTypes.${id}`
  const translated = t(key)
  return translated === key ? id : translated
}

function initials(name: string) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return parts.slice(0, 2).map(p => p[0]?.toUpperCase() || '').join('')
}

function roomLabel(room: Doc) {
  return String(room.number || room.name || room.code || '—')
}

function stayLabel(stay: Doc) {
  const room = stay.room_number ? `#${stay.room_number}` : ''
  const code = stay.stay_code || stay.reservation_no || ''
  return [stay.guest_name || '—', room, code].filter(Boolean).join(' · ')
}

const statusPipeline: Status[] = ['new', 'acknowledged', 'in_progress', 'done', 'cancelled']

function formatScheduled(value: unknown) {
  const raw = String(value || '').trim()
  if (!raw) return '—'
  const d = new Date(raw)
  if (Number.isNaN(d.getTime())) return raw.replace('T', ' ').slice(0, 16)
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatLong(value: unknown) {
  const raw = String(value || '').trim()
  if (!raw) return '—'
  const d = new Date(raw)
  if (Number.isNaN(d.getTime())) return formatScheduled(raw)
  return d.toLocaleString(undefined, {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function statusStepState(row: Doc, step: Status): 'done' | 'current' | 'todo' | 'alt' {
  const current = (row.status as Status) || 'new'
  if (step === 'cancelled') {
    if (current === 'cancelled') return 'current'
    return 'alt'
  }
  if (current === 'cancelled') {
    const idx = statusPipeline.indexOf(step)
    const lastReached = Math.max(
      0,
      ...((row.status_history as Array<{ status: string }> | undefined) || [])
        .map(h => statusPipeline.indexOf(h.status as Status))
        .filter(i => i >= 0 && statusPipeline[i] !== 'cancelled'),
    )
    if (idx <= lastReached && step !== 'cancelled') return 'done'
    return 'todo'
  }
  const curIdx = statusPipeline.indexOf(current)
  const stepIdx = statusPipeline.indexOf(step)
  if (stepIdx < curIdx) return 'done'
  if (stepIdx === curIdx) return 'current'
  return 'todo'
}

function nextStatus(row: Doc): Status | null {
  const s = row.status as Status
  if (s === 'new') return 'acknowledged'
  if (s === 'acknowledged') return 'in_progress'
  if (s === 'in_progress') return 'done'
  return null
}

function nextStatusLabel(row: Doc) {
  const n = nextStatus(row)
  if (!n) return ''
  if (n === 'acknowledged') return t('hotel.concierge.actions.acknowledge')
  if (n === 'in_progress') return t('hotel.concierge.actions.start')
  if (n === 'done') return t('hotel.concierge.actions.complete')
  return statusLabel(n)
}

function pickStay(stayId: string) {
  form.value.reservation_id = stayId
  const stay = inHouseStays.value.find(s => s.id === stayId)
  if (!stay) return
  form.value.guest_name = String(stay.guest_name || '')
  form.value.room_number = String(stay.room_number || '')
  form.value.room_id = String(stay.room_id || '')
  form.value.stay_code = String(stay.stay_code || stay.reservation_no || '')
  if (!form.value.room_id && form.value.room_number) {
    const match = rooms.value.find(r => roomLabel(r) === form.value.room_number)
    if (match) form.value.room_id = String(match.id)
  }
}

function onRoomSelect(roomId: string) {
  form.value.room_id = roomId
  const room = rooms.value.find(r => r.id === roomId)
  if (room) form.value.room_number = roomLabel(room)
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

function openEdit(row: Doc) {
  editingId.value = row.id
  form.value = {
    client_mode: row.reservation_id ? 'stay' : 'manual',
    reservation_id: String(row.reservation_id || ''),
    guest_name: String(row.guest_name || ''),
    room_id: String(row.room_id || ''),
    room_number: String(row.room_number || ''),
    stay_code: String(row.stay_code || ''),
    category: (row.category as Category) || 'room_service',
    title: String(row.title || ''),
    description: String(row.description || ''),
    priority: (row.priority as Priority) || 'normal',
    scheduled_at: String(row.scheduled_at || '').slice(0, 16),
    assignee_type: (row.assignee_type as AssigneeType) || 'internal',
    assignee_name: String(row.assignee_name || auth.user?.name || ''),
    internal_notes: String(row.internal_notes || ''),
    status: (row.status as Status) || 'new',
  }
  error.value = ''
  detailOpen.value = false
  formOpen.value = true
}

function openDetail(row: Doc) {
  detailRow.value = row
  detailOpen.value = true
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_CONCIERGE_KINDS]))).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function save() {
  if (!form.value.guest_name.trim()) {
    error.value = t('hotel.concierge.errors.guestName')
    return
  }
  if (!form.value.room_number.trim()) {
    error.value = t('hotel.concierge.errors.room')
    return
  }
  if (!form.value.title.trim()) {
    error.value = t('hotel.concierge.errors.title')
    return
  }

  saving.value = true
  error.value = ''
  try {
    const payload: Record<string, unknown> = {
      action: 'upsert_concierge_request',
      guest_name: form.value.guest_name.trim(),
      room_id: form.value.room_id || null,
      room_number: form.value.room_number.trim(),
      reservation_id: form.value.client_mode === 'stay' ? (form.value.reservation_id || null) : null,
      stay_code: form.value.stay_code || null,
      category: form.value.category,
      title: form.value.title.trim(),
      description: form.value.description.trim() || null,
      priority: form.value.priority,
      scheduled_at: form.value.scheduled_at || null,
      assignee_type: form.value.assignee_type,
      assignee_name: form.value.assignee_name.trim() || null,
      assignee_id: form.value.assignee_type === 'internal' ? (auth.user?.id || null) : null,
      internal_notes: form.value.internal_notes.trim() || null,
      status: form.value.status || 'new',
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

async function setStatus(row: Doc, status: Status) {
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'set_concierge_status',
      id: row.id,
      status,
      by: auth.user?.name || null,
    })).data.docs
    if (detailRow.value?.id === row.id) {
      detailRow.value = docs.value.find(d => d.id === row.id) || null
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

watch(() => ctx.currentStoreId, () => { load() })
onMounted(load)
</script>

<template>
  <HotelChrome scroll-body>
    <div class="cg">
      <header class="cg__head">
        <div>
          <h2>{{ t('hotel.concierge.title') }}</h2>
          <p>{{ t('hotel.concierge.subtitle') }}</p>
        </div>
        <div class="cg__actions">
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            {{ t('common.refresh') }}
          </button>
          <button type="button" class="btn-primary" @click="openCreate">
            <AppIcon name="plus" :size="14" />
            {{ t('hotel.concierge.newRequest') }}
          </button>
        </div>
      </header>

      <p v-if="error && !formOpen" class="cg__error">{{ error }}</p>

      <section class="cg__stats">
        <article class="cg__stat">
          <span>{{ t('hotel.concierge.stats.total') }}</span>
          <strong>{{ stats.total }}</strong>
        </article>
        <article class="cg__stat">
          <span>{{ t('hotel.concierge.stats.new') }}</span>
          <em>{{ t('hotel.concierge.stats.newHint') }}</em>
          <strong>{{ stats.neu }}</strong>
        </article>
        <article class="cg__stat">
          <span>{{ t('hotel.concierge.stats.inProgress') }}</span>
          <em>{{ t('hotel.concierge.stats.inProgressHint') }}</em>
          <strong>{{ stats.inProgress }}</strong>
        </article>
        <article class="cg__stat">
          <span>{{ t('hotel.concierge.stats.done') }}</span>
          <em>{{ t('hotel.concierge.stats.doneHint') }}</em>
          <strong>{{ stats.done }}</strong>
        </article>
        <article class="cg__stat cg__stat--urgent">
          <span>{{ t('hotel.concierge.stats.urgent') }}</span>
          <em>{{ t('hotel.concierge.stats.urgentHint') }}</em>
          <strong>{{ stats.urgent }}</strong>
        </article>
      </section>

      <div class="cg__chips">
        <button
          type="button"
          class="cg__chip"
          :class="{ 'cg__chip--on': categoryFilter === 'all' }"
          @click="categoryFilter = 'all'"
        >
          {{ t('hotel.concierge.all') }}
        </button>
        <button
          v-for="cat in categories"
          :key="cat.id"
          type="button"
          class="cg__chip"
          :class="{ 'cg__chip--on': categoryFilter === cat.id }"
          :style="{ '--cat': cat.color }"
          @click="categoryFilter = cat.id"
        >
          <i class="cg__dot" />
          {{ categoryLabel(cat.id) }}
          <em>({{ categoryCounts[cat.id] }})</em>
        </button>
      </div>

      <div class="cg__toolbar">
        <input
          v-model="search"
          class="field cg__search"
          :placeholder="t('hotel.concierge.searchPh')"
        >
        <button
          type="button"
          class="btn-secondary cg__filters-toggle"
          :class="{ 'cg__filters-toggle--on': filtersOpen }"
          @click="filtersOpen = !filtersOpen"
        >
          <AppIcon name="filter" :size="13" />
          {{ t('filters.show') }}
        </button>
      </div>

      <div v-show="filtersOpen" class="cg__filters">
        <button
          type="button"
          class="cg__chip"
          :class="{ 'cg__chip--on': statusFilter === 'all' }"
          @click="statusFilter = 'all'"
        >
          {{ t('hotel.concierge.allStatuses') }}
        </button>
        <button
          v-for="st in statusPipeline"
          :key="st"
          type="button"
          class="cg__chip"
          :class="{ 'cg__chip--on': statusFilter === st }"
          @click="statusFilter = st"
        >
          {{ statusLabel(st) }}
        </button>
      </div>

      <div class="cg__table-wrap">
        <LoadingBlock v-if="loading" variant="list" :label="t('common.loading')" />
        <table v-else class="cg__table">
          <thead>
            <tr>
              <th>{{ t('hotel.concierge.cols.requestNo') }}</th>
              <th>{{ t('hotel.concierge.cols.client') }}</th>
              <th>{{ t('hotel.concierge.cols.category') }}</th>
              <th>{{ t('hotel.concierge.cols.request') }}</th>
              <th>{{ t('hotel.concierge.cols.priority') }}</th>
              <th>{{ t('hotel.concierge.cols.status') }}</th>
              <th>{{ t('hotel.concierge.cols.scheduled') }}</th>
              <th>{{ t('hotel.concierge.cols.assignee') }}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in filteredRequests" :key="row.id">
              <td><strong class="cg__code">{{ row.request_no || '—' }}</strong></td>
              <td>
                <div class="cg__client">
                  <span class="cg__avatar">{{ initials(row.guest_name) }}</span>
                  <div>
                    <strong>{{ row.guest_name || '—' }}</strong>
                    <small v-if="row.room_number">#{{ row.room_number }}</small>
                  </div>
                </div>
              </td>
              <td>
                <span class="cg-cat" :style="{ '--cat': categoryColor(row.category) }">
                  {{ categoryLabel(row.category) }}
                </span>
              </td>
              <td>
                <div class="cg__title-cell">
                  <strong>{{ row.title || '—' }}</strong>
                  <small v-if="row.description">{{ row.description }}</small>
                </div>
              </td>
              <td>
                <span class="cg-pill" :class="`cg-pill--prio-${row.priority}`">
                  {{ priorityLabel(row.priority) }}
                </span>
              </td>
              <td>
                <span class="cg-pill" :class="`cg-pill--${row.status}`">
                  {{ statusLabel(row.status) }}
                </span>
              </td>
              <td>{{ formatScheduled(row.scheduled_at) }}</td>
              <td>
                <div v-if="row.assignee_name" class="cg__assignee">
                  <span class="cg__avatar cg__avatar--sm">{{ initials(row.assignee_name) }}</span>
                  <div>
                    <strong>{{ row.assignee_name }}</strong>
                    <small>{{ assigneeTypeLabel(row.assignee_type) }}</small>
                  </div>
                </div>
                <span v-else>—</span>
              </td>
              <td>
                <button type="button" class="cg__view" @click="openDetail(row)">
                  {{ t('common.view') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!loading && !filteredRequests.length" class="cg__empty">
          {{ t('hotel.concierge.empty') }}
        </p>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="editingId ? t('hotel.concierge.editTitle') : t('hotel.concierge.createTitle')"
      icon="bell"
      size="xl"
      @close="closeForm"
    >
      <form class="cg-form" @submit.prevent="save">
        <p class="cg-form__intro">{{ t('hotel.concierge.createIntro') }}</p>
        <p v-if="error" class="cg__error">{{ error }}</p>

        <section class="cg-form__block">
          <h3><AppIcon name="customers" :size="15" /> {{ t('hotel.concierge.clientRoom') }}</h3>
          <p class="cg-form__label">{{ t('hotel.concierge.linkStay') }}</p>
          <div class="cg-form__modes">
            <label class="cg-form__mode" :class="{ 'cg-form__mode--on': form.client_mode === 'stay' }">
              <input v-model="form.client_mode" type="radio" value="stay">
              <span>{{ t('hotel.concierge.pickStay') }}</span>
            </label>
            <label class="cg-form__mode" :class="{ 'cg-form__mode--on': form.client_mode === 'manual' }">
              <input v-model="form.client_mode" type="radio" value="manual">
              <span>{{ t('hotel.concierge.manualClient') }}</span>
            </label>
          </div>

          <div v-if="form.client_mode === 'stay'" class="cg-form__grid">
            <div class="cg-form__span">
              <FieldLabel icon="bed">{{ t('hotel.concierge.pickStay') }}</FieldLabel>
              <select
                class="field"
                :value="form.reservation_id"
                @change="pickStay(($event.target as HTMLSelectElement).value)"
              >
                <option value="">{{ t('hotel.concierge.pickStayPh') }}</option>
                <option v-for="stay in inHouseStays" :key="stay.id" :value="stay.id">
                  {{ stayLabel(stay) }}
                </option>
              </select>
              <p v-if="!inHouseStays.length" class="cg-form__hint">{{ t('hotel.concierge.noStays') }}</p>
            </div>
          </div>

          <div class="cg-form__grid">
            <div>
              <FieldLabel icon="account">{{ t('hotel.concierge.guestName') }} *</FieldLabel>
              <input
                v-model="form.guest_name"
                class="field"
                required
                :placeholder="t('hotel.concierge.guestNamePh')"
              >
            </div>
            <div>
              <FieldLabel icon="key">{{ t('hotel.concierge.room') }} *</FieldLabel>
              <select
                class="field"
                :value="form.room_id"
                @change="onRoomSelect(($event.target as HTMLSelectElement).value)"
              >
                <option value="">{{ t('hotel.concierge.chooseRoom') }}</option>
                <option v-for="room in rooms" :key="room.id" :value="room.id">
                  #{{ roomLabel(room) }}
                </option>
              </select>
              <input
                v-if="!form.room_id"
                v-model="form.room_number"
                class="field"
                style="margin-top: 0.4rem"
                :placeholder="t('hotel.concierge.roomPh')"
              >
            </div>
          </div>
        </section>

        <section class="cg-form__block">
          <h3><AppIcon name="layers" :size="15" /> {{ t('hotel.concierge.requestDetail') }}</h3>
          <p class="cg-form__label">{{ t('hotel.concierge.serviceType') }}</p>
          <div class="cg-form__cats">
            <label
              v-for="cat in categories"
              :key="cat.id"
              class="cg-form__cat"
              :class="{ 'cg-form__cat--on': form.category === cat.id }"
              :style="{ '--cat': cat.color }"
            >
              <input v-model="form.category" type="radio" :value="cat.id">
              <span class="cg-form__cat-icon"><AppIcon :name="cat.icon" :size="16" /></span>
              <strong>{{ categoryLabel(cat.id) }}</strong>
              <span>{{ categoryHint(cat.id) }}</span>
            </label>
          </div>

          <div class="cg-form__grid">
            <div class="cg-form__span">
              <FieldLabel icon="sparkles">{{ t('hotel.concierge.shortTitle') }} *</FieldLabel>
              <input
                v-model="form.title"
                class="field"
                required
                :placeholder="t('hotel.concierge.shortTitlePh')"
              >
            </div>
            <div class="cg-form__span">
              <FieldLabel icon="note">{{ t('hotel.concierge.description') }}</FieldLabel>
              <textarea
                v-model="form.description"
                class="field"
                rows="3"
                :placeholder="t('hotel.concierge.descriptionPh')"
              />
            </div>
            <div class="cg-form__span">
              <FieldLabel icon="alert">{{ t('hotel.concierge.priority') }}</FieldLabel>
              <div class="cg-form__prios">
                <label
                  v-for="p in priorities"
                  :key="p"
                  class="cg-form__prio"
                  :class="{ 'cg-form__prio--on': form.priority === p, [`cg-form__prio--${p}`]: true }"
                >
                  <input v-model="form.priority" type="radio" :value="p">
                  {{ priorityLabel(p) }}
                </label>
              </div>
            </div>
          </div>
        </section>

        <section class="cg-form__block">
          <h3><AppIcon name="calendar" :size="15" /> {{ t('hotel.concierge.scheduling') }}</h3>
          <div class="cg-form__grid">
            <div>
              <FieldLabel icon="calendar">{{ t('hotel.concierge.scheduledAt') }}</FieldLabel>
              <input v-model="form.scheduled_at" class="field" type="datetime-local">
            </div>
          </div>
        </section>

        <section class="cg-form__block">
          <h3><AppIcon name="organization" :size="15" /> {{ t('hotel.concierge.assignment') }}</h3>
          <p class="cg-form__label">{{ t('hotel.concierge.assignTo') }}</p>
          <div class="cg-form__modes">
            <label class="cg-form__mode" :class="{ 'cg-form__mode--on': form.assignee_type === 'internal' }">
              <input v-model="form.assignee_type" type="radio" value="internal">
              <span>{{ t('hotel.concierge.assigneeTypes.internal') }}</span>
            </label>
            <label class="cg-form__mode" :class="{ 'cg-form__mode--on': form.assignee_type === 'supplier' }">
              <input v-model="form.assignee_type" type="radio" value="supplier">
              <span>{{ t('hotel.concierge.assigneeTypes.supplier') }}</span>
            </label>
          </div>
          <p class="cg-form__hint">{{ t('hotel.concierge.assigneeHint') }}</p>
          <div class="cg-form__grid">
            <div>
              <FieldLabel icon="account">{{ t('hotel.concierge.assigneeName') }}</FieldLabel>
              <input
                v-model="form.assignee_name"
                class="field"
                :placeholder="t('hotel.concierge.assigneeNamePh')"
              >
            </div>
            <div class="cg-form__span">
              <FieldLabel icon="lock">{{ t('hotel.concierge.internalNotes') }}</FieldLabel>
              <textarea
                v-model="form.internal_notes"
                class="field"
                rows="2"
                :placeholder="t('hotel.concierge.internalNotesPh')"
              />
            </div>
          </div>
        </section>

        <div class="cg-form__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="detailOpen"
      :title="detailRow?.request_no || t('hotel.concierge.title')"
      icon="bell"
      size="lg"
      @close="detailOpen = false"
    >
      <div v-if="detailRow" class="cg-detail">
        <div class="cg-detail__head">
          <span class="cg-cat" :style="{ '--cat': categoryColor(detailRow.category) }">
            {{ categoryLabel(detailRow.category) }}
          </span>
          <span class="cg-pill" :class="`cg-pill--prio-${detailRow.priority}`">
            {{ priorityLabel(detailRow.priority) }}
          </span>
          <span class="cg-pill" :class="`cg-pill--${detailRow.status}`">
            {{ statusLabel(detailRow.status) }}
          </span>
        </div>

        <h3 class="cg-detail__title">{{ detailRow.title }}</h3>
        <p v-if="detailRow.description" class="cg-detail__desc">{{ detailRow.description }}</p>

        <div class="cg-detail__guest">
          <span class="cg__avatar">{{ initials(detailRow.guest_name) }}</span>
          <div>
            <strong>{{ detailRow.guest_name || '—' }}</strong>
            <small>{{ t('hotel.concierge.roomShort', { n: detailRow.room_number || '—' }) }}</small>
          </div>
        </div>

        <dl class="cg-detail__meta">
          <div>
            <dt>{{ t('hotel.concierge.requestedAt') }}</dt>
            <dd>{{ formatLong(detailRow.requested_at) }}</dd>
          </div>
          <div>
            <dt>{{ t('hotel.concierge.cols.scheduled') }}</dt>
            <dd>{{ formatLong(detailRow.scheduled_at) }}</dd>
          </div>
          <div>
            <dt>{{ t('hotel.concierge.completedAt') }}</dt>
            <dd>{{ formatLong(detailRow.completed_at) }}</dd>
          </div>
        </dl>

        <div class="cg-detail__assignee-block">
          <span class="cg-detail__assignee-label">{{ t('hotel.concierge.cols.assignee') }}</span>
          <div v-if="detailRow.assignee_name" class="cg__assignee">
            <span class="cg__avatar">{{ initials(detailRow.assignee_name) }}</span>
            <div>
              <strong>{{ detailRow.assignee_name }}</strong>
              <small>{{ assigneeTypeLabel(detailRow.assignee_type) }}</small>
            </div>
          </div>
          <span v-else class="cg-detail__empty">—</span>
        </div>

        <section class="cg-detail__history">
          <h4>{{ t('hotel.concierge.statusHistory') }}</h4>
          <ol class="cg-timeline">
            <li
              v-for="step in statusPipeline"
              :key="step"
              class="cg-timeline__item"
              :class="`cg-timeline__item--${statusStepState(detailRow, step)}`"
            >
              <span class="cg-timeline__dot" />
              <span class="cg-timeline__label">
                {{ statusLabel(step) }}
                <em v-if="statusStepState(detailRow, step) === 'current'">
                  ← {{ t('hotel.concierge.current') }}
                </em>
              </span>
            </li>
          </ol>
        </section>

        <div class="cg-detail__actions">
          <button
            v-if="nextStatus(detailRow)"
            type="button"
            class="btn-primary"
            @click="setStatus(detailRow, nextStatus(detailRow)!)"
          >
            {{ nextStatusLabel(detailRow) }}
          </button>
          <button
            v-if="detailRow.status !== 'done' && detailRow.status !== 'cancelled'"
            type="button"
            class="btn-secondary"
            @click="setStatus(detailRow, 'cancelled')"
          >
            {{ t('hotel.concierge.actions.cancel') }}
          </button>
          <button type="button" class="btn-secondary" @click="openEdit(detailRow)">
            {{ t('common.edit') }}
          </button>
        </div>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.cg {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-bottom: 1.5rem;
}

.cg__head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.85rem;
  align-items: flex-start;
}

.cg__head h2 {
  margin: 0;
  font-size: 1.35rem;
  color: #1c2830;
}

.cg__head p {
  margin: 0.25rem 0 0;
  color: #66727c;
  font-size: 0.88rem;
}

.cg__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}

.cg__actions .btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.cg__error {
  margin: 0;
  color: #b91c1c;
  font-size: 0.88rem;
}

.cg__stats {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.65rem;
}

.cg__stat {
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.cg__stat span {
  font-size: 0.78rem;
  font-weight: 700;
  color: #64748b;
}

.cg__stat em {
  font-style: normal;
  font-size: 0.7rem;
  color: #94a3b8;
}

.cg__stat strong {
  font-size: 1.45rem;
  color: #1c2830;
  margin-top: 0.15rem;
}

.cg__stat--urgent strong { color: #b91c1c; }

.cg__chips,
.cg__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.cg__chip {
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 999px;
  padding: 0.35rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 650;
  color: #475569;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.cg__chip em {
  font-style: normal;
  color: #94a3b8;
  font-weight: 600;
}

.cg__chip--on {
  border-color: var(--cat, var(--color-brand-600, var(--color-brand-600)));
  background: color-mix(in srgb, var(--cat, var(--color-brand-600)) 12%, #fff);
  color: #1c2830;
}

.cg__dot {
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 999px;
  background: var(--cat, #94a3b8);
  display: inline-block;
}

.cg__toolbar {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.cg__search {
  flex: 1;
  min-width: 14rem;
}

.cg__filters-toggle--on {
  border-color: var(--color-brand-600, var(--color-brand-600));
  color: var(--color-brand-700, #3a586e);
}

.cg__table-wrap {
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  overflow: auto;
}

.cg__table {
  width: 100%;
  border-collapse: collapse;
  min-width: 960px;
}

.cg__table th,
.cg__table td {
  padding: 0.75rem 0.85rem;
  text-align: left;
  border-bottom: 1px solid #eef2f6;
  vertical-align: middle;
  font-size: 0.84rem;
}

.cg__table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #7b8d9a;
  font-weight: 700;
  background: #fafbfc;
}

.cg__code { color: #0e7490; font-size: 0.82rem; }

.cg__client,
.cg__assignee {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.cg__client strong,
.cg__assignee strong,
.cg__title-cell strong {
  display: block;
  color: #1c2830;
}

.cg__client small,
.cg__assignee small,
.cg__title-cell small {
  display: block;
  color: #7b8d9a;
  font-size: 0.72rem;
  margin-top: 0.1rem;
  max-width: 14rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.cg__avatar {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  background: #e8f0f5;
  color: var(--color-brand-600);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.72rem;
  font-weight: 700;
  flex-shrink: 0;
}

.cg__avatar--sm {
  width: 1.7rem;
  height: 1.7rem;
  font-size: 0.65rem;
}

.cg-cat {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--cat) 14%, #fff);
  color: color-mix(in srgb, var(--cat) 75%, #0f172a);
  font-size: 0.72rem;
  font-weight: 700;
  border: 1px solid color-mix(in srgb, var(--cat) 28%, #fff);
}

.cg-pill {
  display: inline-flex;
  padding: 0.18rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  background: #f1f5f9;
  color: #475569;
}

.cg-pill--new { background: #e0f2fe; color: #0369a1; }
.cg-pill--acknowledged { background: #ede9fe; color: #6d28d9; }
.cg-pill--in_progress { background: #fef3c7; color: #b45309; }
.cg-pill--done { background: #dcfce7; color: #15803d; }
.cg-pill--cancelled { background: #f1f5f9; color: #64748b; }
.cg-pill--prio-low { background: #f1f5f9; color: #64748b; }
.cg-pill--prio-normal { background: #e0f2fe; color: #0369a1; }
.cg-pill--prio-high { background: #ffedd5; color: #c2410c; }
.cg-pill--prio-urgent { background: #fee2e2; color: #b91c1c; }

.cg__view {
  border: 0;
  background: transparent;
  color: var(--color-brand-600, var(--color-brand-600));
  font-weight: 700;
  font-size: 0.82rem;
  cursor: pointer;
  text-decoration: underline;
  text-underline-offset: 2px;
}

.cg__muted,
.cg__empty {
  margin: 0;
  padding: 1.25rem;
  color: #7b8d9a;
  font-size: 0.88rem;
}

.cg-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.cg-form__intro {
  margin: 0;
  color: #66727c;
  font-size: 0.9rem;
}

.cg-form__block {
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  padding: 1rem;
  background: #fafbfc;
}

.cg-form__block h3 {
  margin: 0 0 0.75rem;
  font-size: 0.92rem;
  color: #1c2830;
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.cg-form__label {
  margin: 0 0 0.45rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: #64748b;
}

.cg-form__hint {
  margin: 0.35rem 0 0.65rem;
  font-size: 0.78rem;
  color: #7b8d9a;
}

.cg-form__modes {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-bottom: 0.75rem;
}

.cg-form__mode {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 0.65rem;
  padding: 0.45rem 0.75rem;
  font-size: 0.82rem;
  font-weight: 650;
  color: #475569;
  cursor: pointer;
}

.cg-form__mode input { accent-color: var(--color-brand-600, var(--color-brand-600)); }
.cg-form__mode--on {
  border-color: var(--color-brand-600, var(--color-brand-600));
  background: #eef4f7;
  color: #1c2830;
}

.cg-form__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.cg-form__span { grid-column: 1 / -1; }

.cg-form__cats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.55rem;
  margin-bottom: 0.85rem;
}

.cg-form__cat {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 0.75rem;
  padding: 0.7rem 0.75rem;
  cursor: pointer;
  min-height: 5.2rem;
}

.cg-form__cat input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.cg-form__cat-icon {
  width: 1.7rem;
  height: 1.7rem;
  border-radius: 0.45rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: color-mix(in srgb, var(--cat) 16%, #fff);
  color: var(--cat);
  margin-bottom: 0.15rem;
}

.cg-form__cat strong {
  font-size: 0.82rem;
  color: #1c2830;
}

.cg-form__cat span:last-child {
  font-size: 0.72rem;
  color: #7b8d9a;
  line-height: 1.35;
}

.cg-form__cat--on {
  border-color: var(--cat);
  box-shadow: 0 0 0 1px var(--cat);
  background: color-mix(in srgb, var(--cat) 8%, #fff);
}

.cg-form__prios {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.cg-form__prio {
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 999px;
  padding: 0.35rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 650;
  cursor: pointer;
  color: #475569;
}

.cg-form__prio input { display: none; }
.cg-form__prio--on.cg-form__prio--low { background: #f1f5f9; border-color: #94a3b8; color: #334155; }
.cg-form__prio--on.cg-form__prio--normal { background: #e0f2fe; border-color: #38bdf8; color: #0369a1; }
.cg-form__prio--on.cg-form__prio--high { background: #ffedd5; border-color: #fb923c; color: #c2410c; }
.cg-form__prio--on.cg-form__prio--urgent { background: #fee2e2; border-color: #f87171; color: #b91c1c; }

.cg-form__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 0.25rem;
}

.cg-detail__title {
  margin: 0.85rem 0 0.35rem;
  font-size: 1.35rem;
  color: #1c2830;
}

.cg-detail__desc {
  margin: 0 0 1rem;
  color: #66727c;
  font-size: 0.9rem;
}

.cg-detail__guest {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  margin-bottom: 1rem;
  padding: 0.75rem 0.85rem;
  background: #f8fafc;
  border: 1px solid #eef2f6;
  border-radius: 0.75rem;
}

.cg-detail__guest strong {
  display: block;
  color: #1c2830;
  font-size: 0.95rem;
}

.cg-detail__guest small {
  display: block;
  color: #7b8d9a;
  font-size: 0.78rem;
  margin-top: 0.1rem;
}

.cg-detail__head {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.cg-detail__meta {
  margin: 0 0 1rem;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.cg-detail__meta div {
  display: grid;
  gap: 0.2rem;
}

.cg-detail__meta dt {
  font-size: 0.72rem;
  font-weight: 700;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.cg-detail__meta dd {
  margin: 0;
  color: #1c2830;
  font-size: 0.9rem;
  font-weight: 650;
}

.cg-detail__assignee-block {
  margin-bottom: 1.1rem;
  padding: 0.75rem 0.85rem;
  border: 1px solid #eef2f6;
  border-radius: 0.75rem;
  background: #fff;
}

.cg-detail__assignee-label {
  display: block;
  font-size: 0.72rem;
  font-weight: 700;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  margin-bottom: 0.45rem;
}

.cg-detail__empty {
  color: #94a3b8;
}

.cg-detail__history h4 {
  margin: 0 0 0.75rem;
  font-size: 0.88rem;
  color: #1c2830;
}

.cg-timeline {
  list-style: none;
  margin: 0;
  padding: 0 0 0 0.35rem;
  display: flex;
  flex-direction: column;
  gap: 0;
}

.cg-timeline__item {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.45rem 0 0.45rem 0.15rem;
  color: #94a3b8;
  font-size: 0.88rem;
  font-weight: 650;
}

.cg-timeline__item:not(:last-child)::before {
  content: '';
  position: absolute;
  left: 0.48rem;
  top: 1.35rem;
  bottom: -0.1rem;
  width: 2px;
  background: #e2e8f0;
}

.cg-timeline__dot {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 999px;
  border: 2px solid #cbd5e1;
  background: #fff;
  flex-shrink: 0;
  z-index: 1;
}

.cg-timeline__label em {
  font-style: normal;
  margin-left: 0.35rem;
  color: #0e7490;
  font-weight: 800;
}

.cg-timeline__item--done {
  color: #334155;
}
.cg-timeline__item--done .cg-timeline__dot {
  border-color: #0e7490;
  background: #0e7490;
}
.cg-timeline__item--done:not(:last-child)::before {
  background: #0e7490;
}

.cg-timeline__item--current {
  color: #0f766e;
}
.cg-timeline__item--current .cg-timeline__dot {
  border-color: #0f766e;
  background: #14b8a6;
  box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.2);
}

.cg-timeline__item--alt {
  color: #cbd5e1;
}
.cg-timeline__item--alt .cg-timeline__dot {
  border-color: #e2e8f0;
  background: #f8fafc;
}

.cg-detail__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1.15rem;
}

@media (max-width: 640px) {
  .cg-detail__meta { grid-template-columns: 1fr; }
}

@media (max-width: 960px) {
  .cg__stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cg-form__cats { grid-template-columns: 1fr 1fr; }
}

@media (max-width: 640px) {
  .cg__stats { grid-template-columns: 1fr; }
  .cg-form__grid,
  .cg-form__cats { grid-template-columns: 1fr; }
}
</style>
