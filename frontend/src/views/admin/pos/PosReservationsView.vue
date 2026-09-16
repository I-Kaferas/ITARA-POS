<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDateTime } from '../../../utils/format'

type ReservationStatus = 'pending' | 'confirmed' | 'seated' | 'completed' | 'cancelled' | 'no_show'

interface PosReservation {
  id: string
  reference: string
  guest_name: string
  phone?: string | null
  party_size: number
  reserved_at: string
  table_label?: string | null
  status: ReservationStatus
  notes?: string | null
  customer_id?: string | null
  customer?: { id: string; name: string; phone?: string | null } | null
}

const STATUSES: ReservationStatus[] = ['pending', 'confirmed', 'seated', 'completed', 'cancelled', 'no_show']

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const reservations = ref<PosReservation[]>([])
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

function statusLabel(status: string): string {
  const key = `pointOfSale.reservations.status.${status}`
  const label = t(key)
  return label === key ? status : label
}

function statusVariant(status: string): 'success' | 'neutral' | 'brand' | 'warning' {
  if (status === 'confirmed' || status === 'seated') return 'brand'
  if (status === 'completed') return 'success'
  if (status === 'cancelled') return 'neutral'
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

async function load() {
  if (!storeId.value) return
  loading.value = true
  error.value = ''
  try {
    if (!store.customers.length) await store.loadCustomers()
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
    table_label: item.table_label ?? '',
    status: item.status,
    notes: item.notes ?? '',
  }
  showForm.value = true
}

function payload() {
  const partySize = Number(form.value.party_size)
  return {
    customer_id: form.value.mode === 'customer' && form.value.customer_id ? form.value.customer_id : null,
    guest_name: form.value.guest_name.trim() || null,
    phone: form.value.phone.trim() || null,
    party_size: Number.isFinite(partySize) ? partySize : 1,
    reserved_at: new Date(form.value.reserved_at).toISOString(),
    table_label: form.value.table_label.trim() || null,
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
  try {
    await api.patch(`/pos-reservations/${item.id}/status`, { status })
    item.status = status
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.reservations.saveError'))
    await load()
  } finally {
    statusSavingId.value = null
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
  <AdminLayout>
    <template #title>{{ t('nav.posReservations') }}</template>
    <template #subtitle>{{ t('pointOfSale.reservations.subtitle') }}</template>

    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('pointOfSale.reservations.needStore') }}
    </div>

    <template v-else>
      <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
        <p class="m-0 max-w-2xl text-sm text-slate-500">{{ t('pointOfSale.reservations.intro') }}</p>
        <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
          {{ t('pointOfSale.reservations.add') }}
        </button>
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

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('pointOfSale.reservations.listTitle') }}</h3>
        </div>

        <div v-if="loading" class="px-4 py-10 text-center text-sm text-slate-500">
          {{ t('common.loading') }}
        </div>

        <table v-else-if="reservations.length" class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.reference') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.guest') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.when') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.reservations.party') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.table') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('pointOfSale.reservations.statusLabel') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
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
                <div class="flex flex-wrap items-center gap-2">
                  <Badge :variant="statusVariant(item.status)">{{ statusLabel(item.status) }}</Badge>
                  <select
                    class="ui-select"
                    :value="item.status"
                    :disabled="statusSavingId === item.id"
                    @change="changeStatus(item, ($event.target as HTMLSelectElement).value as ReservationStatus)"
                  >
                    <option v-for="status in STATUSES" :key="status" :value="status">{{ statusLabel(status) }}</option>
                  </select>
                </div>
              </td>
              <td class="px-4 py-3 text-right">
                <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="openEdit(item)">
                  {{ t('common.edit') }}
                </button>
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
            <FieldLabel icon="pin">{{ t('pointOfSale.reservations.table') }}</FieldLabel>
            <input v-model="form.table_label" type="text" class="ui-input w-full" />
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
  </AdminLayout>
</template>
