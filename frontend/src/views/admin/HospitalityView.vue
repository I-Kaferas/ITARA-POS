<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import Badge from '../../components/ui/Badge.vue'
import EmptyState from '../../components/ui/EmptyState.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useConfirm } from '../../composables/useConfirm'
import { formatMoney } from '../../utils/format'
import { useAuthStore } from '../../stores/auth'

type Doc = Record<string, any>
const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const route = useRoute()
const auth = useAuthStore()
const modules = computed(() => auth.user?.modules)
const canRestaurant = computed(() => !modules.value?.length || modules.value.includes('restaurant'))
const canHotel = computed(() => !modules.value?.length || modules.value.includes('hotel'))
const docs = ref<Doc[]>([])
const initialSection = route.query.section
const section = ref<'restaurant' | 'kitchen' | 'hotel'>(
  initialSection === 'hotel' || initialSection === 'kitchen' || initialSection === 'restaurant'
    ? initialSection
    : 'restaurant',
)
if (section.value !== 'hotel' && !canRestaurant.value) section.value = 'hotel'
if (section.value === 'hotel' && !canHotel.value) section.value = 'restaurant'
const error = ref('')
const loading = ref(false)
const order = ref<Doc | null>(null)
const lineName = ref('')
const linePrice = ref('')
const course = ref('plat')
const guest = ref('')
const roomId = ref('')
const folioKind = ref('minibar')
const folioAmount = ref('')
const tableFormOpen = ref(false)
const zoneFormOpen = ref(false)
const savingTable = ref(false)
const editingTableId = ref<string | null>(null)
const editingZoneId = ref<string | null>(null)
const TABLE_SHAPES = ['round', 'square', 'oval', 'rect'] as const
const tableForm = ref({ label: '', seats: '4', zone_id: '', shape: 'round' })
const zoneForm = ref({ name: '' })

const zones = computed(() => docs.value.filter(doc => doc.kind === 'zone'))
const tables = computed(() => docs.value.filter(doc => doc.kind === 'table'))
const tickets = computed(() => docs.value.filter(doc => doc.kind === 'ticket'))
const rooms = computed(() => docs.value.filter(doc => doc.kind === 'room'))
const reservations = computed(() => docs.value.filter(doc => doc.kind === 'reservation' && doc.status !== 'checked_out'))
const occupiedRooms = computed(() => rooms.value.filter(room => room.status === 'occupied'))
const freeTables = computed(() => tables.value.filter(table => table.status !== 'occupied'))
const occupiedTables = computed(() => tables.value.filter(table => table.status === 'occupied'))
const unzonedTables = computed(() => tables.value.filter(table => !table.zone_id || !zones.value.some(zone => zone.id === table.zone_id)))
const floorZones = computed(() =>
  zones.value.map(zone => ({
    ...zone,
    tables: tables.value.filter(table => table.zone_id === zone.id),
  })),
)

function tableShape(table: Doc) {
  if (table.shape === 'round' || table.shape === 'square' || table.shape === 'oval' || table.shape === 'rect') {
    return table.shape
  }
  const seats = Number(table.seats || 4)
  if (seats <= 2) return 'square'
  if (seats <= 4) return 'round'
  if (seats <= 6) return 'oval'
  return 'rect'
}

function chairCount(table: Doc) {
  return Math.min(8, Math.max(2, Number(table.seats || 4)))
}

function openCreateTable(zoneId = '') {
  editingTableId.value = null
  const seats = '4'
  tableForm.value = {
    label: nextTableLabel(),
    seats,
    zone_id: zoneId || zones.value[0]?.id || '',
    shape: tableShape({ seats }),
  }
  tableFormOpen.value = true
}

function onSeatsChange() {
  tableForm.value.shape = tableShape({ seats: tableForm.value.seats })
}

function nextTableLabel() {
  const used = new Set(tables.value.map(table => String(table.label || '').toLowerCase()))
  let index = tables.value.length + 1
  while (used.has(`t${index}`)) index += 1
  return `T${index}`
}

function openEditTable(table: Doc) {
  editingTableId.value = table.id
  tableForm.value = {
    label: table.label || '',
    seats: String(table.seats || 4),
    zone_id: table.zone_id || '',
    shape: tableShape(table),
  }
  tableFormOpen.value = true
}

function openCreateZone() {
  editingZoneId.value = null
  zoneForm.value = { name: '' }
  zoneFormOpen.value = true
}

function openEditZone(zone: Doc) {
  editingZoneId.value = zone.id
  zoneForm.value = { name: zone.name || '' }
  zoneFormOpen.value = true
}

async function saveTableForm() {
  if (!tableForm.value.label.trim()) return
  savingTable.value = true
  try {
    await run({
      action: 'upsert_table',
      id: editingTableId.value || undefined,
      label: tableForm.value.label.trim(),
      seats: Number(tableForm.value.seats) || 4,
      zone_id: tableForm.value.zone_id || '',
      shape: tableForm.value.shape,
    })
    tableFormOpen.value = false
  } finally {
    savingTable.value = false
  }
}

async function saveZoneForm() {
  if (!zoneForm.value.name.trim()) return
  savingTable.value = true
  try {
    await run({
      action: 'upsert_zone',
      id: editingZoneId.value || undefined,
      name: zoneForm.value.name.trim(),
    })
    zoneFormOpen.value = false
  } finally {
    savingTable.value = false
  }
}

async function removeTable(table: Doc) {
  if (table.status === 'occupied') {
    error.value = t('desk.tableOccupiedDelete')
    return
  }
  const ok = await confirmDialog(t('desk.deleteTableConfirm', { name: table.label }), {
    title: t('desk.deleteTable'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return
  await run({ action: 'delete_table', id: table.id })
}

async function removeZone(zone: Doc) {
  const ok = await confirmDialog(t('desk.deleteZoneConfirm', { name: zone.name }), {
    title: t('desk.deleteZone'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return
  await run({ action: 'delete_zone', id: zone.id })
}

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>('/hospitality')).data.docs
    if (order.value) order.value = docs.value.find(doc => doc.id === order.value?.id) ?? null
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function run(action: Record<string, unknown>) {
  error.value = ''
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', action)).data.docs
    if (order.value) order.value = docs.value.find(doc => doc.id === order.value?.id) ?? null
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function openTable(table: Doc) {
  if (table.status !== 'occupied') {
    await run({ action: 'open_order', table_id: table.id })
    const fresh = docs.value.find(doc => doc.id === table.id)
    order.value = docs.value.find(doc => doc.id === fresh?.order_id) ?? null
    return
  }
  order.value = docs.value.find(doc => doc.id === table.order_id) ?? null
}

async function addLine() {
  if (!order.value || !lineName.value.trim()) return
  await run({
    action: 'add_line',
    order_id: order.value.id,
    name: lineName.value.trim(),
    unit_price: Math.round(Number(linePrice.value || 0) * 100),
    quantity: 1,
    course: course.value,
  })
  lineName.value = ''
  linePrice.value = ''
}

function checkTotal(checkId: string) {
  return (order.value?.lines ?? [])
    .filter((line: Doc) => line.check_id === checkId)
    .reduce((sum: number, line: Doc) => sum + Number(line.unit_price || 0) * Number(line.quantity || 0), 0)
}

function folioTotal(room: Doc) {
  const folio = docs.value.find(doc => doc.id === room.folio_id)
  return (folio?.lines ?? []).reduce((sum: number, line: Doc) => sum + Number(line.amount || 0), 0)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('desk.hospitality') }}</template>
    <template #subtitle>{{ t('desk.hospitalityHint') }}</template>

    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="sub-nav">
          <button v-if="canRestaurant" type="button" class="sub-nav__link" :class="{ 'sub-nav__link--active': section === 'restaurant' }" @click="section = 'restaurant'">{{ t('desk.tables') }}</button>
          <button v-if="canRestaurant" type="button" class="sub-nav__link" :class="{ 'sub-nav__link--active': section === 'kitchen' }" @click="section = 'kitchen'">{{ t('desk.kitchen') }}</button>
          <button v-if="canHotel" type="button" class="sub-nav__link" :class="{ 'sub-nav__link--active': section === 'hotel' }" @click="section = 'hotel'">{{ t('desk.hotel') }}</button>
        </div>
        <button class="btn-secondary" :disabled="loading" @click="load">{{ t('common.refresh') }}</button>
      </div>
      <p v-if="error" class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{{ error }}</p>

      <div v-if="section === 'restaurant' && canRestaurant" class="space-y-5">
        <div class="floor-toolbar">
          <div class="floor-legend">
            <span class="floor-pill floor-pill--free">{{ t('desk.free') }} · {{ freeTables.length }}</span>
            <span class="floor-pill floor-pill--occupied">{{ t('desk.occupied') }} · {{ occupiedTables.length }}</span>
            <span class="floor-pill">{{ t('desk.tables') }} · {{ tables.length }}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <button type="button" class="btn-secondary" @click="openCreateZone">{{ t('desk.addZone') }}</button>
            <button type="button" class="btn-primary" @click="openCreateTable()">{{ t('desk.addTable') }}</button>
          </div>
        </div>

        <EmptyState
          v-if="!tables.length && !zones.length"
          icon="tables"
          :title="t('desk.emptyTables')"
          :description="t('desk.emptyTablesHint')"
        >
          <div class="mt-4 flex flex-wrap justify-center gap-2">
            <button type="button" class="btn-secondary" @click="openCreateZone">{{ t('desk.addZone') }}</button>
            <button type="button" class="btn-primary" @click="openCreateTable()">{{ t('desk.addTable') }}</button>
          </div>
        </EmptyState>

        <section v-for="zone in floorZones" :key="zone.id" class="floor-zone">
          <header class="floor-zone__head">
            <div>
              <h3>{{ zone.name }}</h3>
              <p>{{ t('desk.zoneTableCount', { count: zone.tables.length }) }}</p>
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button type="button" class="btn-secondary" @click="openCreateTable(zone.id)">{{ t('desk.addTable') }}</button>
              <button
                type="button"
                class="floor-icon-btn"
                :aria-label="t('common.edit')"
                :title="t('common.edit')"
                @click="openEditZone(zone)"
              >
                <AppIcon name="edit" :size="15" />
              </button>
              <button
                type="button"
                class="floor-icon-btn floor-icon-btn--danger"
                :aria-label="t('common.delete')"
                :title="t('common.delete')"
                @click="removeZone(zone)"
              >
                <AppIcon name="trash" :size="15" />
              </button>
            </div>
          </header>
          <div v-if="zone.tables.length" class="floor-grid">
            <article
              v-for="table in zone.tables"
              :key="table.id"
              class="floor-table"
              :class="[`floor-table--${tableShape(table)}`, table.status === 'occupied' ? 'floor-table--occupied' : 'floor-table--free']"
            >
              <button type="button" class="floor-table__hit" @click="openTable(table)">
                <span class="floor-table__chairs" aria-hidden="true">
                  <i v-for="n in chairCount(table)" :key="n" class="floor-table__chair" />
                </span>
                <span class="floor-table__top">
                  <strong>{{ table.label }}</strong>
                  <em>{{ table.seats }} {{ t('desk.seats') }}</em>
                </span>
              </button>
              <div class="floor-table__meta">
                <Badge :variant="table.status === 'occupied' ? 'warning' : 'success'">
                  {{ table.status === 'occupied' ? t('desk.occupied') : t('desk.free') }}
                </Badge>
                <div class="floor-table__actions">
                  <button
                    type="button"
                    class="floor-icon-btn"
                    :aria-label="t('common.edit')"
                    :title="t('common.edit')"
                    @click="openEditTable(table)"
                  >
                    <AppIcon name="edit" :size="14" />
                  </button>
                  <button
                    type="button"
                    class="floor-icon-btn floor-icon-btn--danger"
                    :aria-label="t('common.delete')"
                    :title="t('common.delete')"
                    @click="removeTable(table)"
                  >
                    <AppIcon name="trash" :size="14" />
                  </button>
                </div>
              </div>
            </article>
          </div>
          <p v-else class="floor-zone__empty">{{ t('desk.zoneEmpty') }}</p>
        </section>

        <section v-if="unzonedTables.length" class="floor-zone">
          <header class="floor-zone__head">
            <div>
              <h3>{{ t('desk.noZone') }}</h3>
              <p>{{ t('desk.zoneTableCount', { count: unzonedTables.length }) }}</p>
            </div>
          </header>
          <div class="floor-grid">
            <article
              v-for="table in unzonedTables"
              :key="table.id"
              class="floor-table"
              :class="[`floor-table--${tableShape(table)}`, table.status === 'occupied' ? 'floor-table--occupied' : 'floor-table--free']"
            >
              <button type="button" class="floor-table__hit" @click="openTable(table)">
                <span class="floor-table__chairs" aria-hidden="true">
                  <i v-for="n in chairCount(table)" :key="n" class="floor-table__chair" />
                </span>
                <span class="floor-table__top">
                  <strong>{{ table.label }}</strong>
                  <em>{{ table.seats }} {{ t('desk.seats') }}</em>
                </span>
              </button>
              <div class="floor-table__meta">
                <Badge :variant="table.status === 'occupied' ? 'warning' : 'success'">
                  {{ table.status === 'occupied' ? t('desk.occupied') : t('desk.free') }}
                </Badge>
                <div class="floor-table__actions">
                  <button
                    type="button"
                    class="floor-icon-btn"
                    :aria-label="t('common.edit')"
                    :title="t('common.edit')"
                    @click="openEditTable(table)"
                  >
                    <AppIcon name="edit" :size="14" />
                  </button>
                  <button
                    type="button"
                    class="floor-icon-btn floor-icon-btn--danger"
                    :aria-label="t('common.delete')"
                    :title="t('common.delete')"
                    @click="removeTable(table)"
                  >
                    <AppIcon name="trash" :size="14" />
                  </button>
                </div>
              </div>
            </article>
          </div>
        </section>
      </div>

      <div v-else-if="section === 'kitchen' && canRestaurant" class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <article v-for="ticket in tickets" :key="ticket.id" class="rounded-2xl border border-slate-200 bg-white p-4">
          <p class="m-0 text-xs uppercase tracking-wide text-slate-400">{{ ticket.table_label }} · {{ ticket.course }}</p>
          <p class="mt-1 font-semibold">{{ ticket.status }}</p>
          <ul class="mt-2 space-y-1 text-sm">
            <li v-for="(line, index) in ticket.lines" :key="index">{{ line.quantity }} × {{ line.name }}</li>
          </ul>
          <div class="mt-3 flex flex-wrap gap-2">
            <button v-if="ticket.status === 'sent'" class="btn-secondary" @click="run({ action: 'set_ticket_status', ticket_id: ticket.id, status: 'preparing' })">{{ t('desk.preparing') }}</button>
            <button v-if="ticket.status === 'preparing'" class="btn-secondary" @click="run({ action: 'set_ticket_status', ticket_id: ticket.id, status: 'ready' })">{{ t('desk.ready') }}</button>
            <button v-if="ticket.status === 'ready'" class="btn-primary" @click="run({ action: 'set_ticket_status', ticket_id: ticket.id, status: 'served' })">{{ t('desk.served') }}</button>
          </div>
        </article>
        <p v-if="!tickets.length" class="text-sm text-slate-500">{{ t('desk.noTickets') }}</p>
      </div>

      <div v-else-if="canHotel" class="grid gap-4 lg:grid-cols-2">
        <article v-for="room in rooms" :key="room.id" class="rounded-2xl border border-slate-200 bg-white p-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h3 class="m-0">{{ t('desk.room') }} {{ room.number }}</h3>
              <p class="m-0 text-sm text-slate-500">{{ room.status }}<span v-if="room.guest_name"> · {{ room.guest_name }}</span></p>
            </div>
            <strong v-if="room.folio_id">{{ formatMoney(folioTotal(room)) }}</strong>
          </div>
          <div v-if="room.status === 'vacant'" class="mt-3">
            <button class="btn-secondary" @click="roomId = room.id">{{ t('desk.reserve') }}</button>
          </div>
          <div v-else-if="room.status === 'occupied'" class="mt-3 grid gap-2 sm:grid-cols-[1fr_8rem_auto]">
            <select v-model="folioKind" class="field">
              <option value="minibar">{{ t('desk.minibar') }}</option>
              <option value="room_service">{{ t('desk.roomService') }}</option>
            </select>
            <input v-model="folioAmount" type="number" min="0" class="field" :placeholder="t('desk.price')" />
            <button class="btn-secondary" @click="run({ action: 'post_folio', room_id: room.id, kind: folioKind, amount: Math.round(Number(folioAmount || 0) * 100), description: folioKind === 'minibar' ? t('desk.minibar') : t('desk.roomService') })">{{ t('desk.postCharge') }}</button>
          </div>
        </article>
        <article v-for="stay in reservations" :key="stay.id" class="rounded-2xl border border-slate-200 bg-white p-4">
          <h3 class="m-0">{{ stay.guest_name }}</h3>
          <p class="m-0 text-sm text-slate-500">{{ t('desk.room') }} {{ stay.room_number }} · {{ stay.status }}</p>
          <div class="mt-3 flex gap-2">
            <button v-if="stay.status === 'reserved'" class="btn-primary" @click="run({ action: 'check_in', reservation_id: stay.id })">{{ t('desk.checkIn') }}</button>
            <button v-if="stay.status === 'checked_in'" class="btn-secondary" @click="run({ action: 'check_out', reservation_id: stay.id })">{{ t('desk.checkOut') }}</button>
          </div>
        </article>
      </div>
    </div>

    <AppModal :open="Boolean(order)" :title="order ? `${t('desk.table')} ${order.table_label}` : ''" size="lg" icon="store-pin" @close="order = null">
      <div v-if="order" class="space-y-4">
        <div v-for="check in order.checks" :key="check.id" class="rounded-xl border border-slate-200 p-3">
          <div class="flex items-center justify-between">
            <strong>{{ check.label }}</strong>
            <span>{{ check.status }} · {{ formatMoney(checkTotal(check.id)) }}</span>
          </div>
          <ul class="mt-2 space-y-1 text-sm">
            <li v-for="line in (order.lines || []).filter((item: Doc) => item.check_id === check.id)" :key="line.id">
              {{ line.quantity }} × {{ line.name }} · {{ formatMoney(line.unit_price) }}
            </li>
          </ul>
          <div v-if="check.status === 'open'" class="mt-3 flex flex-wrap gap-2">
            <button class="btn-primary" @click="run({ action: 'pay_check', order_id: order.id, check_id: check.id })">{{ t('desk.pay') }}</button>
            <button v-if="occupiedRooms.length" class="btn-secondary" @click="run({ action: 'charge_room', order_id: order.id, check_id: check.id, room_id: occupiedRooms[0].id })">{{ t('desk.chargeRoom') }}</button>
            <button class="btn-secondary" @click="run({ action: 'send_course', order_id: order.id, course })">{{ t('desk.sendKitchen') }}</button>
          </div>
        </div>
        <div class="grid gap-3 sm:grid-cols-3">
          <div class="sm:col-span-1"><FieldLabel icon="products">{{ t('desk.item') }}</FieldLabel><input v-model="lineName" class="field" /></div>
          <div><FieldLabel icon="coins">{{ t('desk.price') }}</FieldLabel><input v-model="linePrice" type="number" min="0" class="field" /></div>
          <div>
            <FieldLabel icon="layers">{{ t('desk.course') }}</FieldLabel>
            <select v-model="course" class="field">
              <option value="entree">{{ t('desk.starter') }}</option>
              <option value="plat">{{ t('desk.main') }}</option>
              <option value="dessert">{{ t('desk.dessert') }}</option>
            </select>
          </div>
        </div>
        <button class="btn-primary" @click="addLine">{{ t('desk.addLine') }}</button>
      </div>
    </AppModal>

    <AppModal
      :open="tableFormOpen"
      :title="editingTableId ? t('desk.editTable') : t('desk.addTable')"
      icon="tables"
      size="md"
      @close="tableFormOpen = false"
    >
      <form id="table-form" class="table-form" @submit.prevent="saveTableForm">
        <div class="table-form__preview">
          <article class="floor-table floor-table--preview" :class="[`floor-table--${tableForm.shape}`, 'floor-table--free']">
            <div class="floor-table__hit">
              <span class="floor-table__chairs" aria-hidden="true">
                <i v-for="n in Math.min(8, Math.max(2, Number(tableForm.seats) || 4))" :key="n" class="floor-table__chair" />
              </span>
              <span class="floor-table__top">
                <strong>{{ tableForm.label || t('desk.table') }}</strong>
                <em>{{ tableForm.seats || 0 }} {{ t('desk.seats') }}</em>
              </span>
            </div>
          </article>
          <p class="table-form__hint">{{ t('desk.tableFormHint') }}</p>
        </div>

        <div class="table-form__fields">
          <div>
            <FieldLabel icon="tables">{{ t('desk.tableName') }}</FieldLabel>
            <input v-model="tableForm.label" required class="field" maxlength="40" />
          </div>

          <div class="table-form__row">
            <div>
              <FieldLabel icon="account">{{ t('desk.capacity') }}</FieldLabel>
              <input v-model="tableForm.seats" type="number" min="1" max="40" class="field" @change="onSeatsChange" />
            </div>
            <div>
              <FieldLabel icon="layers">{{ t('desk.zone') }}</FieldLabel>
              <select v-model="tableForm.zone_id" class="field">
                <option value="">{{ t('desk.noZone') }}</option>
                <option v-for="zone in zones" :key="zone.id" :value="zone.id">{{ zone.name }}</option>
              </select>
            </div>
          </div>

          <div>
            <FieldLabel icon="adjust">{{ t('desk.tableShape') }}</FieldLabel>
            <div class="table-form__shapes">
              <label
                v-for="shape in TABLE_SHAPES"
                :key="shape"
                class="table-form__shape"
                :class="{ 'is-active': tableForm.shape === shape }"
              >
                <input v-model="tableForm.shape" type="radio" class="sr-only" :value="shape" />
                <span class="table-form__shape-top" :class="`table-form__shape-top--${shape}`" />
                {{ t(`desk.shapes.${shape}`) }}
              </label>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <button type="button" class="btn-secondary" @click="tableFormOpen = false">{{ t('common.cancel') }}</button>
        <button type="submit" form="table-form" class="btn-primary" :disabled="savingTable">{{ t('common.save') }}</button>
      </template>
    </AppModal>

    <AppModal :open="zoneFormOpen" :title="editingZoneId ? t('desk.editZone') : t('desk.addZone')" icon="layers" size="sm" @close="zoneFormOpen = false">
      <form id="zone-form" class="table-form table-form--simple" @submit.prevent="saveZoneForm">
        <div>
          <FieldLabel icon="layers">{{ t('desk.zoneName') }}</FieldLabel>
          <input v-model="zoneForm.name" required class="field" maxlength="80" />
        </div>
      </form>
      <template #footer>
        <button type="button" class="btn-secondary" @click="zoneFormOpen = false">{{ t('common.cancel') }}</button>
        <button type="submit" form="zone-form" class="btn-primary" :disabled="savingTable">{{ t('common.save') }}</button>
      </template>
    </AppModal>

    <AppModal :open="Boolean(roomId)" :title="t('desk.reserve')" icon="customers" @close="roomId = ''">
      <form class="space-y-3" @submit.prevent="run({ action: 'create_reservation', room_id: roomId, guest_name: guest }).then(() => { roomId = ''; guest = '' })">
        <div><FieldLabel icon="customers">{{ t('desk.guest') }}</FieldLabel><input v-model="guest" required class="field" /></div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="roomId = ''">{{ t('common.cancel') }}</button>
          <button class="btn-primary">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.floor-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.floor-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}
.floor-pill {
  display: inline-flex;
  align-items: center;
  min-height: 32px;
  padding: 0 12px;
  border-radius: 999px;
  background: #f1f5f9;
  color: #475569;
  font-size: 13px;
  font-weight: 600;
}
.floor-pill--free { background: #ecfdf5; color: #047857; }
.floor-pill--occupied { background: #fff7ed; color: #c2410c; }
.floor-zone {
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  background: #fff;
  padding: 16px;
}
.floor-zone__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}
.floor-zone__head h3 {
  margin: 0;
  font-size: 16px;
  color: #0f172a;
}
.floor-zone__head p,
.floor-zone__empty {
  margin: 2px 0 0;
  font-size: 13px;
  color: #64748b;
}
.floor-zone__empty { margin: 0; }
.floor-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(176px, 1fr));
  gap: 16px;
}
.floor-table {
  display: grid;
  gap: 10px;
  padding: 12px;
  border-radius: 16px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.floor-table--free { background: #f0fdf4; border-color: #bbf7d0; }
.floor-table--occupied { background: #fffbeb; border-color: #fde68a; }
.floor-table__hit {
  position: relative;
  display: grid;
  place-items: center;
  min-height: 132px;
  border: 0;
  background: transparent;
  cursor: pointer;
}
.floor-table__chairs {
  position: absolute;
  inset: 6px;
  pointer-events: none;
}
.floor-table__chair {
  position: absolute;
  width: 18px;
  height: 9px;
  border-radius: 3px;
  background: #94a3b8;
}
.floor-table__chair:nth-child(1) { top: 0; left: 50%; transform: translateX(-50%); }
.floor-table__chair:nth-child(2) { bottom: 0; left: 50%; transform: translateX(-50%); }
.floor-table__chair:nth-child(3) { left: 0; top: 50%; transform: translateY(-50%) rotate(90deg); }
.floor-table__chair:nth-child(4) { right: 0; top: 50%; transform: translateY(-50%) rotate(90deg); }
.floor-table__chair:nth-child(5) { top: 0; left: 28%; transform: translateX(-50%); }
.floor-table__chair:nth-child(6) { top: 0; left: 72%; transform: translateX(-50%); }
.floor-table__chair:nth-child(7) { bottom: 0; left: 28%; transform: translateX(-50%); }
.floor-table__chair:nth-child(8) { bottom: 0; left: 72%; transform: translateX(-50%); }
.floor-table__top {
  position: relative;
  z-index: 1;
  display: grid;
  place-items: center;
  gap: 2px;
  width: 92px;
  height: 92px;
  border-radius: 50%;
  background: #fff;
  border: 2px solid #cbd5e1;
  box-shadow: inset 0 1px 0 #fff, 0 8px 16px rgb(15 23 42 / 0.08);
  color: #0f172a;
}
.floor-table--square .floor-table__top { border-radius: 14px; }
.floor-table--oval .floor-table__top { width: 118px; height: 78px; border-radius: 999px; }
.floor-table--rect .floor-table__top { width: 124px; height: 70px; border-radius: 16px; }
.floor-table--free .floor-table__top { border-color: #34d399; }
.floor-table--occupied .floor-table__top { border-color: #f59e0b; }
.floor-table__top strong {
  font-size: 15px;
  line-height: 1.1;
}
.floor-table__top em {
  font-style: normal;
  font-size: 11px;
  color: #64748b;
}
.floor-table__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.floor-table__actions {
  display: flex;
  gap: 4px;
}
.floor-icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  padding: 0;
  border: 1px solid #e2e8f0;
  border-radius: 0.55rem;
  background: #fff;
  color: var(--color-brand-600, #0f766e);
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease;
}
.floor-icon-btn:hover {
  background: #f0fdfa;
  border-color: color-mix(in srgb, var(--color-brand-600, #0f766e) 35%, #e2e8f0);
}
.floor-icon-btn--danger {
  color: #dc2626;
}
.floor-icon-btn--danger:hover {
  background: #fef2f2;
  border-color: #fecaca;
}
.table-form {
  display: grid;
  gap: 1rem;
}
.table-form:not(.table-form--simple) {
  grid-template-columns: 168px minmax(0, 1fr);
  gap: 0.85rem 1.1rem;
  align-items: stretch;
}
.table-form--simple {
  display: block;
}
.table-form__fields {
  display: grid;
  gap: 0.85rem;
  min-width: 0;
}
.table-form__preview {
  display: grid;
  justify-items: center;
  align-content: center;
  gap: 0.45rem;
  padding: 0.7rem 0.5rem;
  border: 1px dashed #d6dee6;
  border-radius: 0.9rem;
  background: #f7f9fb;
}
.table-form__hint {
  margin: 0;
  font-size: 0.75rem;
  line-height: 1.35;
  color: #64748b;
  text-align: center;
}
.floor-table--preview {
  width: 100%;
  max-width: 148px;
  padding: 0;
  border: 0;
  background: transparent;
}
.floor-table--preview .floor-table__hit {
  min-height: 96px;
  cursor: default;
}
.floor-table--preview .floor-table__top {
  width: 76px;
  height: 76px;
}
.floor-table--preview.floor-table--oval .floor-table__top {
  width: 96px;
  height: 62px;
}
.floor-table--preview.floor-table--rect .floor-table__top {
  width: 102px;
  height: 56px;
}
.table-form__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}
.table-form__shapes {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.5rem;
}
.table-form__shape {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 2.5rem;
  padding: 0.4rem 0.65rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  color: #334155;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}
.table-form__shape.is-active {
  border-color: var(--color-brand-600);
  background: color-mix(in srgb, var(--color-brand-500) 8%, white);
  box-shadow: 0 0 0 1px var(--color-brand-600);
}
.table-form__shape-top {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
  border: 2px solid currentColor;
  border-radius: 50%;
}
.table-form__shape-top--square { border-radius: 4px; }
.table-form__shape-top--oval { width: 20px; height: 13px; border-radius: 999px; }
.table-form__shape-top--rect { width: 20px; height: 11px; border-radius: 4px; }
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
}
@media (max-width: 480px) {
  .table-form:not(.table-form--simple) {
    grid-template-columns: 1fr;
  }
  .table-form__row {
    grid-template-columns: 1fr;
  }
}
</style>

