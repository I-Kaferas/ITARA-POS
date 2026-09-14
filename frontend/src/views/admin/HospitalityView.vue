<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import AppModal from '../../components/ui/AppModal.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { formatMoney } from '../../utils/format'
import { useAuthStore } from '../../stores/auth'

type Doc = Record<string, any>
const { t } = useI18n()
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

const zones = computed(() => docs.value.filter(doc => doc.kind === 'zone'))
const tables = computed(() => docs.value.filter(doc => doc.kind === 'table'))
const tickets = computed(() => docs.value.filter(doc => doc.kind === 'ticket'))
const rooms = computed(() => docs.value.filter(doc => doc.kind === 'room'))
const reservations = computed(() => docs.value.filter(doc => doc.kind === 'reservation' && doc.status !== 'checked_out'))
const occupiedRooms = computed(() => rooms.value.filter(room => room.status === 'occupied'))

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
  <AdminLayout>
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
        <section v-for="zone in zones" :key="zone.id">
          <h3 class="mb-2 text-sm font-semibold text-slate-500">{{ zone.name }}</h3>
          <div class="flex flex-wrap gap-3">
            <button
              v-for="table in tables.filter(item => item.zone_id === zone.id)"
              :key="table.id"
              type="button"
              class="w-36 rounded-2xl border p-3 text-left"
              :class="table.status === 'occupied' ? 'border-amber-200 bg-amber-50' : 'border-emerald-200 bg-emerald-50'"
              @click="openTable(table)"
            >
              <strong>{{ table.label }}</strong>
              <p class="m-0 text-xs text-slate-500">{{ table.status === 'occupied' ? t('desk.occupied') : t('desk.free') }} · {{ table.seats }} {{ t('desk.seats') }}</p>
            </button>
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

    <AppModal :open="Boolean(roomId)" :title="t('desk.reserve')" icon="customers" @close="roomId = ''">
      <form class="space-y-3" @submit.prevent="run({ action: 'create_reservation', room_id: roomId, guest_name: guest }).then(() => { roomId = ''; guest = '' })">
        <div><FieldLabel icon="customers">{{ t('desk.guest') }}</FieldLabel><input v-model="guest" required class="field" /></div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="roomId = ''">{{ t('common.cancel') }}</button>
          <button class="btn-primary">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>
