<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import AppModal from '../ui/AppModal.vue'
import FieldLabel from '../ui/FieldLabel.vue'
import LoadingBlock from '../ui/LoadingBlock.vue'
import WarehouseOptions from './WarehouseOptions.vue'
import { extractApiErrorMessage } from '../../api/client'
import { useBackofficeStore } from '../../stores/backoffice'
import type { Category, InventoryCountDetail, InventoryCountItem, Warehouse } from '../../types'
import { formatMoney } from '../../utils/money'
import { formatDate } from '../../utils/format'

const scanCode = ref('')
const scanMessage = ref('')
const scannedId = ref('')

const REASONS = [
  'loss',
  'breakage',
  'damaged',
  'theft',
  'entry_error',
  'conversion_error',
  'unrecorded_consumption',
  'found',
  'other',
] as const

type LineDraft = {
  id: string
  name: string
  sku: string
  barcodes: string[]
  category: string
  system_quantity: number | null
  entered_quantity: number | null
  remainder_ml: number | null
  sale_unit_id: string
  unit_name: string
  tracks_volume: boolean
  units: { id: string; name: string; volume_ml: number }[]
  variance_reason: string
  notes: string
  cost_price: number
  bottle_volume_ml: number
}

const props = defineProps<{
  open: boolean
  warehouses: Warehouse[]
  categories: Category[]
  users: { id: string; name: string }[]
  countId?: string | null
}>()

const emit = defineEmits<{
  close: []
  changed: []
}>()

const { t } = useI18n()
const store = useBackofficeStore()

const loading = ref(false)
const saving = ref(false)
const error = ref('')
const query = ref('')
const varianceFilter = ref<'all' | 'pending' | 'match' | 'shortage' | 'surplus'>('all')
const detail = ref<InventoryCountDetail | null>(null)
const lines = ref<LineDraft[]>([])
const dirty = ref(new Set<string>())
const cancelling = ref(false)
const cancelReason = ref('')
let saveTimer: ReturnType<typeof setTimeout> | undefined

const setup = ref(blankSetup())

function today() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

function blankSetup() {
  return {
    warehouse_id: '',
    counted_at: today(),
    category_id: '',
    zone: '',
    responsible_id: '',
    notes: '',
    lock_movements: true,
  }
}

const active = computed(() => Boolean(detail.value))
const status = computed(() => detail.value?.status ?? '')
const editable = computed(() => ['draft', 'in_progress', 'review'].includes(status.value))
const title = computed(() => detail.value?.count_number || t('inventory.fullCountTitle'))

const visibleLines = computed(() => {
  const term = query.value.trim().toLowerCase()
  return lines.value.filter((line) => {
    if (term && !`${line.name} ${line.sku} ${line.category}`.toLowerCase().includes(term)) return false
    const kind = varianceKind(line)
    if (varianceFilter.value === 'all') return true
    return kind === varianceFilter.value
  })
})

const liveSummary = computed(() => {
  let counted = 0
  let matched = 0
  let shortage = 0
  let surplus = 0
  let shortageValue = 0
  let surplusValue = 0
  for (const line of lines.value) {
    const delta = varianceOf(line)
    if (delta == null) continue
    counted++
    const value = Math.abs(delta) * unitCost(line)
    if (delta === 0) matched++
    else if (delta < 0) {
      shortage++
      shortageValue += value
    } else {
      surplus++
      surplusValue += value
    }
  }
  return {
    total_products: lines.value.length,
    counted_products: counted,
    matched,
    shortage,
    surplus,
    shortage_value: shortageValue,
    surplus_value: surplusValue,
    net_value: surplusValue - shortageValue,
  }
})

watch(() => [props.open, props.countId] as const, ([open, id]) => {
  if (!open) {
    clearSaveTimer()
    return
  }
  error.value = ''
  cancelling.value = false
  query.value = ''
  varianceFilter.value = 'all'
  if (id) void load(id)
  else resetSetup()
})

onBeforeUnmount(clearSaveTimer)

function resetSetup() {
  detail.value = null
  lines.value = []
  dirty.value = new Set()
  setup.value = {
    ...blankSetup(),
    warehouse_id: props.warehouses[0]?.id ?? '',
  }
}

function clearSaveTimer() {
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = undefined
}

function unitVolume(line: LineDraft) {
  return line.units.find((unit) => unit.id === line.sale_unit_id)?.volume_ml || line.bottle_volume_ml || 1
}

function physicalBase(line: LineDraft) {
  if (line.entered_quantity == null || Number.isNaN(line.entered_quantity)) return null
  const qty = Math.max(0, Math.trunc(line.entered_quantity))
  if (!line.tracks_volume) return qty
  const remainder = Math.max(0, Math.trunc(line.remainder_ml ?? 0))
  return qty * Math.max(1, unitVolume(line)) + remainder
}

function varianceOf(line: LineDraft) {
  const physical = physicalBase(line)
  if (physical == null || line.system_quantity == null) return null
  return physical - line.system_quantity
}

function varianceKind(line: LineDraft): 'pending' | 'match' | 'shortage' | 'surplus' {
  const delta = varianceOf(line)
  if (delta == null) return 'pending'
  if (delta === 0) return 'match'
  return delta < 0 ? 'shortage' : 'surplus'
}

function unitCost(line: LineDraft) {
  if (line.tracks_volume && line.bottle_volume_ml > 0) return Math.floor(line.cost_price / line.bottle_volume_ml)
  return line.cost_price
}

function systemLabel(line: LineDraft) {
  if (line.system_quantity == null) return '—'
  return line.tracks_volume ? `${line.system_quantity} ml` : String(line.system_quantity)
}

function varianceLabel(line: LineDraft) {
  const delta = varianceOf(line)
  if (delta == null) return '—'
  if (delta > 0) return `+${delta}`
  return String(delta)
}

function mapLines(items: InventoryCountItem[]): LineDraft[] {
  return items.map((item) => {
    const units = item.product?.sale_units ?? []
    const bottle = item.product?.bottle_volume_ml ?? item.unit_volume_ml ?? 0
    const tracks = bottle > 0 && units.length > 0
    return {
      id: item.id,
      name: item.product?.name ?? '—',
      sku: item.product?.sku ?? '',
      barcodes: [item.product?.barcode, ...(item.product?.barcodes ?? []).map((row) => row.barcode)].filter((code): code is string => !!code),
      category: item.product?.category?.name ?? '',
      system_quantity: item.system_quantity ?? null,
      entered_quantity: item.entered_quantity ?? null,
      remainder_ml: tracks ? (item.remainder_ml ?? 0) : null,
      sale_unit_id: item.sale_unit_id ?? units.find((unit) => unit.is_base)?.id ?? units[0]?.id ?? '',
      unit_name: item.unit_name ?? item.product?.unit ?? '',
      tracks_volume: tracks,
      units,
      variance_reason: item.variance_reason ?? '',
      notes: item.notes ?? '',
      cost_price: item.product?.cost_price ?? 0,
      bottle_volume_ml: bottle,
    }
  })
}

function applyCount(payload: { data?: InventoryCountDetail }) {
  if (!payload.data) return
  detail.value = payload.data
  lines.value = mapLines(payload.data.items ?? [])
  dirty.value = new Set()
}

async function load(id: string) {
  loading.value = true
  error.value = ''
  try {
    const data = await store.loadInventoryCount(id)
    applyCount({ data })
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function markDirty(id: string) {
  if (!dirty.value.has(id)) dirty.value = new Set([...dirty.value, id])
  clearSaveTimer()
  saveTimer = setTimeout(() => { void persist(false) }, 700)
}

function applyScan() {
  const code = scanCode.value.trim().toLowerCase()
  scanCode.value = ''
  if (!code || !editable.value) return
  const line = lines.value.find((item) =>
    item.sku.toLowerCase() === code || item.barcodes.some((barcode) => barcode.toLowerCase() === code),
  )
  if (!line) {
    scanMessage.value = t('inventory.scanMiss')
    return
  }
  line.entered_quantity = (line.entered_quantity ?? 0) + 1
  scannedId.value = line.id
  query.value = line.sku
  markDirty(line.id)
  const delta = varianceOf(line)
  scanMessage.value = t('inventory.scanHit', {
    name: line.name,
    system: line.system_quantity ?? 0,
    physical: line.entered_quantity,
    difference: delta == null ? '—' : delta > 0 ? `+${delta}` : String(delta),
  })
}

function onQuantity(line: LineDraft, raw: string) {
  line.entered_quantity = raw === '' ? null : Math.max(0, Math.trunc(Number(raw) || 0))
  if (varianceOf(line) === 0) line.variance_reason = ''
  markDirty(line.id)
}

function onRemainder(line: LineDraft, raw: string) {
  line.remainder_ml = Math.max(0, Math.trunc(Number(raw) || 0))
  markDirty(line.id)
}

async function start() {
  if (!setup.value.warehouse_id) return
  saving.value = true
  error.value = ''
  try {
    const result = await store.startFullCount({
      warehouse_id: setup.value.warehouse_id,
      counted_at: setup.value.counted_at,
      category_id: setup.value.category_id || undefined,
      zone: setup.value.zone || undefined,
      notes: setup.value.notes || undefined,
      lock_movements: setup.value.lock_movements,
      responsible_id: setup.value.responsible_id || undefined,
    })
    if (!result.data?.id) {
      error.value = t('inventory.noStockToCount')
      return
    }
    applyCount(result)
    emit('changed')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function payloadLines() {
  const ids = dirty.value
  return lines.value
    .filter((line) => ids.has(line.id))
    .map((line) => ({
      id: line.id,
      entered_quantity: line.entered_quantity,
      remainder_ml: line.tracks_volume ? Math.max(0, Math.trunc(line.remainder_ml ?? 0)) : null,
      sale_unit_id: line.sale_unit_id || null,
      variance_reason: varianceOf(line) && line.variance_reason ? line.variance_reason : null,
      notes: line.notes || null,
    }))
}

async function persist(showSaved = true, manageSaving = true) {
  if (!detail.value || !dirty.value.size) return
  const payload = payloadLines()
  if (!payload.length) return
  if (manageSaving) saving.value = true
  if (showSaved) error.value = ''
  try {
    applyCount(await store.saveFullCountLines(detail.value.id, payload))
    if (showSaved) emit('changed')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
    throw err
  } finally {
    if (manageSaving) saving.value = false
  }
}

async function runAction(action: 'submit' | 'review' | 'approve' | 'complete' | 'start') {
  if (!detail.value) return
  saving.value = true
  error.value = ''
  try {
    if (dirty.value.size) await persist(false, false)
    const id = detail.value.id
    if (action === 'submit') {
      const missing = lines.value.filter((line) => line.entered_quantity == null).length
      if (missing) {
        error.value = t('inventory.uncounted', { count: missing })
        return
      }
      applyCount(await store.submitFullCount(id))
    } else if (action === 'review') {
      applyCount(await store.reviewFullCount(id))
    } else if (action === 'approve') {
      applyCount(await store.approveFullCount(id))
    } else if (action === 'start') {
      applyCount(await store.startCycleCount(id))
    } else {
      const adjustments = lines.value.filter((line) => varianceOf(line)).length
      await store.completeInventoryCount(id)
      await load(id)
      if (adjustments) scanMessage.value = t('inventory.adjustmentPosted', { count: adjustments })
    }
    emit('changed')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function confirmCancel() {
  if (!detail.value) return
  saving.value = true
  error.value = ''
  try {
    applyCount(await store.cancelFullCount(detail.value.id, cancelReason.value || undefined))
    cancelling.value = false
    cancelReason.value = ''
    emit('changed')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function statusLabel(value: string) {
  const key = `inventory.countStatus.${value}`
  const translated = t(key)
  return translated === key ? value : translated
}
</script>

<template>
  <AppModal :open="open" :title="title" icon="inventory" tone="info" size="xl" @close="emit('close')">
    <LoadingBlock v-if="loading" variant="table" :rows="5" :label="t('common.loading')" />
    <p v-if="error" class="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>

    <form v-if="!active && !loading" class="space-y-3" @submit.prevent="start">
      <p class="text-sm text-slate-600">{{ t('inventory.fullCountHint') }}</p>
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <WarehouseOptions v-model="setup.warehouse_id" :warehouses="warehouses" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('inventory.countDate') }}</FieldLabel>
          <input v-model="setup.counted_at" type="date" required class="field" />
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('inventory.category') }}</FieldLabel>
          <select v-model="setup.category_id" class="field">
            <option value="">{{ t('inventory.allCategories') }}</option>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="pin">{{ t('inventory.zone') }}</FieldLabel>
          <input v-model="setup.zone" class="field" :placeholder="t('inventory.zoneHint')" />
        </div>
        <div>
          <FieldLabel icon="account">{{ t('inventory.responsible') }}</FieldLabel>
          <select v-model="setup.responsible_id" class="field">
            <option value="">{{ t('inventory.currentUser') }}</option>
            <option v-for="user in users" :key="user.id" :value="user.id">{{ user.name }}</option>
          </select>
        </div>
        <div class="sm:col-span-2">
          <FieldLabel icon="note">{{ t('inventory.notes') }}</FieldLabel>
          <textarea v-model="setup.notes" rows="2" class="field" />
        </div>
      </div>
      <label class="flex items-center gap-2 text-sm">
        <span class="field-icon"><AppIcon name="check" :size="14" /></span>
        <input v-model="setup.lock_movements" type="checkbox" />
        {{ t('inventory.lockMovements') }}
      </label>
      <div class="app-modal__actions">
        <button type="button" class="btn-secondary" @click="emit('close')">{{ t('common.cancel') }}</button>
        <button type="submit" class="btn-primary" :disabled="saving || !setup.warehouse_id">{{ t('inventory.startFullCount') }}</button>
      </div>
    </form>

    <div v-else-if="active" class="space-y-3">
      <div class="flex flex-wrap items-center justify-between gap-2 text-sm text-slate-600">
        <span>{{ detail?.warehouse?.name }} · {{ formatDate(detail?.counted_at) }}</span>
        <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">{{ statusLabel(status) }}</span>
      </div>

      <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.statCounted') }}</p>
          <p class="font-semibold">{{ liveSummary.counted_products }} / {{ liveSummary.total_products }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.statMatch') }}</p>
          <p class="font-semibold">{{ liveSummary.matched }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.statShortage') }}</p>
          <p class="font-semibold text-red-700">{{ liveSummary.shortage }} · {{ formatMoney(liveSummary.shortage_value) }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.statSurplus') }}</p>
          <p class="font-semibold text-emerald-700">{{ liveSummary.surplus }} · {{ formatMoney(liveSummary.surplus_value) }}</p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <input
          v-model="scanCode"
          class="field max-w-xs"
          :placeholder="t('inventory.scanProduct')"
          :disabled="!editable"
          @keydown.enter.prevent="applyScan"
        />
        <input v-model="query" class="field max-w-xs" :placeholder="t('inventory.searchProduct')" />
      </div>
      <p v-if="scanMessage" class="m-0 text-sm text-slate-600">{{ scanMessage }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('inventory.physicalHint') }}</p>
      <div class="flex flex-wrap gap-2">
        <button type="button" class="btn-secondary" :class="{ 'ring-1 ring-brand-500': varianceFilter === 'all' }" @click="varianceFilter = 'all'">{{ t('inventory.statTotal') }}</button>
        <button type="button" class="btn-secondary" @click="varianceFilter = 'pending'">{{ t('inventory.varianceStatus.pending') }}</button>
        <button type="button" class="btn-secondary" @click="varianceFilter = 'shortage'">{{ t('inventory.varianceStatus.shortage') }}</button>
        <button type="button" class="btn-secondary" @click="varianceFilter = 'surplus'">{{ t('inventory.varianceStatus.surplus') }}</button>
      </div>

      <div class="max-h-[28rem] overflow-auto rounded-xl ring-1 ring-slate-200">
        <table class="min-w-full text-sm">
          <thead class="sticky top-0 bg-slate-50 text-left text-slate-500">
            <tr>
              <th class="px-3 py-2 font-medium">{{ t('inventory.product') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.systemQty') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.physicalCount') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.variance') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.varianceReason') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="line in visibleLines" :key="line.id" class="border-t border-slate-100 align-top" :class="scannedId === line.id ? 'bg-amber-50' : ''">
              <td class="px-3 py-2">
                <span class="block font-medium">{{ line.name }}</span>
                <span class="text-xs text-slate-500">{{ line.sku }}<template v-if="line.category"> · {{ line.category }}</template></span>
              </td>
              <td class="px-3 py-2">{{ systemLabel(line) }}</td>
              <td class="px-3 py-2">
                <div class="flex flex-wrap items-center gap-2">
                  <input
                    :value="line.entered_quantity ?? ''"
                    type="number"
                    min="0"
                    step="1"
                    class="field w-24"
                    :disabled="!editable"
                    @input="onQuantity(line, ($event.target as HTMLInputElement).value)"
                  />
                  <select v-if="line.units.length > 1" v-model="line.sale_unit_id" class="field w-28" :disabled="!editable" @change="markDirty(line.id)">
                    <option v-for="unit in line.units" :key="unit.id" :value="unit.id">{{ unit.name }}</option>
                  </select>
                  <span v-else class="text-xs text-slate-500">{{ line.units[0]?.name || line.unit_name }}</span>
                  <input
                    v-if="line.tracks_volume"
                    :value="line.remainder_ml ?? 0"
                    type="number"
                    min="0"
                    step="1"
                    class="field w-24"
                    :disabled="!editable"
                    :title="t('inventory.remainderMl')"
                    :placeholder="t('inventory.remainderMl')"
                    @input="onRemainder(line, ($event.target as HTMLInputElement).value)"
                  />
                </div>
              </td>
              <td class="px-3 py-2" :class="varianceKind(line) === 'shortage' ? 'text-red-700' : varianceKind(line) === 'surplus' ? 'text-emerald-700' : ''">
                {{ varianceLabel(line) }}
              </td>
              <td class="px-3 py-2">
                <select
                  v-if="varianceOf(line)"
                  v-model="line.variance_reason"
                  class="field"
                  :disabled="!editable"
                  @change="markDirty(line.id)"
                >
                  <option value="">{{ t('inventory.varianceReason') }}</option>
                  <option v-for="reason in REASONS" :key="reason" :value="reason">{{ t(`inventory.reasons.${reason}`) }}</option>
                </select>
                <input
                  v-model="line.notes"
                  class="field mt-1"
                  :disabled="!editable"
                  :placeholder="t('inventory.notes')"
                  @input="markDirty(line.id)"
                />
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!visibleLines.length" class="px-3 py-6 text-center text-sm text-slate-500">{{ t('inventory.noArticles') }}</p>
      </div>

      <p class="text-xs text-slate-500">
        {{ t('inventory.statNet') }}: {{ formatMoney(liveSummary.net_value) }}
      </p>

      <div v-if="cancelling" class="flex flex-wrap items-end gap-2">
        <div class="min-w-56 flex-1">
          <FieldLabel icon="note">{{ t('inventory.reason') }}</FieldLabel>
          <input v-model="cancelReason" class="field" />
        </div>
        <button type="button" class="btn-secondary" @click="cancelling = false">{{ t('common.cancel') }}</button>
        <button type="button" class="btn-danger" :disabled="saving" @click="confirmCancel">{{ t('inventory.cancelCount') }}</button>
      </div>

      <div v-else class="app-modal__actions">
        <button v-if="!['completed', 'cancelled'].includes(status)" type="button" class="btn-danger" :disabled="saving" @click="cancelling = true">{{ t('inventory.cancelCount') }}</button>
        <button v-if="editable && dirty.size" type="button" class="btn-secondary" :disabled="saving" @click="persist()">{{ t('common.save') }}</button>
        <button v-if="status === 'scheduled'" type="button" class="btn-primary" :disabled="saving" @click="runAction('start')">{{ t('inventory.startCycle') }}</button>
        <button v-if="status === 'draft' || status === 'in_progress'" type="button" class="btn-primary" :disabled="saving" @click="runAction('submit')">{{ t('inventory.submitCount') }}</button>
        <button v-if="status === 'counted'" type="button" class="btn-primary" :disabled="saving" @click="runAction('review')">{{ t('inventory.reviewCount') }}</button>
        <button v-if="status === 'review'" type="button" class="btn-primary" :disabled="saving" @click="runAction('approve')">{{ t('inventory.approveCount') }}</button>
        <button v-if="status === 'approved' || status === 'confirmed'" type="button" class="btn-primary" :disabled="saving" @click="runAction('complete')">{{ t('inventory.validateInventory') }}</button>
      </div>
    </div>
  </AppModal>
</template>
