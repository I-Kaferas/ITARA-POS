<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_HOUSEKEEPING_KINDS } from '../../../api/hospitality'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type BoardTab = 'rooms' | 'tasks'
type HkStatus = 'clean' | 'dirty' | 'cleaning' | 'inspected' | 'maintenance' | 'out_of_service'
type Occupancy = 'available' | 'reserved' | 'occupied' | 'blocked'
type TaskStatus = 'pending' | 'assigned' | 'in_progress' | 'done'
type TaskType = 'cleaning' | 'inspection' | 'turndown' | 'linen' | 'maintenance'
type Priority = 'low' | 'normal' | 'high' | 'urgent'

const { t } = useI18n()
const ctx = useContextStore()
const office = useBackofficeStore()

const docs = ref<Doc[]>([])
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const boardTab = ref<BoardTab>('rooms')
const search = ref('')
const conditionFilter = ref<HkStatus | 'all'>('all')
const occupancyFilter = ref<Occupancy | 'all'>('all')
const page = ref(1)
const pageSize = 10
const formOpen = ref(false)
const draggingId = ref<string | null>(null)
const selectedMemberId = ref<string | null>(null)

const hkStatuses: HkStatus[] = ['clean', 'dirty', 'cleaning', 'inspected', 'maintenance', 'out_of_service']
const occupancies: Occupancy[] = ['available', 'reserved', 'occupied', 'blocked']
const taskColumns: { id: TaskStatus; tone: string }[] = [
  { id: 'pending', tone: 'pending' },
  { id: 'assigned', tone: 'assigned' },
  { id: 'in_progress', tone: 'progress' },
  { id: 'done', tone: 'done' },
]
const taskTypes: TaskType[] = ['cleaning', 'inspection', 'turndown', 'linen', 'maintenance']
const priorities: Priority[] = ['low', 'normal', 'high', 'urgent']
const avatarPalette = ['#0e7490', '#2563eb', '#7c3aed', '#db2777', '#d97706', '#059669', '#b45309', '#4f46e5']

const form = ref(blankForm())

function blankForm() {
  return {
    id: '' as string,
    room_id: '',
    title: '',
    type: 'cleaning' as TaskType,
    priority: 'normal' as Priority,
    assignee_id: '',
    notes: '',
  }
}

const rooms = computed(() =>
  docs.value
    .filter(d => d.kind === 'room')
    .slice()
    .sort((a, b) => String(a.number || a.name || '').localeCompare(String(b.number || b.name || ''), undefined, { numeric: true })),
)

const roomTypes = computed(() => docs.value.filter(d => d.kind === 'room_type'))

const tasks = computed(() =>
  docs.value
    .filter(d => d.kind === 'housekeeping_task' && d.status !== 'cancelled')
    .slice()
    .sort((a, b) => String(b.task_no || '').localeCompare(String(a.task_no || ''))),
)

const team = computed(() =>
  office.users
    .filter(u => u.is_active !== false)
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })),
)

function occupancyOf(room: Doc): Occupancy {
  if (room.is_active === false || hkOf(room) === 'out_of_service') return 'blocked'
  const status = String(room.status || 'vacant')
  if (status === 'occupied') return 'occupied'
  if (status === 'reserved') return 'reserved'
  return 'available'
}

function hkOf(room: Doc): HkStatus {
  const value = String(room.housekeeping_status || 'clean') as HkStatus
  return hkStatuses.includes(value) ? value : 'clean'
}

function priorityOf(room: Doc): Priority {
  const value = String(room.hk_priority || 'low') as Priority
  return priorities.includes(value) ? value : 'low'
}

function typeName(room: Doc) {
  const type = roomTypes.value.find(item => item.id === room.type_id)
  return String(type?.name || room.type_name || '—')
}

function roomLabel(room: Doc) {
  return String(room.number || room.name || room.code || '—')
}

const stats = computed(() => ({
  total: rooms.value.length,
  ready: rooms.value.filter(r => hkOf(r) === 'clean' || hkOf(r) === 'inspected').length,
  dirty: rooms.value.filter(r => hkOf(r) === 'dirty').length,
  cleaning: rooms.value.filter(r => hkOf(r) === 'cleaning').length,
  maintenance: rooms.value.filter(r => hkOf(r) === 'maintenance').length,
}))

const openTaskCount = computed(() =>
  tasks.value.filter(task => task.status === 'in_progress' || task.status === 'assigned').length,
)

const filteredRooms = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rooms.value.filter((room) => {
    if (conditionFilter.value !== 'all' && hkOf(room) !== conditionFilter.value) return false
    if (occupancyFilter.value !== 'all' && occupancyOf(room) !== occupancyFilter.value) return false
    if (!q) return true
    const hay = [
      roomLabel(room),
      typeName(room),
      occupancyLabel(occupancyOf(room)),
      hkLabel(hkOf(room)),
      room.floor_number,
      room.hk_assignee_name,
      room.notes,
    ].join(' ').toLowerCase()
    return hay.includes(q)
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredRooms.value.length / pageSize)))

const pagedRooms = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredRooms.value.slice(start, start + pageSize)
})

const pageStart = computed(() => (filteredRooms.value.length ? (page.value - 1) * pageSize + 1 : 0))
const pageEnd = computed(() => Math.min(page.value * pageSize, filteredRooms.value.length))

const visibleTasks = computed(() => {
  const member = selectedMemberId.value
  if (!member) return tasks.value
  return tasks.value.filter(task => String(task.assignee_id || '') === member)
})

function tasksByStatus(status: TaskStatus) {
  return visibleTasks.value.filter(task => kanbanStatus(task) === status)
}

function kanbanStatus(task: Doc): TaskStatus {
  const status = String(task.status || 'pending')
  if (status === 'assigned' || status === 'in_progress' || status === 'done') return status
  if (status === 'pending' && String(task.assignee_id || task.assignee_name || '').trim()) return 'assigned'
  return 'pending'
}

function memberStats(userId: string) {
  const mine = tasks.value.filter(task => String(task.assignee_id || '') === userId)
  return {
    total: mine.length,
    done: mine.filter(task => kanbanStatus(task) === 'done').length,
  }
}

function initials(name: string) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return parts.slice(0, 2).map(p => p[0]?.toUpperCase() || '').join('')
}

function avatarColor(name: string) {
  let hash = 0
  for (const char of String(name || '')) hash = (hash * 31 + char.charCodeAt(0)) >>> 0
  return avatarPalette[hash % avatarPalette.length]
}

function hkLabel(status: string) {
  return t(`hotel.housekeeping.conditions.${status}`)
}

function occupancyLabel(id: Occupancy) {
  return t(`hotel.housekeeping.occupancy.${id}`)
}

function priorityLabel(id: string) {
  return t(`hotel.housekeeping.priorities.${id}`)
}

function taskTypeLabel(id: string) {
  return t(`hotel.housekeeping.taskTypes.${id}`)
}

function columnLabel(id: TaskStatus) {
  return t(`hotel.housekeeping.taskStatuses.${id}`)
}

watch([search, conditionFilter, occupancyFilter], () => { page.value = 1 })

function selectTab(tab: BoardTab) {
  boardTab.value = tab
  error.value = ''
}

function openCreate() {
  form.value = blankForm()
  formOpen.value = true
}

function closeForm() {
  formOpen.value = false
  form.value = blankForm()
}

function onRoomPick(roomId: string) {
  form.value.room_id = roomId
  const room = rooms.value.find(item => item.id === roomId)
  if (!room || form.value.title.trim()) return
  form.value.title = t('hotel.housekeeping.defaultTitle', { room: roomLabel(room) })
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [docsRes] = await Promise.all([
      api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_HOUSEKEEPING_KINDS])),
      office.users.length ? Promise.resolve(office.users) : office.loadUsers({ status: 'active' }).catch(() => []),
    ])
    docs.value = docsRes.data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function postAction(payload: Record<string, unknown>) {
  docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', payload)).data.docs
}

async function setHousekeeping(room: Doc, status: HkStatus) {
  if (hkOf(room) === status) return
  try {
    await postAction({
      action: 'set_room_housekeeping',
      id: room.id,
      housekeeping_status: status,
    })
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function saveTask() {
  if (!form.value.room_id) {
    error.value = t('hotel.housekeeping.errors.room')
    return
  }
  saving.value = true
  error.value = ''
  try {
    const member = team.value.find(u => u.id === form.value.assignee_id)
    await postAction({
      action: 'upsert_housekeeping_task',
      id: form.value.id || undefined,
      room_id: form.value.room_id,
      title: form.value.title.trim() || undefined,
      type: form.value.type,
      priority: form.value.priority,
      assignee_id: member?.id || null,
      assignee_name: member?.name || null,
      notes: form.value.notes.trim() || null,
      status: member ? 'assigned' : 'pending',
    })
    closeForm()
    boardTab.value = 'tasks'
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function moveTask(task: Doc, status: TaskStatus, assignee?: { id: string; name: string } | null) {
  try {
    const payload: Record<string, unknown> = {
      action: 'set_housekeeping_task_status',
      id: task.id,
      status,
    }
    if (assignee) {
      payload.assignee_id = assignee.id
      payload.assignee_name = assignee.name
    } else if (status === 'pending') {
      payload.assignee_id = null
      payload.assignee_name = null
    } else if (status === 'assigned' && !task.assignee_id && selectedMemberId.value) {
      const member = team.value.find(u => u.id === selectedMemberId.value)
      if (member) {
        payload.assignee_id = member.id
        payload.assignee_name = member.name
      }
    }
    await postAction(payload)
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

function onDragStart(task: Doc, event: DragEvent) {
  draggingId.value = task.id
  event.dataTransfer?.setData('text/plain', task.id)
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function onDragEnd() {
  draggingId.value = null
}

function draggingTask() {
  return tasks.value.find(task => task.id === draggingId.value) || null
}

async function dropOnColumn(status: TaskStatus) {
  const task = draggingTask()
  draggingId.value = null
  if (!task) return
  await moveTask(task, status)
}

async function dropOnMember(user: { id: string; name: string }) {
  const task = draggingTask()
  draggingId.value = null
  if (!task) return
  const next = kanbanStatus(task) === 'in_progress' || kanbanStatus(task) === 'done'
    ? kanbanStatus(task)
    : 'assigned'
  await moveTask(task, next, user)
}

function toggleMember(id: string) {
  selectedMemberId.value = selectedMemberId.value === id ? null : id
}

watch(() => ctx.currentStoreId, () => { load() })
onMounted(load)
</script>

<template>
  <HotelChrome scroll-body>
    <div class="hk">
      <header class="hk__head">
        <div>
          <h2>{{ t('hotel.housekeeping.title') }}</h2>
          <p>{{ t('hotel.housekeeping.subtitle') }}</p>
        </div>
        <div class="hk__actions">
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            {{ t('common.refresh') }}
          </button>
          <button type="button" class="btn-primary" @click="openCreate">
            <AppIcon name="plus" :size="14" />
            {{ t('hotel.housekeeping.newTask') }}
          </button>
        </div>
      </header>

      <p class="hk__summary">
        {{ t('hotel.housekeeping.summary', { dirty: stats.dirty, staff: team.length, tasks: openTaskCount }) }}
      </p>
      <p v-if="error" class="hk__error">{{ error }}</p>

      <section class="hk__stats">
        <article class="hk__stat">
          <span>{{ t('hotel.housekeeping.stats.total') }}</span>
          <strong>{{ stats.total }}</strong>
        </article>
        <article class="hk__stat hk__stat--ready">
          <span>{{ t('hotel.housekeeping.stats.ready') }}</span>
          <strong>{{ stats.ready }}</strong>
        </article>
        <article class="hk__stat hk__stat--dirty">
          <span>{{ t('hotel.housekeeping.stats.dirty') }}</span>
          <strong>{{ stats.dirty }}</strong>
        </article>
        <article class="hk__stat hk__stat--progress">
          <span>{{ t('hotel.housekeeping.stats.inProgress') }}</span>
          <strong>{{ stats.cleaning }}</strong>
        </article>
        <article class="hk__stat hk__stat--maint">
          <span>{{ t('hotel.housekeeping.stats.maintenance') }}</span>
          <strong>{{ stats.maintenance }}</strong>
        </article>
      </section>

      <div class="hk__tabs">
        <button
          type="button"
          class="hk__tab"
          :class="{ 'hk__tab--on': boardTab === 'rooms' }"
          @click="selectTab('rooms')"
        >
          {{ t('hotel.housekeeping.tabs.rooms') }}
        </button>
        <button
          type="button"
          class="hk__tab"
          :class="{ 'hk__tab--on': boardTab === 'tasks' }"
          @click="selectTab('tasks')"
        >
          {{ t('hotel.housekeeping.tabs.tasks') }}
        </button>
      </div>

      <template v-if="boardTab === 'rooms'">
        <div class="hk__filters">
          <div>
            <span>{{ t('hotel.housekeeping.condition') }}:</span>
            <button
              type="button"
              class="hk__chip"
              :class="{ 'hk__chip--on': conditionFilter === 'all' }"
              @click="conditionFilter = 'all'"
            >{{ t('hotel.housekeeping.all') }}</button>
            <button
              v-for="status in hkStatuses"
              :key="status"
              type="button"
              class="hk__chip"
              :class="{ 'hk__chip--on': conditionFilter === status }"
              @click="conditionFilter = status"
            >{{ hkLabel(status) }}</button>
          </div>
          <div>
            <span>{{ t('hotel.housekeeping.occupation') }}:</span>
            <button
              type="button"
              class="hk__chip"
              :class="{ 'hk__chip--on': occupancyFilter === 'all' }"
              @click="occupancyFilter = 'all'"
            >{{ t('hotel.housekeeping.all') }}</button>
            <button
              v-for="occ in occupancies"
              :key="occ"
              type="button"
              class="hk__chip"
              :class="{ 'hk__chip--on': occupancyFilter === occ }"
              @click="occupancyFilter = occ"
            >{{ occupancyLabel(occ) }}</button>
          </div>
          <input v-model="search" class="field hk__search" :placeholder="t('hotel.housekeeping.searchRooms')">
        </div>

        <div class="hk__table-wrap">
          <LoadingBlock v-if="loading" variant="list" :label="t('common.loading')" />
          <table v-else class="hk__table">
            <thead>
              <tr>
                <th>{{ t('hotel.housekeeping.cols.room') }}</th>
                <th>{{ t('hotel.housekeeping.cols.type') }}</th>
                <th>{{ t('hotel.housekeeping.cols.occupancy') }}</th>
                <th>{{ t('hotel.housekeeping.cols.condition') }}</th>
                <th>{{ t('hotel.housekeeping.cols.priority') }}</th>
                <th>{{ t('hotel.housekeeping.cols.floor') }}</th>
                <th>{{ t('hotel.housekeeping.cols.assignee') }}</th>
                <th>{{ t('hotel.housekeeping.cols.notes') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="room in pagedRooms" :key="room.id">
                <td><strong>{{ roomLabel(room) }}</strong></td>
                <td>{{ typeName(room) }}</td>
                <td>
                  <span class="hk-pill" :class="`hk-pill--occ-${occupancyOf(room)}`">
                    {{ occupancyLabel(occupancyOf(room)) }}
                  </span>
                </td>
                <td>
                  <div class="hk__hk-cell">
                    <span class="hk-pill" :class="`hk-pill--${hkOf(room)}`">{{ hkLabel(hkOf(room)) }}</span>
                    <select
                      class="field hk__mini"
                      :value="hkOf(room)"
                      @change="setHousekeeping(room, ($event.target as HTMLSelectElement).value as HkStatus)"
                    >
                      <option v-for="status in hkStatuses" :key="status" :value="status">{{ hkLabel(status) }}</option>
                    </select>
                  </div>
                </td>
                <td>{{ priorityLabel(priorityOf(room)) }}</td>
                <td>{{ room.floor_number ?? '—' }}</td>
                <td>{{ room.hk_assignee_name || '—' }}</td>
                <td class="hk__notes">{{ room.notes || '—' }}</td>
              </tr>
              <tr v-if="!pagedRooms.length">
                <td colspan="8" class="hk__muted">{{ t('hotel.housekeeping.emptyRooms') }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="hk__pager">
          {{ t('hotel.housekeeping.showing', { from: pageStart, to: pageEnd, total: filteredRooms.length }) }}
          <span class="hk__pages">
            <button type="button" class="hk__page" :disabled="page <= 1" @click="page -= 1">‹</button>
            <button
              v-for="n in totalPages"
              :key="n"
              type="button"
              class="hk__page"
              :class="{ 'hk__page--on': page === n }"
              @click="page = n"
            >{{ n }}</button>
            <button type="button" class="hk__page" :disabled="page >= totalPages" @click="page += 1">›</button>
          </span>
        </p>
      </template>

      <div v-else class="hk-board" :class="{ 'hk-board--dragging': Boolean(draggingId) }">
        <section
          v-for="col in taskColumns"
          :key="col.id"
          class="hk-col"
          :class="`hk-col--${col.tone}`"
          @dragover.prevent
          @drop.prevent="dropOnColumn(col.id)"
        >
          <header class="hk-col__head">
            <h3>{{ columnLabel(col.id) }}</h3>
            <em>{{ tasksByStatus(col.id).length }}</em>
          </header>
          <div class="hk-col__body">
            <article
              v-for="task in tasksByStatus(col.id)"
              :key="task.id"
              class="hk-card"
              :class="{ 'hk-card--drag': draggingId === task.id }"
              draggable="true"
              @dragstart="onDragStart(task, $event)"
              @dragend="onDragEnd"
            >
              <div class="hk-card__top">
                <strong>{{ task.room_number || '—' }}</strong>
                <span class="hk-pill" :class="`hk-pill--prio-${task.priority || 'low'}`">
                  {{ priorityLabel(task.priority || 'low') }}
                </span>
              </div>
              <p>{{ task.title || taskTypeLabel(task.type || 'cleaning') }}</p>
              <small>{{ task.task_no }} · {{ taskTypeLabel(task.type || 'cleaning') }}</small>
              <div v-if="task.assignee_name" class="hk-card__who">
                <span class="hk-ava" :style="{ background: avatarColor(task.assignee_name) }">
                  {{ initials(task.assignee_name) }}
                </span>
                {{ task.assignee_name }}
              </div>
            </article>
            <p v-if="!tasksByStatus(col.id).length" class="hk-col__empty">
              {{ t('hotel.housekeeping.noTasks') }}
            </p>
          </div>
        </section>

        <aside class="hk-team">
          <header class="hk-col__head">
            <h3>{{ t('hotel.housekeeping.team') }}</h3>
            <em>{{ team.length }}</em>
          </header>
          <div class="hk-team__list">
            <button
              v-for="user in team"
              :key="user.id"
              type="button"
              class="hk-member"
              :class="{ 'hk-member--on': selectedMemberId === user.id }"
              @dragover.prevent
              @drop.prevent="dropOnMember(user)"
              @click="toggleMember(user.id)"
            >
              <span class="hk-ava hk-ava--lg" :style="{ background: avatarColor(user.name) }">
                {{ initials(user.name) }}
              </span>
              <span>
                <strong>{{ user.name }}</strong>
                <small>{{ t('hotel.housekeeping.memberStats', memberStats(user.id)) }}</small>
              </span>
            </button>
            <p v-if="!team.length" class="hk-col__empty">{{ t('hotel.housekeeping.noStaff') }}</p>
          </div>
        </aside>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="t('hotel.housekeeping.createTitle')"
      icon="broom"
      size="md"
      @close="closeForm"
    >
      <form class="hk-form" @submit.prevent="saveTask">
        <div>
          <FieldLabel icon="bed">{{ t('hotel.housekeeping.cols.room') }}</FieldLabel>
          <select v-model="form.room_id" class="field" @change="onRoomPick(form.room_id)">
            <option value="">{{ t('hotel.housekeeping.chooseRoom') }}</option>
            <option v-for="room in rooms" :key="room.id" :value="room.id">
              {{ roomLabel(room) }} · {{ typeName(room) }}
            </option>
          </select>
        </div>
        <div>
          <FieldLabel icon="sparkles">{{ t('hotel.housekeeping.taskTitle') }}</FieldLabel>
          <input v-model="form.title" class="field" :placeholder="t('hotel.housekeeping.taskTitlePh')">
        </div>
        <div class="hk-form__grid">
          <div>
            <FieldLabel icon="broom">{{ t('hotel.housekeeping.cols.type') }}</FieldLabel>
            <select v-model="form.type" class="field">
              <option v-for="type in taskTypes" :key="type" :value="type">{{ taskTypeLabel(type) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="alert">{{ t('hotel.housekeeping.cols.priority') }}</FieldLabel>
            <select v-model="form.priority" class="field">
              <option v-for="prio in priorities" :key="prio" :value="prio">{{ priorityLabel(prio) }}</option>
            </select>
          </div>
        </div>
        <div>
          <FieldLabel icon="account">{{ t('hotel.housekeeping.cols.assignee') }}</FieldLabel>
          <select v-model="form.assignee_id" class="field">
            <option value="">{{ t('hotel.housekeeping.unassigned') }}</option>
            <option v-for="user in team" :key="user.id" :value="user.id">{{ user.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="note">{{ t('hotel.housekeeping.cols.notes') }}</FieldLabel>
          <textarea v-model="form.notes" class="field" rows="2" :placeholder="t('hotel.housekeeping.notesPh')" />
        </div>
        <div class="hk-form__actions">
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.hk {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-bottom: 1.5rem;
}
.hk__head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.85rem;
  align-items: flex-start;
}
.hk__head h2 {
  margin: 0;
  font-size: 1.35rem;
  color: #1c2830;
}
.hk__head p,
.hk__summary {
  margin: 0.25rem 0 0;
  color: #66727c;
  font-size: 0.88rem;
}
.hk__summary { margin: 0; }
.hk__actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.hk__actions .btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}
.hk__error { margin: 0; color: #b91c1c; font-size: 0.88rem; }
.hk__stats {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.65rem;
}
.hk__stat {
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}
.hk__stat span { color: #7b8d9a; font-size: 0.78rem; font-weight: 650; }
.hk__stat strong { font-size: 1.45rem; color: #1c2830; }
.hk__stat--ready strong { color: #047857; }
.hk__stat--dirty strong { color: #b45309; }
.hk__stat--progress strong { color: #1d4ed8; }
.hk__stat--maint strong { color: #b91c1c; }
.hk__tabs {
  display: flex;
  gap: 0.35rem;
  border-bottom: 1px solid #e8eef3;
}
.hk__tab {
  border: 0;
  background: transparent;
  padding: 0.65rem 0.9rem;
  font-weight: 700;
  color: #7b8d9a;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}
.hk__tab--on { color: #1c2830; border-bottom-color: var(--color-brand-600, var(--color-brand-600)); }
.hk__filters {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}
.hk__filters > div {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  align-items: center;
}
.hk__filters span { font-size: 0.78rem; font-weight: 700; color: #64748b; }
.hk__chip {
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 999px;
  padding: 0.2rem 0.6rem;
  font-size: 0.75rem;
  font-weight: 650;
  color: #475569;
  cursor: pointer;
}
.hk__chip--on { background: #eef4f8; border-color: #b7c9d6; color: #1c2830; }
.hk__search { max-width: 18rem; }
.hk__table-wrap {
  overflow: auto;
  background: #fff;
  border: 1px solid #e8eef3;
  border-radius: 0.85rem;
}
.hk__table { width: 100%; border-collapse: collapse; min-width: 56rem; }
.hk__table th,
.hk__table td {
  padding: 0.7rem 0.85rem;
  text-align: left;
  border-bottom: 1px solid #eef3f6;
  font-size: 0.86rem;
}
.hk__table th {
  background: #f8fafc;
  color: #64748b;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.hk__notes { color: #7b8d9a; max-width: 12rem; }
.hk__hk-cell { display: flex; flex-direction: column; gap: 0.3rem; align-items: flex-start; }
.hk__mini { width: auto; min-width: 8.5rem; padding: 0.2rem 0.4rem; font-size: 0.75rem; }
.hk__muted { margin: 0; padding: 1.25rem; color: #7b8d9a; }
.hk__pager {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  color: #7b8d9a;
  font-size: 0.82rem;
}
.hk__pages { display: flex; gap: 0.25rem; }
.hk__page {
  min-width: 1.8rem;
  height: 1.8rem;
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 0.4rem;
  cursor: pointer;
}
.hk__page--on { background: #1c2830; color: #fff; border-color: #1c2830; }
.hk-pill {
  display: inline-flex;
  padding: 0.16rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
}
.hk-pill--clean, .hk-pill--inspected { background: #d1fae5; color: #047857; }
.hk-pill--dirty { background: #ffedd5; color: #c2410c; }
.hk-pill--cleaning { background: #dbeafe; color: #1d4ed8; }
.hk-pill--maintenance { background: #fee2e2; color: #b91c1c; }
.hk-pill--out_of_service { background: #f1f5f9; color: #475569; }
.hk-pill--occ-available { background: #ecfdf5; color: #047857; }
.hk-pill--occ-reserved { background: #fff7ed; color: #c2410c; }
.hk-pill--occ-occupied { background: #eff6ff; color: #1d4ed8; }
.hk-pill--occ-blocked { background: #f1f5f9; color: #475569; }
.hk-pill--prio-low { background: #f1f5f9; color: #475569; }
.hk-pill--prio-normal { background: #e0f2fe; color: #0369a1; }
.hk-pill--prio-high { background: #ffedd5; color: #c2410c; }
.hk-pill--prio-urgent { background: #fee2e2; color: #b91c1c; }

.hk-board {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr)) minmax(16rem, 0.9fr);
  gap: 0.75rem;
  align-items: start;
  min-height: 28rem;
}
.hk-col,
.hk-team {
  background: #f8fafc;
  border: 1px solid #e8eef3;
  border-radius: 0.9rem;
  min-height: 26rem;
  display: flex;
  flex-direction: column;
}
.hk-col--pending { background: #f8fafc; }
.hk-col--assigned { background: #f8fbff; }
.hk-col--progress { background: #fffbeb; }
.hk-col--done { background: #f0fdf4; }
.hk-col__head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.8rem 0.9rem 0.45rem;
}
.hk-col__head h3 {
  margin: 0;
  font-size: 0.92rem;
  color: #1c2830;
}
.hk-col__head em {
  font-style: normal;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  min-width: 1.4rem;
  padding: 0.05rem 0.4rem;
  text-align: center;
  font-size: 0.75rem;
  font-weight: 700;
  color: #475569;
}
.hk-col__body,
.hk-team__list {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  padding: 0.55rem 0.7rem 0.85rem;
  flex: 1;
}
.hk-col__empty {
  margin: 1.5rem 0 0;
  text-align: center;
  color: #94a3b8;
  font-size: 0.82rem;
}
.hk-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 0.7rem 0.75rem;
  cursor: grab;
  display: flex;
  flex-direction: column;
  gap: 0.28rem;
}
.hk-card--drag { opacity: 0.55; }
.hk-card__top {
  display: flex;
  justify-content: space-between;
  gap: 0.4rem;
  align-items: center;
}
.hk-card p { margin: 0; font-size: 0.82rem; color: #334155; }
.hk-card small { color: #94a3b8; font-size: 0.7rem; }
.hk-card__who {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.75rem;
  color: #475569;
}
.hk-ava {
  width: 1.55rem;
  height: 1.55rem;
  border-radius: 999px;
  color: #fff;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.62rem;
  font-weight: 700;
  flex-shrink: 0;
}
.hk-ava--lg { width: 2.1rem; height: 2.1rem; font-size: 0.72rem; }
.hk-member {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  border: 1px solid transparent;
  background: #fff;
  border-radius: 0.75rem;
  padding: 0.5rem 0.6rem;
  text-align: left;
  cursor: pointer;
}
.hk-member strong { display: block; font-size: 0.84rem; color: #1c2830; }
.hk-member small { display: block; margin-top: 0.1rem; color: #7b8d9a; font-size: 0.72rem; }
.hk-member--on { border-color: #93c5fd; background: #eff6ff; }
.hk-form { display: flex; flex-direction: column; gap: 0.75rem; }
.hk-form__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.65rem; }
.hk-form__actions { display: flex; justify-content: flex-end; gap: 0.5rem; }

@media (max-width: 1100px) {
  .hk__stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .hk-board { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 720px) {
  .hk-board,
  .hk-form__grid { grid-template-columns: 1fr; }
}
</style>
