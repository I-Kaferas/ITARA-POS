<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { useContextStore } from '../../../stores/context'
import { formatMoney } from '../../../utils/money'
import { formatDateTime } from '../../../utils/format'

type TableStatus = 'available' | 'occupied' | 'reserved' | 'cleaning' | 'inactive'

interface TableSale {
  id: string
  reference: string
  status: string
  total: number
  item_count: number
  opened_at?: string | null
  server?: { id: string; name: string } | null
  customer?: { id: string; name: string } | null
}

interface FloorTable {
  id: string
  name: string
  code: string
  capacity: number
  zone_id?: string | null
  zone?: { id: string; name: string } | null
  description?: string | null
  status: TableStatus
  is_active: boolean
  current_sale_id?: string | null
  current_sale?: TableSale | null
  reservation?: {
    id: string
    reference: string
    guest_name: string
    party_size: number
    reserved_at?: string | null
    status: string
    notes?: string | null
  } | null
}

interface TableZone {
  id: string
  name: string
  description?: string | null
  sort_order: number
  is_active: boolean
}

interface TableStats {
  total: number
  available: number
  occupied: number
  reserved: number
  cleaning: number
  inactive: number
  open_orders: number
  today_revenue: number
  today_tickets: number
  average_ticket: number
  average_occupation_minutes: number
  most_used: { table_id: string; name: string; tickets: number }[]
}

interface HistorySale {
  id: string
  reference: string
  status: string
  total: number
  created_at?: string | null
  completed_at?: string | null
  processed_by?: { id: string; name: string } | null
  customer?: { id: string; name: string } | null
}

const STATUSES: TableStatus[] = ['available', 'occupied', 'reserved', 'cleaning', 'inactive']
const ZONE_PRESETS = ['Salle', 'Terrasse', 'Bar', 'VIP', 'Extérieur']

const { t } = useI18n()
const router = useRouter()
const context = useContextStore()
const { confirm: confirmDialog } = useConfirm()

const storeId = computed(() => context.currentStoreId)
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const zones = ref<TableZone[]>([])
const tables = ref<FloorTable[]>([])
const stats = ref<TableStats | null>(null)
const zoneFilter = ref('')
const selected = ref<FloorTable | null>(null)

const showTableForm = ref(false)
const editingTableId = ref<string | null>(null)
const tableForm = ref({
  name: '',
  code: '',
  capacity: '4',
  zone_id: '',
  description: '',
  is_active: true,
})

const showZoneForm = ref(false)
const editingZoneId = ref<string | null>(null)
const zoneForm = ref({ name: '', description: '', sort_order: '0' })

const showTransfer = ref(false)
const transferTo = ref('')
const showMerge = ref(false)
const mergeTo = ref('')
const showReserve = ref(false)
const reserveForm = ref({ guest_name: '', party_size: '2', reserved_at: '', notes: '' })
const showHistory = ref(false)
const history = ref<HistorySale[]>([])
const historyFilters = ref({ from: '', to: '', status: '' })

const visibleTables = computed(() => {
  if (!zoneFilter.value) return tables.value
  return tables.value.filter(table => table.zone_id === zoneFilter.value)
})

const transferTargets = computed(() =>
  tables.value.filter(table => table.id !== selected.value?.id && table.is_active && table.status !== 'occupied' && table.status !== 'inactive'),
)

const mergeTargets = computed(() =>
  tables.value.filter(table => table.id !== selected.value?.id && table.status === 'occupied'),
)

function statusLabel(status: string) {
  const key = `pointOfSale.tables.status.${status}`
  const label = t(key)
  return label === key ? status : label
}

function statusVariant(status: TableStatus): 'success' | 'warning' | 'brand' | 'neutral' {
  if (status === 'available') return 'success'
  if (status === 'occupied') return 'warning'
  if (status === 'reserved') return 'brand'
  return 'neutral'
}

function formatTime(value?: string | null) {
  if (!value) return '—'
  return new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
}

async function loadFloor() {
  if (!storeId.value) return
  loading.value = true
  error.value = ''
  try {
    const res = await api.get<{ data: { zones: TableZone[]; tables: FloorTable[]; stats: TableStats } }>(
      `/stores/${storeId.value}/pos/tables`,
    )
    zones.value = res.data.zones ?? []
    tables.value = res.data.tables ?? []
    stats.value = res.data.stats ?? null
    if (selected.value) {
      selected.value = tables.value.find(table => table.id === selected.value?.id) ?? null
    }
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.loadError'))
  } finally {
    loading.value = false
  }
}

async function saveZone() {
  if (!storeId.value || !zoneForm.value.name.trim()) return
  saving.value = true
  try {
    const body = {
      name: zoneForm.value.name.trim(),
      description: zoneForm.value.description || null,
      sort_order: Number(zoneForm.value.sort_order) || 0,
    }
    if (editingZoneId.value) {
      await api.put(`/pos-table-zones/${editingZoneId.value}`, body)
    } else {
      await api.post(`/stores/${storeId.value}/pos/table-zones`, body)
    }
    showZoneForm.value = false
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  } finally {
    saving.value = false
  }
}

async function createPresetZone(name: string) {
  if (!storeId.value) return
  if (zones.value.some(zone => zone.name.toLowerCase() === name.toLowerCase())) {
    zoneFilter.value = zones.value.find(zone => zone.name.toLowerCase() === name.toLowerCase())?.id ?? ''
    return
  }
  try {
    await api.post(`/stores/${storeId.value}/pos/table-zones`, { name, sort_order: zones.value.length })
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  }
}

async function saveTable() {
  if (!storeId.value || !tableForm.value.name.trim()) return
  saving.value = true
  try {
    const body = {
      name: tableForm.value.name.trim(),
      code: tableForm.value.code.trim() || undefined,
      capacity: Number(tableForm.value.capacity) || 2,
      zone_id: tableForm.value.zone_id || null,
      description: tableForm.value.description || null,
      is_active: tableForm.value.is_active,
    }
    if (editingTableId.value) {
      await api.put(`/pos-tables/${editingTableId.value}`, body)
    } else {
      await api.post(`/stores/${storeId.value}/pos/tables`, body)
    }
    showTableForm.value = false
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  } finally {
    saving.value = false
  }
}

function openCreateTable() {
  editingTableId.value = null
  tableForm.value = {
    name: '',
    code: '',
    capacity: '4',
    zone_id: zoneFilter.value,
    description: '',
    is_active: true,
  }
  showTableForm.value = true
}

function openEditTable(table: FloorTable) {
  editingTableId.value = table.id
  tableForm.value = {
    name: table.name,
    code: table.code,
    capacity: String(table.capacity),
    zone_id: table.zone_id ?? '',
    description: table.description ?? '',
    is_active: table.is_active,
  }
  showTableForm.value = true
}

async function deactivate(table: FloorTable) {
  const ok = await confirmDialog(t('pointOfSale.tables.deactivateConfirm', { name: table.name }), {
    title: t('pointOfSale.tables.deactivate'),
    confirmLabel: t('pointOfSale.tables.deactivate'),
    danger: true,
  })
  if (!ok) return
  try {
    await api.delete(`/pos-tables/${table.id}`)
    selected.value = null
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  }
}

async function setStatus(table: FloorTable, status: TableStatus) {
  try {
    await api.patch(`/pos-tables/${table.id}/status`, { status })
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  }
}

async function onTableClick(table: FloorTable) {
  selected.value = table
  if (table.status === 'available') {
    await openOrder(table)
  }
}

async function openOrder(table: FloorTable, confirmReserved = false) {
  if (!storeId.value) return
  saving.value = true
  error.value = ''
  try {
    const res = await api.post<{ data: { sale: { id: string } } }>(
      `/stores/${storeId.value}/pos/tables/${table.id}/open`,
      { confirm_reserved: confirmReserved },
    )
    const saleId = res.data.sale.id
    await router.push({ name: 'pos', query: { sale: saleId, table: table.id } })
  } catch (e) {
    const message = extractApiErrorMessage(e, t('pointOfSale.tables.openError'))
    if (table.status === 'reserved' && !confirmReserved) {
      const ok = await confirmDialog(t('pointOfSale.tables.reservedConfirm', { name: table.name }), {
        title: t('pointOfSale.tables.reserved'),
        confirmLabel: t('pointOfSale.tables.openOrder'),
        danger: false,
      })
      if (ok) await openOrder(table, true)
      return
    }
    error.value = message
  } finally {
    saving.value = false
  }
}

function continueOrder(table: FloorTable, pay = false) {
  if (!table.current_sale_id) return
  void router.push({
    name: 'pos',
    query: { sale: table.current_sale_id, table: table.id, ...(pay ? { pay: '1' } : {}) },
  })
}

async function cancelOrder() {
  const table = selected.value
  if (!table) return
  const ok = await confirmDialog(t('pointOfSale.tables.cancelConfirm', { name: table.name }), {
    title: t('pointOfSale.tables.cancelOrder'),
    confirmLabel: t('pointOfSale.tables.cancelOrder'),
    danger: true,
  })
  if (!ok) return
  try {
    await api.post(`/pos-tables/${table.id}/cancel`, { reason: t('pointOfSale.tables.cancelReason') })
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  }
}

async function confirmTransfer() {
  const table = selected.value
  if (!table || !transferTo.value) return
  saving.value = true
  try {
    await api.post(`/pos-tables/${table.id}/transfer`, { to_table_id: transferTo.value })
    showTransfer.value = false
    selected.value = null
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  } finally {
    saving.value = false
  }
}

async function confirmMerge() {
  const table = selected.value
  if (!table || !mergeTo.value) return
  saving.value = true
  try {
    await api.post(`/pos-tables/${table.id}/merge`, { to_table_id: mergeTo.value })
    showMerge.value = false
    selected.value = null
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  } finally {
    saving.value = false
  }
}

async function confirmReserve() {
  const table = selected.value
  if (!table || !storeId.value || !reserveForm.value.guest_name.trim()) return
  saving.value = true
  try {
    await api.post(`/stores/${storeId.value}/pos/tables/${table.id}/reserve`, {
      guest_name: reserveForm.value.guest_name.trim(),
      party_size: Number(reserveForm.value.party_size) || table.capacity,
      reserved_at: reserveForm.value.reserved_at || undefined,
      notes: reserveForm.value.notes || undefined,
    })
    showReserve.value = false
    await loadFloor()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.saveError'))
  } finally {
    saving.value = false
  }
}

async function loadHistory() {
  const table = selected.value
  if (!table) return
  try {
    const params = new URLSearchParams()
    if (historyFilters.value.from) params.set('from', historyFilters.value.from)
    if (historyFilters.value.to) params.set('to', historyFilters.value.to)
    if (historyFilters.value.status) params.set('status', historyFilters.value.status)
    const res = await api.get<{ data: HistorySale[] }>(`/pos-tables/${table.id}/history?${params.toString()}`)
    history.value = res.data ?? []
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.tables.loadError'))
  }
}

function openHistory(table: FloorTable) {
  selected.value = table
  showHistory.value = true
  void loadHistory()
}

onMounted(loadFloor)
watch(storeId, loadFloor)
useRealtimeSync(realtimeTopics.posFloor, loadFloor)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posTables') }}</template>
    <template #subtitle>{{ t('pointOfSale.tables.subtitle') }}</template>

    <p v-if="!storeId" class="m-0 text-sm text-slate-500">{{ t('pointOfSale.tables.needStore') }}</p>

    <div v-else class="tables-page">
      <p v-if="error" class="tables-error">{{ error }}</p>

      <section v-if="stats" class="tables-kpis">
        <article>
          <span>{{ t('pointOfSale.tables.kpi.total') }}</span>
          <strong>{{ stats.total }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.available') }}</span>
          <strong>{{ stats.available }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.occupied') }}</span>
          <strong>{{ stats.occupied }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.reserved') }}</span>
          <strong>{{ stats.reserved }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.openOrders') }}</span>
          <strong>{{ stats.open_orders }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.todayRevenue') }}</span>
          <strong>{{ formatMoney(stats.today_revenue) }}</strong>
        </article>
        <article>
          <span>{{ t('pointOfSale.tables.kpi.averageTicket') }}</span>
          <strong>{{ formatMoney(stats.average_ticket) }}</strong>
        </article>
      </section>

      <div class="tables-toolbar">
        <div class="tables-zones">
          <button type="button" :class="{ 'is-active': !zoneFilter }" @click="zoneFilter = ''">
            {{ t('pointOfSale.tables.allZones') }}
          </button>
          <button
            v-for="zone in zones"
            :key="zone.id"
            type="button"
            :class="{ 'is-active': zoneFilter === zone.id }"
            @click="zoneFilter = zone.id"
          >
            {{ zone.name }}
          </button>
        </div>
        <div class="tables-actions">
          <button type="button" class="btn-secondary" @click="showZoneForm = true; editingZoneId = null; zoneForm = { name: '', description: '', sort_order: String(zones.length) }">
            {{ t('pointOfSale.tables.addZone') }}
          </button>
          <button type="button" class="btn-primary" @click="openCreateTable">
            {{ t('pointOfSale.tables.addTable') }}
          </button>
        </div>
      </div>

      <div v-if="zones.length === 0" class="tables-presets">
        <span>{{ t('pointOfSale.tables.presetZones') }}</span>
        <button v-for="name in ZONE_PRESETS" :key="name" type="button" @click="createPresetZone(name)">{{ name }}</button>
      </div>

      <div v-if="loading" class="tables-loading">{{ t('common.loading') }}</div>

      <EmptyState
        v-else-if="visibleTables.length === 0"
        :title="t('pointOfSale.tables.empty')"
        :description="t('pointOfSale.tables.emptyHint')"
      >
        <button type="button" class="btn-primary" @click="openCreateTable">{{ t('pointOfSale.tables.addTable') }}</button>
      </EmptyState>

      <div v-else class="tables-grid">
        <button
          v-for="table in visibleTables"
          :key="table.id"
          type="button"
          class="table-card"
          :class="`table-card--${table.status}`"
          @click="onTableClick(table)"
        >
          <header>
            <strong>{{ table.name }}</strong>
            <Badge :variant="statusVariant(table.status)">{{ statusLabel(table.status) }}</Badge>
          </header>
          <p class="table-card__meta">{{ t('pointOfSale.tables.seats', { count: table.capacity }) }} · {{ table.zone?.name || '—' }}</p>
          <template v-if="table.status === 'occupied' && table.current_sale">
            <p class="table-card__sale">{{ table.current_sale.reference }}</p>
            <p>{{ table.current_sale.item_count }} {{ t('pointOfSale.tables.items') }}</p>
            <p class="table-card__total">{{ formatMoney(table.current_sale.total) }}</p>
            <p>{{ t('pointOfSale.tables.since') }} {{ formatTime(table.current_sale.opened_at) }}</p>
            <p v-if="table.current_sale.server">{{ t('pointOfSale.tables.server') }}: {{ table.current_sale.server.name }}</p>
          </template>
          <template v-else-if="table.status === 'reserved' && table.reservation">
            <p class="table-card__sale">{{ table.reservation.guest_name }}</p>
            <p>{{ formatDateTime(table.reservation.reserved_at) }}</p>
            <p>{{ t('pointOfSale.tables.party', { count: table.reservation.party_size }) }}</p>
          </template>
        </button>
      </div>

      <aside v-if="selected && selected.status !== 'available'" class="table-drawer">
        <header>
          <div>
            <h3>{{ selected.name }}</h3>
            <Badge :variant="statusVariant(selected.status)">{{ statusLabel(selected.status) }}</Badge>
          </div>
          <button type="button" class="btn-secondary" @click="selected = null">×</button>
        </header>

        <div v-if="selected.current_sale" class="table-drawer__sale">
          <p>{{ selected.current_sale.reference }}</p>
          <p>{{ selected.current_sale.item_count }} {{ t('pointOfSale.tables.items') }} · {{ formatMoney(selected.current_sale.total) }}</p>
          <p>{{ t('pointOfSale.tables.since') }} {{ formatTime(selected.current_sale.opened_at) }}</p>
        </div>

        <div class="table-drawer__actions">
          <button v-if="selected.status === 'occupied'" type="button" class="btn-primary" @click="continueOrder(selected)">
            {{ t('pointOfSale.tables.addProducts') }}
          </button>
          <button v-if="selected.status === 'occupied'" type="button" class="btn-secondary" @click="continueOrder(selected, true)">
            {{ t('pointOfSale.tables.pay') }}
          </button>
          <button v-if="selected.status === 'occupied'" type="button" class="btn-secondary" @click="showTransfer = true; transferTo = ''">
            {{ t('pointOfSale.tables.transfer') }}
          </button>
          <button v-if="selected.status === 'occupied' && mergeTargets.length" type="button" class="btn-secondary" @click="showMerge = true; mergeTo = ''">
            {{ t('pointOfSale.tables.merge') }}
          </button>
          <button v-if="selected.status === 'occupied'" type="button" class="btn-danger" @click="cancelOrder">
            {{ t('pointOfSale.tables.cancelOrder') }}
          </button>
          <button v-if="selected.status === 'reserved'" type="button" class="btn-primary" @click="openOrder(selected, false)">
            {{ t('pointOfSale.tables.openOrder') }}
          </button>
          <button v-if="selected.status === 'available' || selected.status === 'cleaning'" type="button" class="btn-secondary" @click="showReserve = true">
            {{ t('pointOfSale.tables.reserve') }}
          </button>
          <button v-if="selected.status === 'cleaning'" type="button" class="btn-secondary" @click="setStatus(selected, 'available')">
            {{ t('pointOfSale.tables.markAvailable') }}
          </button>
          <button v-if="selected.status === 'available'" type="button" class="btn-secondary" @click="setStatus(selected, 'cleaning')">
            {{ t('pointOfSale.tables.markCleaning') }}
          </button>
          <button type="button" class="btn-secondary" @click="openHistory(selected)">
            {{ t('pointOfSale.tables.history') }}
          </button>
          <button type="button" class="btn-secondary" @click="openEditTable(selected)">
            {{ t('common.edit') }}
          </button>
          <button v-if="selected.is_active" type="button" class="btn-danger" @click="deactivate(selected)">
            {{ t('pointOfSale.tables.deactivate') }}
          </button>
        </div>
      </aside>
    </div>

    <AppModal :open="showTableForm" :title="editingTableId ? t('common.edit') : t('pointOfSale.tables.addTable')" @close="showTableForm = false">
      <form class="grid gap-3" @submit.prevent="saveTable">
        <FieldLabel icon="pin">{{ t('pointOfSale.tables.name') }}</FieldLabel>
        <input v-model="tableForm.name" required>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <FieldLabel icon="pin">{{ t('pointOfSale.tables.code') }}</FieldLabel>
            <input v-model="tableForm.code">
          </div>
          <div>
            <FieldLabel icon="account">{{ t('pointOfSale.tables.capacity') }}</FieldLabel>
            <input v-model="tableForm.capacity" type="number" min="1">
          </div>
        </div>
        <FieldLabel icon="layers">{{ t('pointOfSale.tables.zone') }}</FieldLabel>
        <select v-model="tableForm.zone_id">
          <option value="">{{ t('pointOfSale.tables.noZone') }}</option>
          <option v-for="zone in zones" :key="zone.id" :value="zone.id">{{ zone.name }}</option>
        </select>
        <FieldLabel icon="note">{{ t('pointOfSale.tables.description') }}</FieldLabel>
        <textarea v-model="tableForm.description" rows="2" />
        <label class="flex items-center gap-2 text-sm">
          <input v-model="tableForm.is_active" type="checkbox">
          {{ t('pointOfSale.tables.active') }}
        </label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showTableForm = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showZoneForm" :title="t('pointOfSale.tables.addZone')" size="sm" @close="showZoneForm = false">
      <form class="grid gap-3" @submit.prevent="saveZone">
        <FieldLabel icon="layers">{{ t('pointOfSale.tables.zone') }}</FieldLabel>
        <input v-model="zoneForm.name" required>
        <div class="tables-presets">
          <button v-for="name in ZONE_PRESETS" :key="name" type="button" @click="zoneForm.name = name">{{ name }}</button>
        </div>
        <FieldLabel icon="note">{{ t('pointOfSale.tables.description') }}</FieldLabel>
        <textarea v-model="zoneForm.description" rows="2" />
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showZoneForm = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showTransfer" :title="t('pointOfSale.tables.transfer')" size="sm" @close="showTransfer = false">
      <div class="grid gap-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.tables.transferHint') }}</p>
        <label v-for="table in transferTargets" :key="table.id" class="tables-choice">
          <input v-model="transferTo" type="radio" :value="table.id">
          <span>{{ table.name }} · {{ table.zone?.name || '—' }}</span>
        </label>
        <p v-if="!transferTargets.length" class="m-0 text-sm text-slate-500">{{ t('pointOfSale.tables.noTransferTarget') }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showTransfer = false">{{ t('common.cancel') }}</button>
          <button type="button" class="btn-primary" :disabled="!transferTo || saving" @click="confirmTransfer">{{ t('common.confirm') }}</button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showMerge" :title="t('pointOfSale.tables.merge')" size="sm" @close="showMerge = false">
      <div class="grid gap-3">
        <p class="m-0 text-sm text-slate-500">{{ t('pointOfSale.tables.mergeHint') }}</p>
        <label v-for="table in mergeTargets" :key="table.id" class="tables-choice">
          <input v-model="mergeTo" type="radio" :value="table.id">
          <span>{{ table.name }} · {{ formatMoney(table.current_sale?.total ?? 0) }}</span>
        </label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showMerge = false">{{ t('common.cancel') }}</button>
          <button type="button" class="btn-primary" :disabled="!mergeTo || saving" @click="confirmMerge">{{ t('common.confirm') }}</button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showReserve" :title="t('pointOfSale.tables.reserve')" size="sm" @close="showReserve = false">
      <form class="grid gap-3" @submit.prevent="confirmReserve">
        <FieldLabel icon="account">{{ t('pointOfSale.tables.guest') }}</FieldLabel>
        <input v-model="reserveForm.guest_name" required>
        <FieldLabel icon="calendar">{{ t('pointOfSale.tables.when') }}</FieldLabel>
        <input v-model="reserveForm.reserved_at" type="datetime-local">
        <FieldLabel icon="organization">{{ t('pointOfSale.tables.capacity') }}</FieldLabel>
        <input v-model="reserveForm.party_size" type="number" min="1">
        <FieldLabel icon="note">{{ t('pointOfSale.tables.description') }}</FieldLabel>
        <textarea v-model="reserveForm.notes" rows="2" />
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showReserve = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showHistory" :title="t('pointOfSale.tables.history')" @close="showHistory = false">
      <div class="grid gap-3">
        <div class="grid grid-cols-3 gap-2">
          <input v-model="historyFilters.from" type="date" @change="loadHistory">
          <input v-model="historyFilters.to" type="date" @change="loadHistory">
          <select v-model="historyFilters.status" @change="loadHistory">
            <option value="">{{ t('pointOfSale.orders.filters.allStatuses') }}</option>
            <option value="completed">{{ t('pointOfSale.orders.status.completed') }}</option>
            <option value="pending">{{ t('pointOfSale.orders.status.pending') }}</option>
            <option value="voided">{{ t('pointOfSale.orders.status.voided') }}</option>
          </select>
        </div>
        <ul class="tables-history">
          <li v-for="sale in history" :key="sale.id">
            <div>
              <strong>{{ sale.reference }}</strong>
              <small>{{ formatDateTime(sale.completed_at || sale.created_at) }} · {{ sale.processed_by?.name || '—' }}</small>
            </div>
            <div>
              <strong>{{ formatMoney(sale.total) }}</strong>
              <small>{{ statusLabel(sale.status) }}</small>
            </div>
          </li>
        </ul>
        <p v-if="!history.length" class="m-0 text-sm text-slate-500">{{ t('pointOfSale.tables.historyEmpty') }}</p>
      </div>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.tables-page {
  display: grid;
  gap: 16px;
  position: relative;
}
.tables-error {
  margin: 0;
  padding: 10px 12px;
  border-radius: 8px;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 13px;
}
.tables-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
}
.tables-kpis article {
  background: #fff;
  border: 1px solid var(--color-border, #e2e8f0);
  border-radius: 8px;
  padding: 12px 14px;
}
.tables-kpis span {
  display: block;
  font-size: 13px;
  color: #64748b;
  line-height: 20px;
}
.tables-kpis strong {
  display: block;
  margin-top: 4px;
  font-size: 20px;
  line-height: 28px;
}
.tables-toolbar {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  align-items: center;
}
.tables-zones,
.tables-actions,
.tables-presets {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}
.tables-zones button,
.tables-presets button {
  height: 40px;
  padding: 0 14px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #fff;
  font-size: 13px;
}
.tables-zones button.is-active {
  background: #0f766e;
  border-color: #0f766e;
  color: #fff;
}
.tables-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px;
}
.table-card {
  text-align: left;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 14px;
  min-height: 148px;
  display: grid;
  gap: 4px;
  font-size: 13px;
  line-height: 20px;
  color: #334155;
}
.table-card header {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  align-items: start;
}
.table-card header strong {
  font-size: 14px;
  color: #0f172a;
}
.table-card--available { box-shadow: inset 4px 0 0 #059669; }
.table-card--occupied { box-shadow: inset 4px 0 0 #d97706; }
.table-card--reserved { box-shadow: inset 4px 0 0 #2563eb; }
.table-card--cleaning { box-shadow: inset 4px 0 0 #64748b; }
.table-card--inactive { opacity: 0.55; }
.table-card__sale { font-weight: 600; color: #0f172a; margin: 4px 0 0; }
.table-card__total { font-size: 16px; font-weight: 700; color: #0f172a; }
.table-card p { margin: 0; }
.table-drawer {
  position: sticky;
  bottom: 0;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 16px;
  display: grid;
  gap: 12px;
}
.table-drawer header {
  display: flex;
  justify-content: space-between;
  align-items: start;
}
.table-drawer h3 { margin: 0 0 6px; font-size: 18px; }
.table-drawer__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.tables-choice {
  display: flex;
  gap: 8px;
  align-items: center;
  min-height: 40px;
}
.tables-history {
  list-style: none;
  margin: 0;
  padding: 0;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.tables-history li {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 12px;
  border-top: 1px solid #f1f5f9;
  font-size: 13px;
}
.tables-history li:first-child { border-top: 0; }
.tables-history small { display: block; color: #64748b; }
.tables-loading { color: #64748b; font-size: 14px; }
</style>
