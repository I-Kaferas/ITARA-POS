<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDateTime } from '../../../utils/format'

type ReservationStatus = 'pending' | 'confirmed' | 'seated' | 'completed' | 'cancelled' | 'no_show'

interface PosTableOption {
  id: string
  name: string
  code?: string
  capacity: number
  status: string
  is_active: boolean
}

interface PosReservation {
  id: string
  reference: string
  guest_name: string
  phone?: string | null
  party_size: number
  reserved_at: string
  table_label?: string | null
  table_id?: string | null
  status: ReservationStatus
  notes?: string | null
  customer_id?: string | null
  customer?: { id: string; name: string; phone?: string | null } | null
}

const STATUSES: ReservationStatus[] = ['pending', 'confirmed', 'seated', 'completed', 'cancelled', 'no_show']

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const loading = ref(false)
const saving = ref(false)
const actionId = ref<string | null>(null)
const error = ref('')
const notice = ref('')
const reservations = ref<PosReservation[]>([])
const tables = ref<PosTableOption[]>([])
const showForm = ref(false)
const editingId = ref<string | null>(null)
const statusSavingId = ref<string | null>(null)

const filters = ref({
  q: '',
  status: '',
  from: '',
  to: '',
})

const form = ref({
  mode: 'walkin' as 'walkin' | 'customer',
  customer_id: '',
  guest_name: '',
  phone: '',
  party_size: '2',
  reserved_at: '',
  table_id: '',
  table_label: '',
  status: 'pending' as ReservationStatus,
  notes: '',
})

const canSave = computed(() => {
  if (!form.value.reserved_at) return false
  if (form.value.mode === 'customer') return Boolean(form.value.customer_id)
  return Boolean(form.value.guest_name.trim())
})

const statusOptions = computed(() => [
  { value: '', label: t('pointOfSale.reservations.allStatuses') },
  ...STATUSES.map(value => ({ value, label: statusLabel(value) })),
])

const selectableTables = computed(() =>
  tables.value.filter(table => table.is_active !== false && table.status !== 'inactive'),
)

function statusLabel(status: string): string {
  const key = `pointOfSale.reservations.status.${status}`
  const label = t(key)
  return label === key ? status : label
}

function statusVariant(status: string): 'success' | 'neutral' | 'brand' | 'warning' {
  if (status === 'confirmed' || status === 'seated') return 'brand'
  if (status === 'completed') return 'success'
  if (status === 'cancelled' || status === 'no_show') return 'neutral'
  return 'warning'
}

function toLocalInput(value?: string | null): string {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function defaultReservedAt(): string {
  const date = new Date()
  date.setMinutes(0, 0, 0)
  date.setHours(date.getHours() + 1)
  return toLocalInput(date.toISOString())
}

function queryString(): string {
  const params = new URLSearchParams()
  if (filters.value.q.trim()) params.set('q', filters.value.q.trim())
  if (filters.value.status) params.set('status', filters.value.status)
  if (filters.value.from) params.set('from', filters.value.from)
  if (filters.value.to) params.set('to', filters.value.to)
  const qs = params.toString()
  return qs ? `?${qs}` : ''
}

async function loadTables() {
  if (!storeId.value) return
  try {
    const res = await api.get<{ data: { tables: PosTableOption[] } }>(`/stores/${storeId.value}/pos/tables`)
    tables.value = res.data?.tables ?? []
  } catch {
    tables.value = []
  }
}

async function load() {
  if (!storeId.value) return
  loading.value = true
  error.value = ''
  try {
    if (!store.customers.length) await store.loadCustomers()
    await loadTables()
    reservations.value = (await api.get<{ data: PosReservation[] }>(
      `/stores/${storeId.value}/pos/reservations${queryString()}`,
    )).data
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.reservations.loadError'))
  } finally {
    loading.value = false
  }
}

function resetFilters() {
  filters.value = { q: '', status: '', from: '', to: '' }
  void load()
}

function openCreate() {
  editingId.value = null
  form.value = {
    mode: 'walkin',
    customer_id: '',
    guest_name: '',
    phone: '',
    party_size: '2',
    reserved_at: defaultReservedAt(),
    table_id: '',
    table_label: '',
    status: 'pending',
    notes: '',
  }
  showForm.value = true
}

function openEdit(item: PosReservation) {
  editingId.value = item.id
  form.value = {
    mode: item.customer_id ? 'customer' : 'walkin',
    customer_id: item.customer_id ?? '',
    guest_name: item.guest_name,
    phone: item.phone ?? '',
    party_size: String(item.party_size),
    reserved_at: toLocalInput(item.reserved_at),
    table_id: item.table_id ?? '',
    table_label: item.table_label ?? '',
    status: item.status,
    notes: item.notes ?? '',
  }
  showForm.value = true
}

function onTableSelected() {
  const table = tables.value.find(item => item.id === form.value.table_id)
  if (table) form.value.table_label = table.name
}

function payload() {
  const partySize = Number(form.value.party_size)
  const table = tables.value.find(item => item.id === form.value.table_id)
  return {
    customer_id: form.value.mode === 'customer' && form.value.customer_id ? form.value.customer_id : null,
    guest_name: form.value.guest_name.trim() || null,
    phone: form.value.phone.trim() || null,
    party_size: Number.isFinite(partySize) ? partySize : 1,
    reserved_at: new Date(form.value.reserved_at).toISOString(),
    table_id: form.value.table_id || null,
    table_label: form.value.table_label.trim() || table?.name || null,
    status: form.value.status,
    notes: form.value.notes.trim() || null,
  }
}

async function save() {
  if (!storeId.value || !form.value.reserved_at) return
  saving.value = true
  error.value = ''
  try {
    const body = payload()
    if (editingId.value) {
      await api.patch(`/pos-reservations/${editingId.value}`, body)
    } else {
      await api.post(`/stores/${storeId.value}/pos/reservations`, body)
    }
    showForm.value = false
    await load()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.reservations.saveError'))
  } finally {
    saving.value = false
  }
}

async function changeStatus(item: PosReservation, status: ReservationStatus) {
  if (item.status === status) return
  statusSavingId.value = item.id
  error.value = ''
  notice.value = ''
  try {
    await api.patch(`/pos-reservations/${item.id}/status`, { status })
    item.status = status
    notice.value = t('pointOfSale.reservations.statusUpdated')
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.reservations.saveError'))
    await load()
  } finally {
    statusSavingId.value = null
  }
}

function canConfirm(item: PosReservation) {
  return item.status === 'pending'
}

function canSeat(item: PosReservation) {
  return (item.status === 'pending' || item.status === 'confirmed') && Boolean(item.table_id)
}

function canComplete(item: PosReservation) {
  return item.status === 'seated' || item.status === 'confirmed'
}

function canCancel(item: PosReservation) {
  return !['completed', 'cancelled', 'no_show'].includes(item.status)
}

async function seatReservation(item: PosReservation) {
  if (!storeId.value || !item.table_id) {
    error.value = t('pointOfSale.reservations.needTable')
    return
  }
  actionId.value = item.id
  error.value = ''
  notice.value = ''
  try {
    if (item.status === 'pending') {
      await api.patch(`/pos-reservations/${item.id}/status`, { status: 'confirmed' })
    }
    const res = await api.post<{ data: { sale: { id: string } } }>(
      `/stores/${storeId.value}/pos/tables/${item.table_id}/open`,
      { confirm_reserved: true },
    )
    const saleId = res.data.sale.id
    await router.push({ name: 'pos', query: { sale: saleId, table: item.table_id } })
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.reservations.seatError'))
    await load()
  } finally {
    actionId.value = null
  }
}

onMounted(load)
watch(storeId, load)
watchLiveSearch(() => filters.value.q, load)
watch(
  () => [filters.value.status, filters.value.from, filters.value.to],
  load,
)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posReservations') }}</template>
    <template #subtitle>{{ t('pointOfSale.reservations.subtitle') }}</template>

    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('pointOfSale.reservations.needStore') }}
    </div>

    <template v-else>
      <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div class="max-w-2xl space-y-1">
          <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.reservations.intro') }}</p>
          <p class="m-0 text-xs text-slate-400">{{ t('pointOfSale.reservations.flowHint') }}</p>
        </div>
        <div class="flex flex-wrap gap-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="router.push({ name: 'pos-tables' })">
            {{ t('pointOfSale.reservations.openFloor') }}
          </button>
          <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
            {{ t('pointOfSale.reservations.add') }}
          </button>
        </div>
      </div>

      <div class="mb-4 rounded-xl border border-slate-200 bg-white p-4">
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-5">
          <div class="xl:col-span-2">
            <FieldLabel icon="search">{{ t('common.search') }}</FieldLabel>
            <div class="relative">
              <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="filters.q"
                type="search"
                class="ui-input !pl-8 w-full"
                :placeholder="t('pointOfSale.orders.filters.searchPlaceholder')"
              />
            </div>
          </div>
          <div>
            <FieldLabel icon="filter">{{ t('pointOfSale.reservations.statusLabel') }}</FieldLabel>
            <select v-model="filters.status" class="ui-select w-full">
              <option v-for="opt in statusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('pointOfSale.orders.filters.from') }}</FieldLabel>
            <input v-model="filters.from" type="date" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('pointOfSale.orders.filters.to') }}</FieldLabel>
            <input v-model="filters.to" type="date" class="ui-input w-full" />
          </div>
        </div>
        <div class="mt-3 flex flex-wrap gap-2">
          <button type="button" class="ui-btn ui-btn--primary" :disabled="loading" @click="load">
            {{ t('pointOfSale.orders.filters.apply') }}
          </button>
          <button type="button" class="ui-btn ui-btn--secondary" @click="resetFilters">
            {{ t('pointOfSale.orders.filters.reset') }}
          </button>
        </div>
      </div>

      <p v-if="error" class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>
      <p v-if="notice" class="mb-4 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">{{ notice }}</p>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('pointOfSale.reservations.listTitle') }}</h3>
        </div>

        <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />

        <table v-else-if="reservations.length" class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.reference') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.guest') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.when') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.reservations.party') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.table') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.statusLabel') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.reservations.actions') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in reservations" :key="item.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ item.reference }}</td>
              <td class="px-4 py-3">
                <div>{{ item.guest_name }}</div>
                <div v-if="item.phone" class="text-xs text-slate-500">{{ item.phone }}</div>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ formatDateTime(item.reserved_at) }}</td>
              <td class="px-4 py-3 text-right">{{ item.party_size }}</td>
              <td class="px-4 py-3">{{ item.table_label || '—' }}</td>
              <td class="px-4 py-3">
                <Badge :variant="statusVariant(item.status)">{{ statusLabel(item.status) }}</Badge>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap justify-end gap-1.5">
                  <button
                    v-if="canConfirm(item)"
                    type="button"
                    class="ui-btn ui-btn--secondary ui-btn--sm"
                    :disabled="statusSavingId === item.id"
                    @click="changeStatus(item, 'confirmed')"
                  >
                    {{ t('pointOfSale.reservations.confirm') }}
                  </button>
                  <button
                    v-if="canSeat(item)"
                    type="button"
                    class="ui-btn ui-btn--primary ui-btn--sm"
                    :disabled="actionId === item.id"
                    @click="seatReservation(item)"
                  >
                    {{ actionId === item.id ? '…' : t('pointOfSale.reservations.seat') }}
                  </button>
                  <button
                    v-if="canComplete(item)"
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    :disabled="statusSavingId === item.id"
                    @click="changeStatus(item, 'completed')"
                  >
                    {{ t('pointOfSale.reservations.complete') }}
                  </button>
                  <button
                    v-if="canCancel(item)"
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    :disabled="statusSavingId === item.id"
                    @click="changeStatus(item, 'cancelled')"
                  >
                    {{ t('pointOfSale.reservations.cancel') }}
                  </button>
                  <button
                    v-if="canCancel(item)"
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    :disabled="statusSavingId === item.id"
                    @click="changeStatus(item, 'no_show')"
                  >
                    {{ t('pointOfSale.reservations.noShow') }}
                  </button>
                  <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="openEdit(item)">
                    {{ t('common.edit') }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <EmptyState
          v-else
          icon="note"
          :title="t('pointOfSale.reservations.empty')"
          :description="t('pointOfSale.reservations.emptyHint')"
        >
          <button type="button" class="ui-btn ui-btn--primary mt-4" @click="openCreate">
            {{ t('pointOfSale.reservations.add') }}
          </button>
        </EmptyState>
      </div>
    </template>

    <AppModal
      :open="showForm"
      size="xl"
      icon="note"
      :title="editingId ? t('common.edit') : t('pointOfSale.reservations.add')"
      @close="showForm = false"
    >
      <div class="space-y-3">
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="ui-btn ui-btn--sm"
            :class="form.mode === 'walkin' ? 'ui-btn--primary' : 'ui-btn--secondary'"
            @click="form.mode = 'walkin'"
          >
            {{ t('pointOfSale.reservations.walkIn') }}
          </button>
          <button
            type="button"
            class="ui-btn ui-btn--sm"
            :class="form.mode === 'customer' ? 'ui-btn--primary' : 'ui-btn--secondary'"
            @click="form.mode = 'customer'"
          >
            {{ t('pointOfSale.reservations.customer') }}
          </button>
        </div>

        <div v-if="form.mode === 'customer'">
          <FieldLabel icon="customers">{{ t('pointOfSale.reservations.customer') }}</FieldLabel>
          <select v-model="form.customer_id" class="ui-select w-full">
            <option value="">—</option>
            <option v-for="customer in store.customers" :key="customer.id" :value="customer.id">
              {{ customer.name }}
            </option>
          </select>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="account">{{ t('pointOfSale.reservations.guest') }}</FieldLabel>
            <input v-model="form.guest_name" type="text" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="phone">{{ t('pointOfSale.reservations.phone') }}</FieldLabel>
            <input v-model="form.phone" type="text" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('pointOfSale.reservations.when') }}</FieldLabel>
            <input v-model="form.reserved_at" type="datetime-local" class="ui-input w-full" required />
          </div>
          <div>
            <FieldLabel icon="organization">{{ t('pointOfSale.reservations.party') }}</FieldLabel>
            <input v-model="form.party_size" type="number" min="1" max="200" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="tables">{{ t('pointOfSale.reservations.table') }}</FieldLabel>
            <select v-model="form.table_id" class="ui-select w-full" @change="onTableSelected">
              <option value="">{{ t('pointOfSale.reservations.noTable') }}</option>
              <option v-for="table in selectableTables" :key="table.id" :value="table.id">
                {{ table.name }} · {{ table.capacity }} {{ t('pointOfSale.reservations.seats') }}
                <template v-if="table.status !== 'available'"> ({{ table.status }})</template>
              </option>
            </select>
          </div>
          <div>
            <FieldLabel icon="filter">{{ t('pointOfSale.reservations.statusLabel') }}</FieldLabel>
            <select v-model="form.status" class="ui-select w-full">
              <option v-for="status in STATUSES" :key="status" :value="status">{{ statusLabel(status) }}</option>
            </select>
          </div>
        </div>

        <div>
          <FieldLabel icon="note">{{ t('pointOfSale.reservations.notes') }}</FieldLabel>
          <textarea v-model="form.notes" rows="2" class="ui-input w-full" />
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="ui-btn ui-btn--secondary" @click="showForm = false">{{ t('common.cancel') }}</button>
          <button
            type="button"
            class="ui-btn ui-btn--primary"
            :disabled="saving || !canSave"
            @click="save"
          >
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </div>
    </AppModal>
  </PageFrame>
</template>
