<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { api, extractApiErrorMessage } from '../../../api/client'
import { hospitalitySnapshotPath, HOTEL_STAY_KINDS } from '../../../api/hospitality'
import { useRealtimeSync } from '../../../composables/useRealtimeSync'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useAuthStore } from '../../../stores/auth'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Customer } from '../../../types'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { getAppCurrency } from '../../../utils/currency'
import { computeStayTaxes, findHotelSettings, moneyFromSettingsCents } from '../../../utils/hotelSettings'
import HotelChrome from './HotelChrome.vue'

type Doc = Record<string, any>
type ClientMode = 'new' | 'existing'
type IdMode = 'upload' | 'blank'
type SigMode = 'upload' | 'blank' | 'dotted'
type Step = 1 | 2 | 3
type IdDocumentType = 'passport' | 'national_id' | 'driver_license' | 'residence_permit' | 'other'
type Channel = 'direct' | 'phone' | 'walk_in' | 'agency' | 'booking_com' | 'expedia' | 'other'
type PaymentMode = 'collect_now' | 'credit'
type PayMethod = 'cash' | 'card' | 'bank_transfer' | 'mobile_money' | 'voucher'
type StayBoardStatus = 'en_sejour' | 'enregistre' | 'en_attente' | 'parti' | 'annule' | 'no_show'
type BoardTab = 'plan' | 'arrivals' | 'departures' | 'folios' | 'list'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const auth = useAuthStore()

const docs = ref<Doc[]>([])
const hotelSettings = computed(() => findHotelSettings(docs.value))
const step = ref<Step>(1)
const formOpen = ref(false)
const signOpen = ref(false)
const detailOpen = ref(false)
const detailStay = ref<Doc | null>(null)
const detailTab = ref<'overview' | 'room_service' | 'journal' | 'folio'>('overview')
const changeRoomOpen = ref(false)
const changeRoomId = ref('')
const changeRoomSaving = ref(false)
const collectOpen = ref(false)
const collectAmount = ref('')
const collectMethod = ref<PayMethod>('cash')
const collectSaving = ref(false)
const checkoutOpen = ref(false)
const checkoutStay = ref<Doc | null>(null)
const checkoutItems = ref<Array<{
  amenity_id: string
  name: string
  icon_key: string
  replacement_value_cents: number
  status: 'ok' | 'missing' | 'damaged'
  amount: string
}>>([])
const checkoutSaving = ref(false)
const signingStay = ref<Doc | null>(null)
const signTab = ref<'scan' | 'draw'>('scan')
const signUrl = ref('')
const signLinkCopied = ref(false)
const signSaving = ref(false)
const signLoading = ref(false)
const signRemoteDone = ref(false)
const signCanvas = ref<HTMLCanvasElement | null>(null)
const signDrawn = ref(false)
let signCtx: CanvasRenderingContext2D | null = null
let signPainting = false
let signPollTimer: ReturnType<typeof setInterval> | null = null
let signCloseTimer: ReturnType<typeof setTimeout> | null = null
let signBroadcast: BroadcastChannel | null = null
const STAY_SIGN_CHANNEL = 'itara-stay-sign'
const saving = ref(false)
const loading = ref(false)
const error = ref('')
const customerSearch = ref('')
const listSearch = ref('')
const statusFilter = ref<'all' | StayBoardStatus>('all')
const boardTab = ref<BoardTab>('list')
const viewMode = ref<'plan' | 'list'>('list')
const idFile = ref<File | null>(null)
const idPreview = ref('')
const sigFile = ref<File | null>(null)
const sigPreview = ref('')
const form = ref(blankForm())

const documentTypes: IdDocumentType[] = ['passport', 'national_id', 'driver_license', 'residence_permit', 'other']
const channels: Channel[] = ['direct', 'phone', 'walk_in', 'agency', 'booking_com', 'expedia', 'other']
const payMethods: PayMethod[] = ['cash', 'card', 'bank_transfer', 'mobile_money', 'voucher']

const roomTypes = computed(() => docs.value.filter(d => d.kind === 'room_type'))
const rooms = computed(() => docs.value.filter(d => d.kind === 'room'))
const floors = computed(() => docs.value.filter(d => d.kind === 'floor'))
const folios = computed(() => docs.value.filter(d => d.kind === 'folio'))
const amenities = computed(() => docs.value.filter(d => d.kind === 'amenity'))

type PlanTone = 'available' | 'occupied' | 'reserved' | 'dirty' | 'maintenance'

const allStays = computed(() =>
  docs.value
    .filter(d => d.kind === 'reservation')
    .slice()
    .sort((a, b) => String(b.arrive_on ?? '').localeCompare(String(a.arrive_on ?? ''))),
)

function activeStayForRoom(room: Doc) {
  const roomId = String(room.id ?? '')
  return allStays.value.find(s =>
    String(s.room_id ?? '') === roomId
    && (s.status === 'checked_in' || s.status === 'confirmed' || s.status === 'reserved'),
  ) ?? null
}

function planTone(room: Doc): PlanTone {
  const hk = String(room.housekeeping_status || 'clean')
  if (hk === 'maintenance' || hk === 'out_of_service') return 'maintenance'

  const status = String(room.status || 'vacant')
  const stay = activeStayForRoom(room)
  if (status === 'occupied' || stay?.status === 'checked_in') return 'occupied'
  if (status === 'reserved' || stay) return 'reserved'
  if (hk === 'dirty' || hk === 'cleaning') return 'dirty'
  return 'available'
}

function planToneLabel(tone: PlanTone) {
  if (tone === 'occupied') return t('hotel.stays.board.planOccupied')
  if (tone === 'reserved') return t('hotel.stays.board.planReserved')
  if (tone === 'dirty') return t('hotel.stays.board.planDirty')
  if (tone === 'maintenance') return t('hotel.stays.board.planMaintenance')
  return t('hotel.stays.board.planAvailable')
}

function planRoomTypeName(room: Doc) {
  if (room.type_name) return String(room.type_name)
  const type = roomTypes.value.find(t => t.id === room.type_id)
  return type?.name ? String(type.name) : '—'
}

function planFloorLabel(floorId: string | null, sample?: Doc) {
  if (!floorId) return t('hotel.stays.board.noFloor')
  const floor = floors.value.find(f => f.id === floorId)
  if (floor?.name) return String(floor.name)
  const num = floor?.floor_number ?? sample?.floor_number
  if (num != null && num !== '') return t('hotel.stays.board.floorN', { n: num })
  if (sample?.floor_name) return String(sample.floor_name)
  return t('hotel.stays.board.noFloor')
}

const planLegend = computed(() => ([
  { id: 'available' as const, label: t('hotel.stays.board.planAvailable') },
  { id: 'occupied' as const, label: t('hotel.stays.board.planOccupied') },
  { id: 'reserved' as const, label: t('hotel.stays.board.planReserved') },
  { id: 'dirty' as const, label: t('hotel.stays.board.planDirty') },
  { id: 'maintenance' as const, label: t('hotel.stays.board.planMaintenance') },
]))

const planFloors = computed(() => {
  const grouped = new Map<string, {
    id: string
    label: string
    sort: number
    rooms: Array<{
      room: Doc
      tone: PlanTone
      typeName: string
      stay: Doc | null
      guestName: string
      outDate: string
      meta: string
    }>
  }>()
  const sortedRooms = rooms.value.slice().sort((a, b) => {
    const fa = Number(a.floor_number ?? 9999) - Number(b.floor_number ?? 9999)
    if (fa !== 0) return fa
    return String(a.number ?? '').localeCompare(String(b.number ?? ''), undefined, { numeric: true })
  })
  for (const room of sortedRooms) {
    if (room.is_active === false) continue
    const floorId = room.floor_id ? String(room.floor_id) : '_none'
    if (!grouped.has(floorId)) {
      grouped.set(floorId, {
        id: floorId,
        label: planFloorLabel(room.floor_id ? String(room.floor_id) : null, room),
        sort: Number(room.floor_number ?? 9999),
        rooms: [],
      })
    }
    const stay = activeStayForRoom(room)
    const balance = stay ? stayBalanceCents(stay) : 0
    grouped.get(floorId)!.rooms.push({
      room,
      tone: planTone(room),
      typeName: planRoomTypeName(room),
      stay,
      guestName: String(stay?.guest_name || room.guest_name || ''),
      outDate: stay?.depart_on ? formatStayDate(String(stay.depart_on)) : '',
      meta: stay?.guest_phone
        ? String(stay.guest_phone)
        : (balance > 0 ? formatMoney(balance, stayCurrency(stay!)) : ''),
    })
  }
  return Array.from(grouped.values()).sort((a, b) => a.sort - b.sort || a.label.localeCompare(b.label))
})

function onPlanRoomClick(room: Doc, stay: Doc | null) {
  if (stay) {
    openDetail(stay)
    return
  }
  openCreate()
  nextTick(() => {
    form.value.type_id = String(room.type_id || '')
    form.value.room_id = String(room.id || '')
    step.value = 2
  })
}

function todayIso() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function stayBoardStatus(row: Doc): StayBoardStatus {
  const status = String(row.status || '')
  if (status === 'cancelled') return 'annule'
  if (status === 'no_show') return 'no_show'
  if (status === 'checked_out') return 'parti'
  if (status === 'checked_in') {
    const today = todayIso()
    const arrive = String(row.arrive_on || '').slice(0, 10)
    const depart = String(row.depart_on || '').slice(0, 10)
    if (arrive && depart && arrive <= today && today < depart) return 'en_sejour'
    return 'enregistre'
  }
  return 'en_attente'
}

function stayNights(row: Doc) {
  if (row.nights != null) return Number(row.nights)
  const a = String(row.arrive_on || '').slice(0, 10)
  const b = String(row.depart_on || '').slice(0, 10)
  if (!a || !b) return 0
  return Math.max(0, Math.round((new Date(b).getTime() - new Date(a).getTime()) / 86400000))
}

function folioOf(row: Doc) {
  if (row.folio_id) return folios.value.find(f => f.id === row.folio_id) ?? null
  return folios.value.find(f => f.reservation_id === row.id) ?? null
}

function stayBalanceCents(row: Doc) {
  const folio = folioOf(row)
  if (folio?.lines && Array.isArray(folio.lines)) {
    return folio.lines.reduce((sum: number, line: Doc) => sum + Number(line.amount || 0), 0)
  }
  const due = Number(row.amount_due_cents || 0)
  const collected = Number(row.amount_collected_cents || 0)
  return Math.max(0, due - collected)
}

function stayCurrency(row: Doc) {
  return getAppCurrency()
}

function stayRoomNumber(row: Doc) {
  if (row.room_number) return String(row.room_number)
  const room = rooms.value.find(r => r.id === row.room_id)
  return room?.number ? String(room.number) : '—'
}

function stayTypeName(row: Doc) {
  if (row.type_name) return String(row.type_name)
  const room = rooms.value.find(r => r.id === row.room_id)
  if (room?.type_name) return String(room.type_name)
  const type = roomTypes.value.find(t => t.id === (row.type_id || room?.type_id))
  return type?.name ? String(type.name) : '—'
}

function stayPaidComplete(row: Doc) {
  return stayBalanceCents(row) <= 0
}

function stayChannelLabel(row: Doc) {
  if (row.walk_in || row.channel === 'walk_in') return channelLabel('walk_in')
  if (!row.channel || row.channel === 'direct') return t('hotel.stays.board.channelReservation')
  return channelLabel(String(row.channel))
}

function selectBoardTab(tab: BoardTab) {
  boardTab.value = tab
  viewMode.value = tab === 'plan' ? 'plan' : 'list'
}

function showStayList() {
  return viewMode.value === 'list' && boardTab.value !== 'plan' && boardTab.value !== 'folios'
}

const stayStats = computed(() => {
  const counts = {
    en_sejour: 0,
    enregistre: 0,
    en_attente: 0,
    parti: 0,
    annule: 0,
    no_show: 0,
  }
  let revenue = 0
  for (const row of allStays.value) {
    const key = stayBoardStatus(row)
    counts[key] += 1
    revenue += Number(row.amount_due_cents || row.amount_collected_cents || 0)
  }
  return { ...counts, revenue }
})

const filteredStays = computed(() => {
  const q = listSearch.value.trim().toLowerCase()
  return allStays.value.filter((row) => {
    const board = stayBoardStatus(row)
    if (statusFilter.value !== 'all' && board !== statusFilter.value) return false
    if (boardTab.value === 'arrivals' && String(row.arrive_on || '').slice(0, 10) !== todayIso()) return false
    if (boardTab.value === 'departures' && String(row.depart_on || '').slice(0, 10) !== todayIso()) return false
    if (!q) return true
    const hay = `${row.guest_name || ''} ${row.guest_email || ''} ${row.room_number || ''} ${row.stay_code || ''} ${row.type_name || ''}`.toLowerCase()
    return hay.includes(q)
  })
})

const statusFilters = computed(() => ([
  { id: 'all' as const, label: t('hotel.stays.board.all'), count: allStays.value.length },
  { id: 'en_sejour' as const, label: t('hotel.stays.board.inHouse'), count: stayStats.value.en_sejour },
  { id: 'enregistre' as const, label: t('hotel.stays.board.registered'), count: stayStats.value.enregistre },
  { id: 'en_attente' as const, label: t('hotel.stays.board.pending'), count: stayStats.value.en_attente },
  { id: 'parti' as const, label: t('hotel.stays.board.departed'), count: stayStats.value.parti },
  { id: 'annule' as const, label: t('hotel.stays.board.cancelled'), count: stayStats.value.annule },
  { id: 'no_show' as const, label: t('hotel.stays.board.noShow'), count: stayStats.value.no_show },
]))

const boardTabs = computed(() => ([
  { id: 'plan' as const, label: t('hotel.stays.board.roomPlan') },
  { id: 'arrivals' as const, label: t('hotel.stays.board.arrivals') },
  { id: 'departures' as const, label: t('hotel.stays.board.departures') },
  { id: 'folios' as const, label: t('hotel.stays.board.folios') },
]))

function initials(name?: string) {
  const parts = String(name || '?').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return `${parts[0][0] || ''}${parts[1][0] || ''}`.toUpperCase()
}

function formatStayDate(value?: string) {
  const raw = String(value || '').slice(0, 10)
  if (!raw) return '—'
  const d = new Date(`${raw}T00:00:00`)
  if (Number.isNaN(d.getTime())) return raw
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

function boardStatusLabel(row: Doc) {
  return t(`hotel.stays.board.status.${stayBoardStatus(row)}`)
}

function openDetail(row: Doc) {
  detailStay.value = row
  detailTab.value = 'overview'
  detailOpen.value = true
  void hydrateStayMedia(row.id)
}

async function hydrateStayMedia(id: string) {
  try {
    const full = (await api.get<{ data: Doc }>(`/hospitality/docs/${encodeURIComponent(id)}`)).data
    docs.value = docs.value.map(d => (d.id === id ? { ...d, ...full } : d))
    if (detailStay.value?.id === id) detailStay.value = { ...detailStay.value, ...full }
    if (signingStay.value?.id === id) signingStay.value = { ...signingStay.value, ...full }
  } catch {
    // Detail remains usable without media binaries.
  }
}

function closeDetail() {
  detailOpen.value = false
  detailStay.value = null
}

function openSignFromDetail() {
  const row = detailStay.value
  closeDetail()
  if (row) openSign(row)
}

function checkoutFromDetail() {
  const row = detailStay.value
  if (row) void checkout(row)
}

const detailVacantRooms = computed(() => {
  const stay = detailStay.value
  if (!stay) return []
  return rooms.value
    .filter(room => room.is_active !== false)
    .filter(room => !['occupied', 'reserved'].includes(String(room.status ?? 'vacant')))
    .filter(room => String(room.housekeeping_status ?? 'clean') !== 'out_of_service')
    .filter(room => room.id !== stay.room_id)
    .slice()
    .sort((a, b) => String(a.number ?? '').localeCompare(String(b.number ?? ''), undefined, { numeric: true }))
})

function canManageStay(row: Doc) {
  const status = String(row.status || '')
  if (status === 'checked_in') return true
  const board = stayBoardStatus(row)
  return board === 'en_sejour' || board === 'enregistre'
}

function openChangeRoom() {
  if (!detailStay.value || !canManageStay(detailStay.value)) return
  error.value = ''
  changeRoomId.value = detailVacantRooms.value[0]?.id ?? ''
  changeRoomOpen.value = true
}

async function saveChangeRoom() {
  if (!detailStay.value || !changeRoomId.value) return
  changeRoomSaving.value = true
  error.value = ''
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'change_stay_room',
      reservation_id: detailStay.value.id,
      room_id: changeRoomId.value,
    })).data.docs
    const fresh = docs.value.find(d => d.id === detailStay.value?.id)
    if (fresh) detailStay.value = fresh
    changeRoomOpen.value = false
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    changeRoomSaving.value = false
  }
}

function openCollect() {
  if (!detailStay.value || !canManageStay(detailStay.value)) return
  error.value = ''
  const balance = detailFolioBalanceCents(detailStay.value)
  collectAmount.value = balance > 0 ? String((balance / 100).toFixed(2)) : ''
  collectMethod.value = 'cash'
  collectOpen.value = true
}

async function saveCollect() {
  if (!detailStay.value) return
  const cents = parseMoneyInput(collectAmount.value)
  if (cents <= 0) {
    error.value = t('hotel.stays.errors.amountCollected')
    return
  }
  collectSaving.value = true
  error.value = ''
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'collect_stay_payment',
      reservation_id: detailStay.value.id,
      amount_cents: cents,
      payment_method: collectMethod.value,
      by: receptionistName.value || null,
    })).data.docs
    const fresh = docs.value.find(d => d.id === detailStay.value?.id)
    if (fresh) detailStay.value = fresh
    collectOpen.value = false
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    collectSaving.value = false
  }
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

function printStayExport(title: string, bodyHtml: string) {
  const win = window.open('', '_blank', 'noopener,noreferrer,width=900,height=700')
  if (!win) return
  win.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
    <style>
      body{font-family:Segoe UI,Arial,sans-serif;color:#1c2830;padding:1.5rem;line-height:1.45}
      h1{font-size:1.25rem;margin:0 0 .75rem} h2{font-size:1rem;margin:1.2rem 0 .5rem}
      table{width:100%;border-collapse:collapse;font-size:.9rem} th,td{border:1px solid #d7e2ea;padding:.45rem .55rem;text-align:left}
      th{background:#f8fafc} .meta{color:#64748b;font-size:.85rem} .sign{max-width:220px;max-height:90px;border:1px solid #d7e2ea}
      @media print{button{display:none}}
    </style></head><body>
    <button onclick="window.print()">${escapeHtml(t('hotel.stays.detail.print'))}</button>
    ${bodyHtml}</body></html>`)
  win.document.close()
}

function exportStayLodging(row: Doc) {
  const currency = stayCurrency(row)
  const lines = detailFolioLines(row).filter(l => ['room', 'stay', 'tax', 'vat', 'tc'].includes(String(l.kind || '')) || Number(l.amount || 0) > 0 && !['payment', 'deposit', 'minibar', 'room_service', 'restaurant'].includes(String(l.kind || '')))
  const rows = (lines.length ? lines : [{
    description: t('hotel.stays.detail.groupStay'),
    amount: detailChargesCents(row),
    created_at: row.arrive_on,
  }]).map(l => `<tr><td>${escapeHtml(String(l.description || '—'))}</td><td>${escapeHtml(formatMoney(Math.abs(Number(l.amount || 0)), currency))}</td><td>${escapeHtml(formatDateTime(l.created_at || row.arrive_on))}</td></tr>`).join('')
  printStayExport(t('hotel.stays.detail.exportLodging'), `
    <h1>${escapeHtml(t('hotel.stays.detail.exportLodging'))}</h1>
    <p class="meta">${escapeHtml(row.guest_name || '')} · ${escapeHtml(row.stay_code || '')} · #${escapeHtml(stayRoomNumber(row))}</p>
    <table><thead><tr><th>${escapeHtml(t('hotel.stays.detail.colLabel'))}</th><th>${escapeHtml(t('hotel.stays.detail.colAmount'))}</th><th>${escapeHtml(t('hotel.stays.detail.colDate'))}</th></tr></thead>
    <tbody>${rows}</tbody></table>
    <p><strong>${escapeHtml(t('hotel.stays.detail.totalCharges'))}: ${escapeHtml(formatMoney(detailChargesCents(row), currency))}</strong></p>`)
}

function exportStayConsumption(row: Doc) {
  const currency = stayCurrency(row)
  const lines = detailFolioLines(row).filter(l => ['minibar', 'room_service', 'restaurant', 'other', 'missing_amenity', 'damaged_amenity'].includes(String(l.kind || '')))
  const rows = lines.map(l => `<tr><td>${escapeHtml(String(l.kind || '—'))}</td><td>${escapeHtml(String(l.description || '—'))}</td><td>${escapeHtml(formatMoney(Math.abs(Number(l.amount || 0)), currency))}</td></tr>`).join('')
    || `<tr><td colspan="3">${escapeHtml(t('hotel.stays.detail.noTransactions'))}</td></tr>`
  printStayExport(t('hotel.stays.detail.exportConsumption'), `
    <h1>${escapeHtml(t('hotel.stays.detail.exportConsumption'))}</h1>
    <p class="meta">${escapeHtml(row.guest_name || '')} · ${escapeHtml(row.stay_code || '')} · #${escapeHtml(stayRoomNumber(row))}</p>
    <table><thead><tr><th>${escapeHtml(t('hotel.stays.detail.colType'))}</th><th>${escapeHtml(t('hotel.stays.detail.colLabel'))}</th><th>${escapeHtml(t('hotel.stays.detail.colAmount'))}</th></tr></thead>
    <tbody>${rows}</tbody></table>`)
}

async function exportStayRegistration(row: Doc) {
  let stay = row
  if (!String(stay.guest_signature_data || '').startsWith('data:image') && isStaySigned(stay)) {
    try {
      stay = (await api.get<{ data: Doc }>(`/hospitality/docs/${encodeURIComponent(String(row.id))}`)).data
    } catch {
      stay = row
    }
  }
  const sig = String(stay.guest_signature_data || '')
  const sigHtml = sig.startsWith('data:image')
    ? `<p><strong>${escapeHtml(t('hotel.stays.guestSignature'))}</strong><br><img class="sign" src="${sig}" alt=""></p>`
    : `<p><strong>${escapeHtml(t('hotel.stays.guestSignature'))}:</strong> ${isStaySigned(stay) ? escapeHtml(t('hotel.stays.sign.signed')) : '—'}</p>`
  printStayExport(t('hotel.stays.detail.exportRegistration'), `
    <h1>${escapeHtml(t('hotel.stays.detail.exportRegistration'))}</h1>
    <h2>${escapeHtml(t('hotel.stays.detail.client'))}</h2>
    <p>${escapeHtml(stay.guest_name || '—')}<br>${escapeHtml(stay.guest_email || '')}<br>${escapeHtml(stay.guest_phone || '')}</p>
    <p class="meta">${escapeHtml(t('hotel.stays.nationality'))}: ${escapeHtml(stay.nationality || '—')} · ${escapeHtml(documentTypeShort(stay))}</p>
    <h2>${escapeHtml(t('hotel.stays.detail.stayDetails'))}</h2>
    <p>#${escapeHtml(stayRoomNumber(stay))} · ${escapeHtml(stayTypeName(stay))}<br>
    ${escapeHtml(formatDateTime(stay.arrive_on))} → ${escapeHtml(formatDateTime(stay.depart_on))} · ${stayNights(stay)} ${escapeHtml(t('hotel.reservations.nights'))}</p>
    ${sigHtml}`)
}

function formatDateTime(value?: string | null, withTime = true) {
  if (!value) return '—'
  const iso = String(value)
  const hasTime = iso.includes('T') || /\d{2}:\d{2}/.test(iso)
  const d = new Date(hasTime ? iso : `${iso.slice(0, 10)}T12:00:00`)
  if (Number.isNaN(d.getTime())) return iso.slice(0, 10)
  return d.toLocaleString(undefined, withTime
    ? { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }
    : { month: 'short', day: 'numeric', year: 'numeric' })
}

function detailPricePerNight(row: Doc) {
  const special = Number(row.special_price_cents || 0)
  if (special > 0) return special
  const rate = Number(row.type_rate_cents || 0)
  if (rate > 0) return rate
  const nights = stayNights(row) || 1
  const sub = Number(row.room_subtotal_cents || 0)
  return sub > 0 ? Math.round(sub / nights) : 0
}

function detailDepositCents(row: Doc) {
  return Math.max(0, Number(row.deposit_cents || 0))
}

function detailChargesCents(row: Doc) {
  const folio = folioOf(row)
  if (folio?.lines && Array.isArray(folio.lines)) {
    return folio.lines
      .filter((line: Doc) => Number(line.amount || 0) > 0 && String(line.kind || '') !== 'deposit')
      .reduce((sum: number, line: Doc) => sum + Number(line.amount || 0), 0)
  }
  return Math.max(0, Number(row.amount_due_cents || 0))
}

function detailPaidCents(row: Doc) {
  const folio = folioOf(row)
  if (folio?.lines && Array.isArray(folio.lines)) {
    return folio.lines
      .filter((line: Doc) => Number(line.amount || 0) < 0)
      .reduce((sum: number, line: Doc) => sum + Math.abs(Number(line.amount || 0)), 0)
  }
  return Math.max(0, Number(row.amount_collected_cents || 0))
}

function detailFolioBalanceCents(row: Doc) {
  return Math.max(0, detailChargesCents(row) - detailPaidCents(row))
}

function detailFolioLines(row: Doc): Doc[] {
  const folio = folioOf(row)
  if (folio?.lines && Array.isArray(folio.lines) && folio.lines.length) {
    return folio.lines.slice().sort((a: Doc, b: Doc) =>
      String(a.created_at || '').localeCompare(String(b.created_at || '')),
    )
  }
  const lines: Doc[] = []
  const nights = stayNights(row) || 1
  const rate = detailPricePerNight(row)
  const currency = stayCurrency(row)
  if (rate > 0) {
    for (let i = 0; i < nights; i++) {
      const arrive = new Date(`${String(row.arrive_on || '').slice(0, 10)}T00:00:00`)
      if (!Number.isNaN(arrive.getTime())) arrive.setDate(arrive.getDate() + i)
      const next = new Date(arrive)
      next.setDate(next.getDate() + 1)
      const a = arrive.toISOString().slice(0, 10)
      const b = next.toISOString().slice(0, 10)
      lines.push({
        id: `night-${i}`,
        kind: 'room',
        group: 'stay',
        status: 'settled',
        description: t('hotel.stays.detail.nightLine', {
          room: stayRoomNumber(row),
          n: i + 1,
          from: a,
          to: b,
        }),
        amount: rate,
        created_at: a,
        by: row.receptionist_name || '—',
        currency,
      })
    }
  }
  const vat = Number(row.vat_cents || 0)
  if (vat > 0) {
    lines.push({
      id: 'vat',
      kind: 'tax',
      group: 'tax',
      status: 'settled',
      description: t('hotel.stays.detail.vatLineNights', { nights }),
      amount: vat,
      created_at: row.arrive_on,
      by: row.receptionist_name || '—',
    })
  }
  const tc = Number(row.tc_cents || 0)
  if (tc > 0) {
    lines.push({
      id: 'tc',
      kind: 'tax',
      group: 'tax',
      status: 'settled',
      description: t('hotel.stays.detail.tcLineNights', { nights }),
      amount: tc,
      created_at: row.arrive_on,
      by: row.receptionist_name || '—',
    })
  }
  const deposit = detailDepositCents(row)
  if (deposit > 0) {
    lines.push({
      id: 'deposit',
      kind: 'deposit',
      group: 'payment',
      status: 'deposit',
      description: t('hotel.stays.detail.depositLine', { method: row.payment_method || 'cash' }),
      amount: deposit,
      created_at: row.arrive_on,
      by: row.receptionist_name || '—',
    })
  }
  const collected = Number(row.amount_collected_cents || 0)
  if (collected > 0 && row.payment_mode === 'collect_now') {
    lines.push({
      id: 'payment',
      kind: 'payment',
      group: 'payment',
      status: 'paid',
      description: t('hotel.stays.detail.paymentLine', { method: row.payment_method || 'cash' }),
      amount: -collected,
      created_at: row.arrive_on,
      by: row.receptionist_name || '—',
    })
  }
  return lines
}

function lineGroupLabel(line: Doc) {
  const kind = String(line.kind || line.group || '')
  if (kind === 'room' || kind === 'stay') return t('hotel.stays.detail.groupStay')
  if (kind === 'tax' || kind === 'vat' || kind === 'tc') return t('hotel.stays.detail.groupTax')
  if (kind === 'payment' || kind === 'deposit') return t('hotel.stays.detail.groupPayment')
  if (kind === 'missing_amenity' || kind === 'damaged_amenity' || kind === 'late_departure' || kind === 'early_arrival') {
    return t('hotel.stays.detail.groupFees')
  }
  return t('hotel.stays.detail.groupOther')
}

function lineStatusLabel(line: Doc) {
  const status = String(line.status || '')
  if (status === 'deposit') return t('hotel.stays.detail.txDeposit')
  if (Number(line.amount || 0) < 0) return t('hotel.stays.detail.txPaid')
  return t('hotel.stays.detail.txSettled')
}

function detailRoom(row: Doc) {
  return rooms.value.find(r => r.id === row.room_id) ?? null
}

function journeySteps(row: Doc) {
  const status = String(row.status || '')
  const board = stayBoardStatus(row)
  const checkedIn = status === 'checked_in' || board === 'enregistre' || board === 'en_sejour'
  const checkedOut = status === 'checked_out' || board === 'parti'
  const confirmed = checkedIn || checkedOut || status === 'confirmed' || status === 'reserved'
  return [
    { id: 'reserved', label: t('hotel.stays.detail.journey.reserved'), done: confirmed },
    { id: 'confirmed', label: t('hotel.stays.detail.journey.confirmed'), done: confirmed },
    { id: 'arrived', label: t('hotel.stays.detail.journey.arrived'), done: checkedIn || checkedOut },
    { id: 'in_room', label: t('hotel.stays.detail.journey.inRoom'), done: checkedIn || checkedOut, current: checkedIn && !checkedOut },
    { id: 'depart', label: t('hotel.stays.detail.journey.depart'), done: checkedOut },
    { id: 'closed', label: t('hotel.stays.detail.journey.closed'), done: checkedOut },
  ]
}

function detailTimeline(row: Doc) {
  const events: Array<{ title: string; at: string; key: string }> = []
  const checkInRaw = row.checked_in_at || row.arrive_on
  if (checkInRaw) {
    events.push({
      title: t('hotel.stays.detail.timelineCheckedIn'),
      at: formatDateTime(checkInRaw),
      key: `checkin:${String(checkInRaw)}`,
    })
  }

  const seen = new Set<string>()
  for (const line of detailFolioLines(row)) {
    const title = String(line.description || line.kind || '—').trim()
    if (!title) continue
    const atRaw = line.created_at || checkInRaw || row.arrive_on
    const key = `${title}|${String(atRaw || '').slice(0, 19)}|${line.id || ''}`
    if (seen.has(key)) continue
    seen.add(key)
    events.push({
      title,
      at: formatDateTime(atRaw),
      key,
    })
  }

  if (row.depart_on) {
    const departRaw = String(row.depart_on)
    const departAt = departRaw.includes('T') ? departRaw : `${departRaw.slice(0, 10)}T12:00:00`
    events.push({
      title: t('hotel.stays.detail.timelineExpectedOut'),
      at: formatDateTime(departAt),
      key: `depart:${departAt}`,
    })
  }

  return events
}

const detailTabs = computed(() => ([
  { id: 'overview' as const, label: t('hotel.stays.detail.tabs.overview') },
  { id: 'room_service' as const, label: t('hotel.stays.detail.tabs.roomService') },
  { id: 'journal' as const, label: t('hotel.stays.detail.tabs.journal') },
  { id: 'folio' as const, label: t('hotel.stays.detail.tabs.folio') },
]))

function documentTypeShort(row: Doc) {
  const type = documentLabel(row.id_document_type)
  const num = row.id_document_number ? ` ${row.id_document_number}` : ''
  return `${row.nationality || '—'} · ${type}${num}`
}

function exportStaysCsv() {
  const header = ['Client', 'Email', 'Chambre', 'Type', 'Arrivee', 'Depart', 'Nuits', 'Canal', 'Statut', 'Solde']
  const lines = filteredStays.value.map((row) => [
    row.guest_name || '',
    row.guest_email || '',
    row.room_number || '',
    row.type_name || '',
    String(row.arrive_on || '').slice(0, 10),
    String(row.depart_on || '').slice(0, 10),
    String(stayNights(row)),
    stayChannelLabel(row),
    boardStatusLabel(row),
    String(stayBalanceCents(row) / 100),
  ].map(v => `"${String(v).replace(/"/g, '""')}"`).join(','))
  const blob = new Blob([[header.join(','), ...lines].join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `sejours-${todayIso()}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const typeOptions = computed(() =>
  roomTypes.value
    .filter(item => item.is_active !== false && item.status !== 'inactive')
    .slice()
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })),
)

const selectedType = computed(() => roomTypes.value.find(r => r.id === form.value.type_id) ?? null)

const vacantRooms = computed(() =>
  rooms.value
    .filter(room => room.is_active !== false)
    .filter(room => !['occupied', 'reserved'].includes(String(room.status ?? 'vacant')))
    .filter(room => String(room.housekeeping_status ?? 'clean') !== 'out_of_service')
    .filter(room => !form.value.type_id || room.type_id === form.value.type_id)
    .slice()
    .sort((a, b) => String(a.number ?? '').localeCompare(String(b.number ?? ''), undefined, { numeric: true })),
)

const selectedRoom = computed(() => rooms.value.find(r => r.id === form.value.room_id) ?? null)

const nights = computed(() => {
  if (!form.value.arrive_on || !form.value.depart_on) return 0
  const a = new Date(form.value.arrive_on)
  const b = new Date(form.value.depart_on)
  return Math.max(0, Math.round((b.getTime() - a.getTime()) / 86400000))
})

const typeRateCents = computed(() =>
  Number(selectedType.value?.base_price_cents ?? selectedType.value?.rate ?? selectedRoom.value?.price_override_cents ?? 0),
)

const currency = computed(() => getAppCurrency())

const roomSubtotalCents = computed(() => {
  if (form.value.special_price.trim()) return parseMoneyInput(form.value.special_price)
  return typeRateCents.value * nights.value
})

const stayTaxes = computed(() => computeStayTaxes(roomSubtotalCents.value, hotelSettings.value))
const vatCents = computed(() => stayTaxes.value.vatCents)
const tcCents = computed(() => stayTaxes.value.tcCents)
const amountDueCents = computed(() => stayTaxes.value.totalCents)

const amountCollectedCents = computed(() =>
  form.value.payment_mode === 'collect_now' && form.value.amount_collected.trim()
    ? parseMoneyInput(form.value.amount_collected)
    : 0,
)

const depositCents = computed(() =>
  form.value.deposit.trim() ? parseMoneyInput(form.value.deposit) : 0,
)

const specialPriceCents = computed(() =>
  form.value.special_price.trim() ? parseMoneyInput(form.value.special_price) : 0,
)

const paymentComplete = computed(() =>
  form.value.payment_mode === 'collect_now' && amountDueCents.value > 0 && amountCollectedCents.value >= amountDueCents.value,
)

const paymentStatusLabel = computed(() => {
  if (form.value.payment_mode === 'credit') return t('hotel.stays.onCreditShort')
  if (paymentComplete.value) return t('hotel.stays.fullyPaidShort')
  if (amountCollectedCents.value > 0) return t('hotel.stays.partialCreditShort')
  return t('hotel.stays.collectNow')
})

const paymentStayLabel = computed(() => {
  const method = form.value.payment_mode === 'collect_now'
    ? payMethodLabel(form.value.payment_method)
    : t('hotel.stays.credit')
  return `${method} · ${paymentStatusLabel.value} · ${formatMoney(amountDueCents.value, currency.value)}`
})

const documentConfirmLabel = computed(() => {
  const type = form.value.id_document_type ? documentLabel(form.value.id_document_type) : '—'
  const filled = form.value.id_document_number.trim() || form.value.id_document_name || form.value.id_mode === 'blank'
    ? t('hotel.stays.filled')
    : '—'
  return `${type} · ${filled}`
})

const guestSignatureConfirmLabel = computed(() => {
  const guest = form.value.guest_signature_mode === 'upload'
    ? (sigFile.value || form.value.guest_signature_name ? t('hotel.stays.filled') : '—')
    : t('hotel.stays.filled')
  return t('hotel.stays.signaturesSummary', {
    guest,
    receptionist: receptionistName.value,
  })
})

const roomConfirmLabel = computed(() => {
  if (!selectedRoom.value) return '—'
  const number = selectedRoom.value.number || selectedRoom.value.id
  const type = selectedType.value?.name || selectedRoom.value.type_name || ''
  return type ? `#${number} · ${type}` : `#${number}`
})

const peopleConfirmLabel = computed(() =>
  t('hotel.stays.peopleSummary', {
    adults: Number(form.value.adults) || 1,
    children: Number(form.value.children) || 0,
    nights: nights.value,
  }),
)

const receptionistName = computed(() => auth.user?.name || '—')

const customers = computed(() => store.customers.filter(c => c.is_active !== false))

const filteredCustomers = computed(() => {
  const q = customerSearch.value.trim().toLowerCase()
  if (!q) return customers.value.slice(0, 40)
  return customers.value
    .filter((c) => {
      const hay = `${c.name} ${c.email ?? ''} ${c.phone ?? ''}`.toLowerCase()
      return hay.includes(q)
    })
    .slice(0, 40)
})

const selectedCustomer = computed(() =>
  customers.value.find(c => c.id === form.value.customer_id) ?? null,
)

const steps = computed(() => [
  { id: 1 as Step, label: t('hotel.stays.steps.client') },
  { id: 2 as Step, label: t('hotel.stays.steps.room') },
  { id: 3 as Step, label: t('hotel.stays.steps.confirm') },
])

watch(() => form.value.client_mode, (mode) => {
  if (mode === 'new') form.value.customer_id = ''
})

watch(() => form.value.type_id, () => {
  if (form.value.room_id && !vacantRooms.value.some(r => r.id === form.value.room_id)) {
    form.value.room_id = vacantRooms.value[0]?.id ?? ''
  }
})

onMounted(async () => {
  await Promise.all([load(), store.loadCustomers().catch(() => undefined)])
})

function blankForm() {
  const today = new Date()
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)
  const depositDefault = moneyFromSettingsCents(hotelSettings.value.deposit_amount_cents)
  return {
    client_mode: 'new' as ClientMode,
    customer_id: '',
    guest_name: '',
    guest_email: '',
    guest_phone: '',
    birth_place: '',
    date_of_birth: '',
    nationality: '',
    residence: '',
    profession: '',
    company_name: '',
    contact_person: '',
    origin_place: '',
    id_mode: 'upload' as IdMode,
    id_document_type: '' as IdDocumentType | '',
    id_document_number: '',
    id_document_issue_place: '',
    id_document_name: '',
    type_id: '',
    room_id: '',
    arrive_on: toDateInput(today),
    depart_on: toDateInput(tomorrow),
    adults: '1',
    children: '0',
    channel: 'walk_in' as Channel,
    purpose: '',
    companions: '',
    payment_mode: 'collect_now' as PaymentMode,
    amount_collected: '',
    payment_method: 'cash' as PayMethod,
    voucher_reference: '',
    deposit: depositDefault > 0 ? String(depositDefault) : '',
    special_price: '',
    special_price_reason: '',
    special_requests: '',
    guest_signature_mode: 'dotted' as SigMode,
    guest_signature_name: '',
  }
}

function toDateInput(d: Date) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function metaString(item: Customer, key: string) {
  const value = item.metadata?.[key]
  return typeof value === 'string' ? value : ''
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_STAY_KINDS]))).data.docs
    if (!form.value.type_id) form.value.type_id = typeOptions.value[0]?.id ?? ''
    if (!form.value.room_id) form.value.room_id = vacantRooms.value[0]?.id ?? ''
    if (!form.value.deposit.trim() && Number(hotelSettings.value.deposit_amount_cents || 0) > 0) {
      form.value.deposit = String(moneyFromSettingsCents(hotelSettings.value.deposit_amount_cents))
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function pickCustomer(customer: Customer) {
  form.value.customer_id = customer.id
  form.value.guest_name = customer.name
  form.value.guest_email = customer.email ?? ''
  form.value.guest_phone = customer.phone ?? ''
  form.value.date_of_birth = String(customer.date_of_birth ?? '').slice(0, 10)
  form.value.company_name = customer.company_name ?? metaString(customer, 'company_name')
  form.value.birth_place = metaString(customer, 'birth_place')
  form.value.nationality = metaString(customer, 'nationality')
  form.value.residence = metaString(customer, 'residence')
  form.value.profession = metaString(customer, 'profession')
  form.value.contact_person = metaString(customer, 'contact_person')
  form.value.origin_place = metaString(customer, 'origin_place')
  const docType = metaString(customer, 'id_document_type')
  form.value.id_document_type = documentTypes.includes(docType as IdDocumentType) ? docType as IdDocumentType : ''
  form.value.id_document_number = metaString(customer, 'id_document_number')
  form.value.id_document_issue_place = metaString(customer, 'id_document_issue_place')
  form.value.id_document_name = metaString(customer, 'id_document_name')
  if (form.value.id_document_name) form.value.id_mode = 'blank'
  customerSearch.value = ''
}

function resetForm() {
  if (idPreview.value) URL.revokeObjectURL(idPreview.value)
  if (sigPreview.value) URL.revokeObjectURL(sigPreview.value)
  idFile.value = null
  idPreview.value = ''
  sigFile.value = null
  sigPreview.value = ''
  step.value = 1
  form.value = blankForm()
  form.value.type_id = typeOptions.value[0]?.id ?? ''
  form.value.room_id = vacantRooms.value[0]?.id ?? ''
  error.value = ''
}

function validateClient(): boolean {
  if (form.value.client_mode === 'existing' && !form.value.customer_id) {
    error.value = t('hotel.stays.errors.pickCustomer')
    return false
  }
  if (!form.value.guest_name.trim()) {
    error.value = t('hotel.stays.errors.guestName')
    return false
  }
  if (!form.value.nationality.trim()) {
    error.value = t('hotel.stays.errors.nationality')
    return false
  }
  if (!form.value.id_document_type) {
    error.value = t('hotel.stays.errors.documentType')
    return false
  }
  if (form.value.id_mode === 'upload' && !idFile.value && !form.value.id_document_name) {
    error.value = t('hotel.stays.errors.documentFile')
    return false
  }
  if (!form.value.id_document_number.trim()) {
    error.value = t('hotel.stays.errors.documentNumber')
    return false
  }
  error.value = ''
  return true
}

function validateRoom(): boolean {
  if (!form.value.type_id) {
    error.value = t('hotel.stays.errors.type')
    return false
  }
  if (!form.value.room_id) {
    error.value = t('hotel.stays.errors.room')
    return false
  }
  if (!form.value.arrive_on || !form.value.depart_on) {
    error.value = t('hotel.stays.errors.dates')
    return false
  }
  if (form.value.depart_on <= form.value.arrive_on) {
    error.value = t('hotel.stays.errors.departAfter')
    return false
  }
  if (!form.value.purpose.trim()) {
    error.value = t('hotel.stays.errors.purpose')
    return false
  }
  if (form.value.payment_mode === 'collect_now' && !form.value.amount_collected.trim()) {
    error.value = t('hotel.stays.errors.amountCollected')
    return false
  }
  if (form.value.payment_mode === 'collect_now' && form.value.payment_method === 'voucher' && !form.value.voucher_reference.trim()) {
    error.value = t('hotel.stays.errors.voucher')
    return false
  }
  error.value = ''
  return true
}

function goStep(next: Step) {
  if (next > step.value) {
    if (step.value === 1 && !validateClient()) return
    if (step.value === 2 && next === 3 && !validateRoom()) return
    if (next === 3 && (!validateClient() || !validateRoom())) return
  }
  step.value = next
}

function onIdFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  if (idPreview.value) URL.revokeObjectURL(idPreview.value)
  idFile.value = file
  form.value.id_document_name = file.name
  idPreview.value = file.type.startsWith('image/') ? URL.createObjectURL(file) : ''
}

function onSigFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  if (sigPreview.value) URL.revokeObjectURL(sigPreview.value)
  sigFile.value = file
  form.value.guest_signature_name = file.name
  sigPreview.value = file.type.startsWith('image/') ? URL.createObjectURL(file) : ''
}

function setIdMode(mode: IdMode) {
  form.value.id_mode = mode
  if (mode === 'blank') {
    if (idPreview.value) URL.revokeObjectURL(idPreview.value)
    idFile.value = null
    idPreview.value = ''
  }
}

function setSigMode(mode: SigMode) {
  form.value.guest_signature_mode = mode
  if (mode !== 'upload') {
    if (sigPreview.value) URL.revokeObjectURL(sigPreview.value)
    sigFile.value = null
    sigPreview.value = ''
    form.value.guest_signature_name = ''
  }
}

async function fileToDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result ?? ''))
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}

async function save() {
  if (!validateClient()) {
    step.value = 1
    return
  }
  if (!validateRoom()) {
    step.value = 2
    return
  }
  saving.value = true
  error.value = ''
  try {
    let customerId = form.value.customer_id
    const identityMeta = {
      birth_place: form.value.birth_place.trim() || null,
      nationality: form.value.nationality.trim(),
      residence: form.value.residence.trim() || null,
      profession: form.value.profession.trim() || null,
      company_name: form.value.company_name.trim() || null,
      contact_person: form.value.contact_person.trim() || null,
      origin_place: form.value.origin_place.trim() || null,
      id_document_type: form.value.id_document_type,
      id_document_number: form.value.id_document_number.trim(),
      id_document_issue_place: form.value.id_document_issue_place.trim() || null,
      id_document_name: form.value.id_document_name.trim() || null,
    }
    const existingMeta = selectedCustomer.value?.metadata && typeof selectedCustomer.value.metadata === 'object'
      ? selectedCustomer.value.metadata
      : {}

    if (form.value.client_mode === 'new' || !customerId) {
      const created = await store.saveCustomer({
        name: form.value.guest_name.trim(),
        email: form.value.guest_email.trim() || null,
        phone: form.value.guest_phone.trim() || null,
        date_of_birth: form.value.date_of_birth || null,
        company_name: form.value.company_name.trim() || null,
        is_active: true,
        metadata: identityMeta,
      })
      customerId = created.id
    } else {
      await store.saveCustomer({
        name: form.value.guest_name.trim(),
        email: form.value.guest_email.trim() || null,
        phone: form.value.guest_phone.trim() || null,
        date_of_birth: form.value.date_of_birth || null,
        company_name: form.value.company_name.trim() || null,
        is_active: true,
        metadata: { ...existingMeta, ...identityMeta },
      }, customerId)
    }
    await store.loadCustomers().catch(() => undefined)

    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'walk_in_check_in',
      customer_id: customerId,
      guest_name: form.value.guest_name.trim(),
      guest_email: form.value.guest_email.trim() || null,
      guest_phone: form.value.guest_phone.trim() || null,
      birth_place: form.value.birth_place.trim() || null,
      date_of_birth: form.value.date_of_birth || null,
      nationality: form.value.nationality.trim(),
      residence: form.value.residence.trim() || null,
      profession: form.value.profession.trim() || null,
      company_name: form.value.company_name.trim() || null,
      contact_person: form.value.contact_person.trim() || null,
      origin_place: form.value.origin_place.trim() || null,
      id_document_type: form.value.id_document_type,
      id_document_number: form.value.id_document_number.trim(),
      id_document_issue_place: form.value.id_document_issue_place.trim() || null,
      id_document_name: form.value.id_document_name.trim() || null,
      id_document_data: idFile.value && idFile.value.size <= 400_000
        ? await fileToDataUrl(idFile.value)
        : null,
      type_id: form.value.type_id,
      room_id: form.value.room_id,
      arrive_on: form.value.arrive_on,
      depart_on: form.value.depart_on,
      adults: Number(form.value.adults) || 1,
      children: Number(form.value.children) || 0,
      channel: form.value.channel,
      purpose: form.value.purpose.trim(),
      companions: form.value.companions.trim() || null,
      special_requests: form.value.special_requests.trim() || null,
      payment_mode: form.value.payment_mode,
      amount_due_cents: amountDueCents.value,
      amount_collected_cents: form.value.payment_mode === 'collect_now' ? amountCollectedCents.value : 0,
      payment_method: form.value.payment_mode === 'collect_now' ? form.value.payment_method : null,
      voucher_reference: form.value.payment_method === 'voucher' ? form.value.voucher_reference.trim() || null : null,
      deposit_cents: form.value.deposit.trim() ? parseMoneyInput(form.value.deposit) : null,
      special_price_cents: form.value.special_price.trim() ? parseMoneyInput(form.value.special_price) : null,
      special_price_reason: form.value.special_price_reason.trim() || null,
      room_subtotal_cents: roomSubtotalCents.value,
      vat_cents: vatCents.value,
      tc_cents: tcCents.value,
      receptionist_name: receptionistName.value,
      guest_signature_mode: form.value.guest_signature_mode,
      guest_signature_name: form.value.guest_signature_name.trim() || null,
      guest_signature_data: sigFile.value && sigFile.value.size <= 400_000
        ? await fileToDataUrl(sigFile.value)
        : null,
    })).data.docs
    formOpen.value = false
    resetForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function openCreate() {
  resetForm()
  formOpen.value = true
}

function closeForm() {
  formOpen.value = false
  resetForm()
}

function isStaySigned(row: Doc) {
  return Boolean(row.has_signature || row.guest_signed_at || row.guest_signature_data)
}

function canOpenSign(row: Doc) {
  if (isStaySigned(row)) return false
  const status = String(row.status || '')
  if (status === 'checked_in' || status === 'confirmed' || status === 'reserved') return true
  const board = stayBoardStatus(row)
  return board === 'enregistre' || board === 'en_sejour' || board === 'en_attente'
}

function stayRoomLabel(row: Doc) {
  const parts = [
    stayRoomNumber(row) !== '—' ? `#${stayRoomNumber(row)}` : null,
    row.stay_code || null,
    stayTypeName(row) !== '—' ? stayTypeName(row) : null,
  ].filter(Boolean)
  return parts.join(' · ') || '—'
}

function stopSignPoll() {
  if (signPollTimer) {
    clearInterval(signPollTimer)
    signPollTimer = null
  }
  if (signCloseTimer) {
    clearTimeout(signCloseTimer)
    signCloseTimer = null
  }
}

function startSignPoll() {
  stopSignPoll()
  if (!signOpen.value || signTab.value !== 'scan' || signRemoteDone.value) return
  signPollTimer = setInterval(() => {
    void pollRemoteSignature()
  }, 1000)
  void pollRemoteSignature()
}

async function refreshDocsQuiet() {
  const next = (await api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...HOTEL_STAY_KINDS]))).data.docs
  docs.value = next
  return next
}

async function applySignedStay(id: string) {
  try {
    const next = await refreshDocsQuiet()
    const fresh = next.find(d => d.id === id)
    if (!fresh) return
    if (detailStay.value?.id === id) detailStay.value = fresh
    if (signOpen.value && signingStay.value?.id === id && isStaySigned(fresh)) {
      markSignReceived(fresh)
    } else if (signingStay.value?.id === id) {
      signingStay.value = fresh
    }
  } catch {
    // Keep waiting; next poll / realtime event will retry.
  }
}

async function pollRemoteSignature() {
  if (!signOpen.value || !signingStay.value || signRemoteDone.value || signTab.value !== 'scan') return
  const id = String(signingStay.value.id)
  try {
    const next = await refreshDocsQuiet()
    const fresh = next.find(d => d.id === id)
    if (!fresh) return
    signingStay.value = fresh
    if (detailStay.value?.id === id) detailStay.value = fresh
    if (isStaySigned(fresh)) {
      markSignReceived(fresh)
    }
  } catch {
    // Keep waiting silently while the guest signs on another device.
  }
}

function markSignReceived(fresh: Doc) {
  stopSignPoll()
  signTab.value = 'scan'
  signRemoteDone.value = true
  signUrl.value = ''
  signingStay.value = fresh
  if (detailStay.value?.id === fresh.id) detailStay.value = fresh
  signCloseTimer = setTimeout(() => {
    if (signRemoteDone.value && signOpen.value) closeSign()
  }, 4500)
}

async function openSign(row: Doc) {
  error.value = ''
  stopSignPoll()
  signTab.value = 'scan'
  signDrawn.value = false
  signLinkCopied.value = false
  signRemoteDone.value = false
  signUrl.value = ''
  signingStay.value = row
  signOpen.value = true
  signLoading.value = true
  try {
    const payload = await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'create_stay_sign_link',
      reservation_id: row.id,
    })
    docs.value = payload.data.docs
    const fresh = docs.value.find(d => d.id === row.id) ?? row
    signingStay.value = fresh
    if (isStaySigned(fresh)) {
      markSignReceived(fresh)
      return
    }
    const token = String(fresh.sign_token || '')
    const lang = String(locale.value || 'fr').slice(0, 2)
    signUrl.value = token
      ? `${window.location.origin}/sign/stay/${token}?lang=${encodeURIComponent(lang)}`
      : ''
    if (!token) {
      error.value = t('hotel.stays.sign.invalidLink')
    } else {
      startSignPoll()
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    signLoading.value = false
  }
}

async function copySignLink() {
  if (!signUrl.value) return
  try {
    await navigator.clipboard.writeText(signUrl.value)
    signLinkCopied.value = true
    window.setTimeout(() => { signLinkCopied.value = false }, 2000)
  } catch {
    error.value = t('hotel.stays.sign.copyFailed')
  }
}

function closeSign() {
  stopSignPoll()
  signOpen.value = false
  signingStay.value = null
  signUrl.value = ''
  signDrawn.value = false
  signLinkCopied.value = false
  signLoading.value = false
  signRemoteDone.value = false
  error.value = ''
}

const qrImageUrl = computed(() =>
  signUrl.value && !signRemoteDone.value
    ? `https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(signUrl.value)}`
    : '',
)

const signModalTitle = computed(() =>
  signRemoteDone.value ? t('hotel.stays.sign.doneTitle') : t('hotel.stays.sign.scanTitle'),
)

watch(signTab, async (tab) => {
  if (tab === 'draw' && signOpen.value) {
    stopSignPoll()
    await nextTick()
    setupSignCanvas()
  } else if (tab === 'scan' && signOpen.value && !signRemoteDone.value && signUrl.value) {
    startSignPoll()
  }
})

watch(signOpen, (open) => {
  if (!open) stopSignPoll()
})

useRealtimeSync(['stay.signed'], async () => {
  const id = signingStay.value?.id
    ? String(signingStay.value.id)
    : ''
  if (id && signOpen.value) {
    await applySignedStay(id)
    return
  }
  try {
    await refreshDocsQuiet()
  } catch {
    // Ignore background refresh errors.
  }
})

onMounted(() => {
  if (typeof BroadcastChannel === 'undefined') return
  signBroadcast = new BroadcastChannel(STAY_SIGN_CHANNEL)
  signBroadcast.onmessage = (event: MessageEvent) => {
    const data = event.data as { type?: string; id?: string } | null
    if (data?.type !== 'stay.signed' || !data.id) return
    void applySignedStay(String(data.id))
  }
})

onBeforeUnmount(() => {
  stopSignPoll()
  signBroadcast?.close()
  signBroadcast = null
})

function setupSignCanvas() {
  const canvas = signCanvas.value
  if (!canvas) return
  const ratio = window.devicePixelRatio || 1
  const width = canvas.clientWidth || 320
  const height = 160
  canvas.width = Math.floor(width * ratio)
  canvas.height = Math.floor(height * ratio)
  signCtx = canvas.getContext('2d')
  if (!signCtx) return
  signCtx.setTransform(ratio, 0, 0, ratio, 0, 0)
  signCtx.lineWidth = 2.2
  signCtx.lineCap = 'round'
  signCtx.strokeStyle = '#0f172a'
  signCtx.fillStyle = '#fff'
  signCtx.fillRect(0, 0, width, height)
  signDrawn.value = false
}

function signPointerPos(event: PointerEvent) {
  const canvas = signCanvas.value!
  const rect = canvas.getBoundingClientRect()
  return { x: event.clientX - rect.left, y: event.clientY - rect.top }
}

function startSignDraw(event: PointerEvent) {
  if (!signCtx) return
  signPainting = true
  const p = signPointerPos(event)
  signCtx.beginPath()
  signCtx.moveTo(p.x, p.y)
  signCanvas.value?.setPointerCapture(event.pointerId)
}

function moveSignDraw(event: PointerEvent) {
  if (!signPainting || !signCtx) return
  const p = signPointerPos(event)
  signCtx.lineTo(p.x, p.y)
  signCtx.stroke()
  signDrawn.value = true
}

function endSignDraw(event: PointerEvent) {
  if (!signPainting) return
  signPainting = false
  signCanvas.value?.releasePointerCapture(event.pointerId)
}

async function saveDrawnSignature() {
  if (!signingStay.value || !signCanvas.value || !signDrawn.value) return
  signSaving.value = true
  error.value = ''
  try {
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'submit_stay_signature',
      reservation_id: signingStay.value.id,
      guest_signature_data: signCanvas.value.toDataURL('image/png'),
    })).data.docs
    closeSign()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    signSaving.value = false
  }
}

async function checkout(row: Doc) {
  checkoutStay.value = row
  checkoutItems.value = stayInventory(row).map(item => ({
    amenity_id: item.id,
    name: item.name,
    icon_key: item.icon_key,
    replacement_value_cents: item.replacement_value_cents,
    status: 'ok' as const,
    amount: item.replacement_value_cents ? String(item.replacement_value_cents / 100) : '',
  }))
  checkoutOpen.value = true
  error.value = ''
}

function stayInventory(row: Doc) {
  const snap = Array.isArray(row.inventory_amenities) ? row.inventory_amenities : []
  if (snap.length) {
    return snap.map((item: Doc) => ({
      id: String(item.id ?? ''),
      name: String(item.name ?? item.id ?? ''),
      icon_key: String(item.icon_key ?? ''),
      replacement_value_cents: Number(item.replacement_value_cents ?? 0),
    })).filter(item => item.id)
  }
  const room = rooms.value.find(r => r.id === row.room_id)
  const type = roomTypes.value.find(t => t.id === (room?.type_id || row.type_id))
  const typeIds = Array.isArray(type?.amenity_ids) ? type.amenity_ids.map(String) : []
  const extraIds = Array.isArray(room?.amenity_ids) ? room.amenity_ids.map(String) : []
  const ids = [...new Set([...typeIds, ...extraIds])]
  return ids.map((id) => {
    const amenity = amenities.value.find(item => item.id === id)
    return {
      id,
      name: String(amenity?.name ?? id),
      icon_key: String(amenity?.icon_key ?? ''),
      replacement_value_cents: Number(amenity?.replacement_value_cents ?? 0),
    }
  })
}

function setCheckoutStatus(index: number, status: 'ok' | 'missing' | 'damaged') {
  const item = checkoutItems.value[index]
  if (!item) return
  item.status = status
  if (status !== 'ok' && !item.amount && item.replacement_value_cents) {
    item.amount = String(item.replacement_value_cents / 100)
  }
}

const checkoutChargeCents = computed(() =>
  checkoutItems.value.reduce((sum, item) => {
    if (item.status === 'ok') return sum
    return sum + parseMoneyInput(item.amount || '0')
  }, 0),
)

function closeCheckout() {
  checkoutOpen.value = false
  checkoutStay.value = null
  checkoutItems.value = []
  checkoutSaving.value = false
}

async function confirmCheckout() {
  const row = checkoutStay.value
  if (!row) return
  checkoutSaving.value = true
  error.value = ''
  try {
    const missing_items = checkoutItems.value
      .filter(item => item.status !== 'ok')
      .map(item => ({
        amenity_id: item.amenity_id,
        condition: item.status,
        amount_cents: parseMoneyInput(item.amount || '0'),
      }))
    docs.value = (await api.post<{ data: { docs: Doc[] } }>('/hospitality/actions', {
      action: 'check_out',
      reservation_id: row.id,
      missing_items,
    })).data.docs
    if (!form.value.room_id) form.value.room_id = vacantRooms.value[0]?.id ?? ''
    closeCheckout()
    closeDetail()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    checkoutSaving.value = false
  }
}

function documentLabel(type?: string) {
  if (!type) return '—'
  const path = `hotel.stays.documentTypes.${type}`
  return t(path) !== path ? t(path) : type
}

function channelLabel(channel?: string) {
  return t(`hotel.reservations.channels.${channel || 'walk_in'}`)
}

function payMethodLabel(method: string) {
  return t(`hotel.stays.payMethods.${method}`)
}

function typePriceLabel(type: Doc) {
  const cents = Number(type.base_price_cents ?? type.rate ?? 0)
  const cur = getAppCurrency()
  return `${type.name} — ${formatMoney(cents, cur)}/${t('hotel.rooms.perNight')}`
}

function roomLabel(room: Doc) {
  const number = room.number || room.id
  const type = room.type_name ? ` · ${room.type_name}` : ''
  return `${t('hotel.rooms.room')} ${number}${type}`
}
</script>

<template>
  <HotelChrome>
    <div class="stay">
      <div class="stay__board">
        <div class="stay__board-top">
          <div>
            <h2>{{ t('hotel.tabs.stays') }}</h2>
            <div class="stay__board-links">
              <button
                v-for="tab in boardTabs"
                :key="tab.id"
                type="button"
                class="stay__board-link"
                :class="{ 'stay__board-link--on': boardTab === tab.id }"
                @click="selectBoardTab(tab.id)"
              >
                {{ tab.label }}
              </button>
            </div>
          </div>
          <div class="stay__board-actions">
            <button type="button" class="btn-secondary" :disabled="loading" @click="load">{{ t('common.refresh') }}</button>
            <button type="button" class="btn-secondary" @click="exportStaysCsv">{{ t('hotel.stays.board.export') }}</button>
            <button type="button" class="btn-primary" @click="openCreate">{{ t('hotel.stays.walkInTitle') }}</button>
          </div>
        </div>

        <div class="stay__view-toggle">
          <button type="button" class="stay__toggle" :class="{ 'stay__toggle--on': viewMode === 'plan' }" @click="selectBoardTab('plan')">
            {{ t('hotel.stays.board.roomPlanShort') }}
          </button>
          <button type="button" class="stay__toggle" :class="{ 'stay__toggle--on': viewMode === 'list' && boardTab !== 'folios' }" @click="selectBoardTab('list')">
            {{ t('hotel.stays.board.listTitle') }}
          </button>
        </div>

        <div class="stay__stats">
          <article class="stay__stat">
            <span>{{ t('hotel.stays.board.inHouse') }}</span>
            <strong>{{ stayStats.en_sejour }}</strong>
          </article>
          <article class="stay__stat">
            <span>{{ t('hotel.stays.board.registeredPlural') }}</span>
            <strong>{{ stayStats.enregistre }}</strong>
          </article>
          <article class="stay__stat">
            <span>{{ t('hotel.stays.board.pending') }}</span>
            <strong>{{ stayStats.en_attente }}</strong>
          </article>
          <article class="stay__stat">
            <span>{{ t('hotel.stays.board.departedPlural') }}</span>
            <strong>{{ stayStats.parti }}</strong>
          </article>
          <article class="stay__stat stay__stat--money">
            <span>{{ t('hotel.stays.board.revenue') }}</span>
            <strong>{{ formatMoney(stayStats.revenue) }}</strong>
          </article>
        </div>

        <p v-if="error && !formOpen && !signOpen" class="stay__error stay__error--inline">{{ error }}</p>

        <template v-if="viewMode === 'plan' || boardTab === 'plan'">
          <div class="stay-plan">
            <div class="stay-plan__legend">
              <span v-for="item in planLegend" :key="item.id" class="stay-plan__legend-item">
                <i :class="`stay-plan__dot stay-plan__dot--${item.id}`" />
                {{ item.label }}
              </span>
            </div>

            <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />
            <div v-else-if="!planFloors.length" class="stay__placeholder">
              <AppIcon name="bed" :size="22" />
              <p>{{ t('hotel.stays.board.planEmpty') }}</p>
            </div>
            <div v-else class="stay-plan__floors">
              <section v-for="floor in planFloors" :key="floor.id" class="stay-plan__floor">
                <header class="stay-plan__floor-head">
                  <h3>{{ floor.label }}</h3>
                  <span>{{ t('hotel.stays.board.roomsCount', { count: floor.rooms.length }) }}</span>
                </header>
                <div class="stay-plan__grid">
                  <button
                    v-for="item in floor.rooms"
                    :key="item.room.id"
                    type="button"
                    class="stay-plan__card"
                    :class="`stay-plan__card--${item.tone}`"
                    @click="onPlanRoomClick(item.room, item.stay)"
                  >
                    <span class="stay-plan__status">{{ planToneLabel(item.tone) }}</span>
                    <strong class="stay-plan__num">{{ item.room.number }}</strong>
                    <span class="stay-plan__type">{{ item.typeName }}</span>
                    <template v-if="item.guestName">
                      <span class="stay-plan__guest">{{ item.guestName }}</span>
                      <span v-if="item.outDate" class="stay-plan__out">
                        {{ t('hotel.stays.board.outOn', { date: item.outDate }) }}
                      </span>
                      <span v-if="item.meta" class="stay-plan__meta">{{ item.meta }}</span>
                    </template>
                  </button>
                </div>
              </section>
            </div>
          </div>
        </template>

        <template v-else-if="boardTab === 'folios'">
          <div class="stay__placeholder">
            <AppIcon name="receipt" :size="22" />
            <p>{{ t('hotel.stays.board.foliosSoon') }}</p>
          </div>
        </template>

        <template v-else-if="showStayList()">
          <div class="stay__filters">
            <div class="stay__chips">
              <button
                v-for="item in statusFilters"
                :key="item.id"
                type="button"
                class="stay__chip"
                :class="{ 'stay__chip--on': statusFilter === item.id }"
                @click="statusFilter = item.id"
              >
                {{ item.label }}<em>{{ item.count }}</em>
              </button>
            </div>
            <input
              v-model="listSearch"
              class="field stay__search"
              :placeholder="t('hotel.stays.board.searchPh')"
            >
          </div>

          <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />
          <div v-else class="stay__table-wrap">
            <table class="ui-table stay__table">
              <thead>
                <tr>
                  <th>{{ t('hotel.stays.board.colClient') }}</th>
                  <th>{{ t('hotel.rooms.room') }}</th>
                  <th>{{ t('hotel.reservations.arriveOn') }}</th>
                  <th>{{ t('hotel.stays.board.colDepart') }}</th>
                  <th>{{ t('hotel.reservations.nights') }}</th>
                  <th>{{ t('hotel.reservations.channelField') }}</th>
                  <th>{{ t('hotel.stays.board.colStatus') }}</th>
                  <th>{{ t('hotel.stays.board.colBalance') }}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in filteredStays" :key="row.id">
                  <td>
                    <div class="stay__client">
                      <span class="stay__avatar">{{ initials(row.guest_name) }}</span>
                      <div>
                        <strong>{{ row.guest_name || '—' }}</strong>
                        <small v-if="row.guest_email">{{ row.guest_email }}</small>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="stay__room-cell">
                      <strong>#{{ stayRoomNumber(row) }}</strong>
                      <small>{{ stayTypeName(row) }}</small>
                    </div>
                  </td>
                  <td>{{ formatStayDate(row.arrive_on) }}</td>
                  <td>{{ formatStayDate(row.depart_on) }}</td>
                  <td>{{ stayNights(row) }}</td>
                  <td>{{ stayChannelLabel(row) }}</td>
                  <td>
                    <span class="stay__badge" :class="`stay__badge--${stayBoardStatus(row)}`">
                      {{ boardStatusLabel(row) }}
                    </span>
                  </td>
                  <td>
                    <div class="stay__balance">
                      <strong>{{ formatMoney(stayBalanceCents(row), stayCurrency(row)) }}</strong>
                      <small v-if="stayPaidComplete(row)" class="stay__ok">{{ t('hotel.stays.fullyPaidShort') }}</small>
                      <small v-else-if="row.payment_mode === 'credit'" class="stay__warn">{{ t('hotel.stays.onCreditShort') }}</small>
                    </div>
                  </td>
                  <td class="stay__row-actions">
                    <button
                      v-if="canOpenSign(row)"
                      type="button"
                      class="btn-primary stay-card__sign"
                      @click.stop="openSign(row)"
                    >
                      {{ t('hotel.stays.sign.button') }}
                    </button>
                    <span v-if="isStaySigned(row)" class="stay__ok">{{ t('hotel.stays.sign.signed') }}</span>
                    <button type="button" class="stay__view" @click="openDetail(row)">
                      {{ t('hotel.stays.board.view') }} →
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-if="!filteredStays.length" class="stay__empty">{{ t('hotel.stays.empty') }}</p>
          </div>
        </template>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="t('hotel.stays.walkInTitle')"
      icon="key"
      size="xl"
      @close="closeForm"
    >
      <form class="stay__form stay__form--modal" @submit.prevent="step === 3 ? save() : goStep((step + 1) as Step)">
        <p class="stay__intro-text">{{ t('hotel.stays.walkInHint') }}</p>

        <ol class="stay__steps" aria-label="Étapes">
          <li v-for="item in steps" :key="item.id">
            <button
              type="button"
              class="stay__step"
              :class="{
                'stay__step--on': step === item.id,
                'stay__step--done': step > item.id,
              }"
              @click="goStep(item.id)"
            >
              <span>{{ item.id }}</span>
              {{ item.label }}
            </button>
          </li>
        </ol>

        <p v-if="error" class="stay__error">{{ error }}</p>

        <template v-if="step === 1">
          <section class="stay__block">
            <h3><AppIcon name="customers" :size="15" /> {{ t('hotel.stays.clientTitle') }}</h3>
            <p class="stay__label">{{ t('hotel.reservations.clientRef') }}</p>
            <div class="stay__modes">
              <label class="stay__mode" :class="{ 'stay__mode--on': form.client_mode === 'new' }">
                <input v-model="form.client_mode" type="radio" value="new">
                <AppIcon name="account" :size="13" />
                <span>{{ t('hotel.reservations.newClient') }}</span>
              </label>
              <label class="stay__mode" :class="{ 'stay__mode--on': form.client_mode === 'existing' }">
                <input v-model="form.client_mode" type="radio" value="existing">
                <AppIcon name="customers" :size="13" />
                <span>{{ t('hotel.reservations.existingClient') }}</span>
              </label>
            </div>
            <p class="stay__hint">
              {{ t('hotel.reservations.clientHint') }}
              <RouterLink to="/admin/customers" class="stay__link">{{ t('hotel.reservations.clientsLink') }}</RouterLink>
            </p>

            <div v-if="form.client_mode === 'existing'" class="stay__pick">
              <FieldLabel icon="customers">{{ t('hotel.reservations.searchClient') }}</FieldLabel>
              <input
                v-model="customerSearch"
                class="field"
                :placeholder="t('hotel.reservations.searchClientPh')"
              >
              <div v-if="selectedCustomer" class="stay__picked">
                <strong>{{ selectedCustomer.name }}</strong>
                <small>{{ selectedCustomer.email || selectedCustomer.phone || '—' }}</small>
              </div>
              <div v-else class="stay__customer-list">
                <button
                  v-for="c in filteredCustomers"
                  :key="c.id"
                  type="button"
                  class="stay__customer"
                  @click="pickCustomer(c)"
                >
                  <strong>{{ c.name }}</strong>
                  <small>{{ c.email || c.phone || '—' }}</small>
                </button>
                <p v-if="!filteredCustomers.length" class="stay__muted">{{ t('hotel.reservations.noCustomers') }}</p>
              </div>
            </div>

            <div class="stay__grid">
              <div class="stay__span">
                <FieldLabel icon="account">{{ t('hotel.reservations.guestName') }} *</FieldLabel>
                <input
                  v-model="form.guest_name"
                  class="field"
                  required
                  :placeholder="t('hotel.reservations.guestNamePh')"
                >
              </div>
              <div>
                <FieldLabel icon="mail">{{ t('hotel.reservations.email') }}</FieldLabel>
                <input
                  v-model="form.guest_email"
                  class="field"
                  type="email"
                  :placeholder="t('hotel.reservations.emailPh')"
                >
              </div>
              <div>
                <FieldLabel icon="phone">{{ t('hotel.reservations.phone') }}</FieldLabel>
                <input
                  v-model="form.guest_phone"
                  class="field"
                  :placeholder="t('hotel.reservations.phonePh')"
                >
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="id-card" :size="15" /> {{ t('hotel.stays.identityTitle') }}</h3>
            <div class="stay__grid">
              <div>
                <FieldLabel icon="pin">{{ t('hotel.stays.birthPlace') }}</FieldLabel>
                <input v-model="form.birth_place" class="field" :placeholder="t('hotel.stays.birthPlacePh')">
              </div>
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.stays.birthDate') }}</FieldLabel>
                <input v-model="form.date_of_birth" class="field" type="date" :placeholder="t('hotel.stays.birthDatePh')">
              </div>
              <div>
                <FieldLabel icon="organization">{{ t('hotel.stays.nationality') }} *</FieldLabel>
                <input v-model="form.nationality" class="field" required :placeholder="t('hotel.stays.nationalityPh')">
              </div>
              <div>
                <FieldLabel icon="store-pin">{{ t('hotel.stays.residence') }}</FieldLabel>
                <input v-model="form.residence" class="field" :placeholder="t('hotel.stays.residencePh')">
              </div>
              <div>
                <FieldLabel icon="catalog">{{ t('hotel.stays.profession') }}</FieldLabel>
                <input v-model="form.profession" class="field" :placeholder="t('hotel.stays.professionPh')">
              </div>
              <div>
                <FieldLabel icon="organization">{{ t('hotel.stays.company') }}</FieldLabel>
                <input v-model="form.company_name" class="field" :placeholder="t('hotel.stays.companyPh')">
              </div>
              <div>
                <FieldLabel icon="phone">{{ t('hotel.stays.contactPerson') }}</FieldLabel>
                <input v-model="form.contact_person" class="field" :placeholder="t('hotel.stays.contactPersonPh')">
              </div>
              <div>
                <FieldLabel icon="transfer">{{ t('hotel.stays.originPlace') }}</FieldLabel>
                <input v-model="form.origin_place" class="field" :placeholder="t('hotel.stays.originPlacePh')">
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="id-card" :size="15" /> {{ t('hotel.stays.documentTitle') }}</h3>
            <div class="stay__grid">
              <div class="stay__span">
                <FieldLabel icon="id-card">{{ t('hotel.stays.documentType') }} *</FieldLabel>
                <select v-model="form.id_document_type" class="field" required>
                  <option disabled value="">{{ t('hotel.stays.documentTypePh') }}</option>
                  <option v-for="type in documentTypes" :key="type" :value="type">{{ documentLabel(type) }}</option>
                </select>
              </div>
            </div>

            <p class="stay__label">{{ t('hotel.stays.documentFile') }} *</p>
            <div class="stay__modes">
              <label class="stay__mode" :class="{ 'stay__mode--on': form.id_mode === 'upload' }">
                <input v-model="form.id_mode" type="radio" value="upload" @change="setIdMode('upload')">
                <AppIcon name="upload" :size="13" />
                <span>{{ t('hotel.stays.upload') }}</span>
              </label>
              <label class="stay__mode" :class="{ 'stay__mode--on': form.id_mode === 'blank' }">
                <input v-model="form.id_mode" type="radio" value="blank" @change="setIdMode('blank')">
                <AppIcon name="note" :size="13" />
                <span>{{ t('hotel.stays.fillBlank') }}</span>
              </label>
            </div>

            <label v-if="form.id_mode === 'upload'" class="stay__drop">
              <input type="file" accept="image/*,.pdf" class="sr-only" @change="onIdFile">
              <img v-if="idPreview" :src="idPreview" alt="" class="stay__drop-preview">
              <AppIcon v-else name="upload" :size="22" />
              <strong>{{ form.id_document_name || t('hotel.stays.uploadHint') }}</strong>
            </label>

            <div class="stay__grid">
              <div>
                <FieldLabel icon="tag">{{ t('hotel.stays.documentNumber') }} *</FieldLabel>
                <input
                  v-model="form.id_document_number"
                  class="field"
                  required
                  :placeholder="t('hotel.stays.documentNumberPh')"
                >
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('hotel.stays.issuePlace') }}</FieldLabel>
                <input v-model="form.id_document_issue_place" class="field" :placeholder="t('hotel.stays.issuePlacePh')">
              </div>
            </div>
          </section>
        </template>

        <template v-else-if="step === 2">
          <div class="stay__guest-banner">
            <AppIcon name="account" :size="16" />
            <strong>{{ form.guest_name || '—' }}</strong>
          </div>

          <section class="stay__block">
            <h3><AppIcon name="bed" :size="15" /> {{ t('hotel.stays.roomTypeTitle') }}</h3>
            <div class="stay__grid">
              <div class="stay__span">
                <FieldLabel icon="catalog">{{ t('hotel.reservations.roomType') }} *</FieldLabel>
                <select v-model="form.type_id" class="field" required>
                  <option disabled value="">{{ t('hotel.reservations.chooseType') }}</option>
                  <option v-for="item in typeOptions" :key="item.id" :value="item.id">{{ typePriceLabel(item) }}</option>
                </select>
              </div>
              <div class="stay__span">
                <FieldLabel icon="key">{{ t('hotel.stays.availableRoom') }} *</FieldLabel>
                <select
                  v-model="form.room_id"
                  class="field"
                  required
                  :disabled="!form.type_id || !vacantRooms.length"
                >
                  <option disabled value="">
                    {{ form.type_id ? t('hotel.stays.chooseRoom') : t('hotel.stays.pickTypeFirst') }}
                  </option>
                  <option v-for="room in vacantRooms" :key="room.id" :value="room.id">{{ roomLabel(room) }}</option>
                </select>
                <p v-if="form.type_id && !vacantRooms.length" class="stay__hint">{{ t('hotel.stays.noVacantRooms') }}</p>
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="calendar" :size="15" /> {{ t('hotel.reservations.stayTitle') }}</h3>
            <div class="stay__grid">
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.reservations.arriveOn') }} *</FieldLabel>
                <input v-model="form.arrive_on" class="field" type="date" required>
                <p class="stay__hint">{{ t('hotel.settings.checkIn') }} · {{ hotelSettings.check_in_time }}</p>
              </div>
              <div>
                <FieldLabel icon="calendar">{{ t('hotel.reservations.departOn') }} *</FieldLabel>
                <input v-model="form.depart_on" class="field" type="date" required>
                <p class="stay__hint">{{ t('hotel.settings.checkOut') }} · {{ hotelSettings.check_out_time }}</p>
              </div>
              <div>
                <FieldLabel icon="account">{{ t('hotel.reservations.adults') }} *</FieldLabel>
                <input v-model="form.adults" class="field" type="number" min="1" required>
              </div>
              <div>
                <FieldLabel icon="customers">{{ t('hotel.reservations.children') }}</FieldLabel>
                <input v-model="form.children" class="field" type="number" min="0">
              </div>
              <div class="stay__span">
                <FieldLabel icon="layers">{{ t('hotel.reservations.channelField') }}</FieldLabel>
                <select v-model="form.channel" class="field">
                  <option v-for="ch in channels" :key="ch" :value="ch">{{ channelLabel(ch) }}</option>
                </select>
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="note" :size="15" /> {{ t('hotel.stays.detailsTitle') }}</h3>
            <div class="stay__grid">
              <div class="stay__span">
                <FieldLabel icon="note">{{ t('hotel.stays.purpose') }} *</FieldLabel>
                <input v-model="form.purpose" class="field" required :placeholder="t('hotel.stays.purposePh')">
              </div>
              <div class="stay__span">
                <FieldLabel icon="customers">{{ t('hotel.stays.companions') }}</FieldLabel>
                <input v-model="form.companions" class="field" :placeholder="t('hotel.stays.companionsPh')">
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="coins" :size="15" /> {{ t('hotel.stays.paymentTitle') }}</h3>
            <p class="stay__label">{{ t('hotel.stays.paymentOfStay') }}</p>
            <div class="stay__pay-modes">
              <label class="stay__pay-card" :class="{ 'stay__pay-card--on': form.payment_mode === 'collect_now' }">
                <input v-model="form.payment_mode" type="radio" value="collect_now">
                <strong>{{ t('hotel.stays.collectNow') }}</strong>
                <span>{{ t('hotel.stays.collectNowHint') }}</span>
              </label>
              <label class="stay__pay-card" :class="{ 'stay__pay-card--on': form.payment_mode === 'credit' }">
                <input v-model="form.payment_mode" type="radio" value="credit">
                <strong>{{ t('hotel.stays.credit') }}</strong>
                <span>{{ t('hotel.stays.creditHint') }}</span>
              </label>
            </div>

            <div class="stay__grid">
              <div v-if="form.payment_mode === 'collect_now'">
                <FieldLabel icon="coins">{{ t('hotel.stays.amountCollected') }} *</FieldLabel>
                <div class="stay__money">
                  <span>$</span>
                  <input v-model="form.amount_collected" class="field" inputmode="decimal" required>
                </div>
              </div>
              <div>
                <FieldLabel icon="receipt">{{ t('hotel.stays.amountDue') }}</FieldLabel>
                <div class="stay__due">
                  <strong>{{ formatMoney(amountDueCents, currency) }}</strong>
                  <small v-if="paymentComplete" class="stay__due--ok">{{ t('hotel.stays.fullyPaid') }}</small>
                  <small v-else-if="form.payment_mode === 'credit'" class="stay__due--credit">{{ t('hotel.stays.onCredit') }}</small>
                  <small v-else-if="amountCollectedCents > 0 && amountCollectedCents < amountDueCents" class="stay__due--partial">
                    {{ t('hotel.stays.partialCredit') }}
                  </small>
                </div>
              </div>
              <div v-if="form.payment_mode === 'collect_now'">
                <FieldLabel icon="card">{{ t('hotel.stays.paymentMethod') }}</FieldLabel>
                <select v-model="form.payment_method" class="field">
                  <option v-for="m in payMethods" :key="m" :value="m">{{ payMethodLabel(m) }}</option>
                </select>
              </div>
              <div v-if="form.payment_mode === 'collect_now' && form.payment_method === 'voucher'">
                <FieldLabel icon="tag">{{ t('hotel.stays.voucherRef') }}</FieldLabel>
                <input v-model="form.voucher_reference" class="field" :placeholder="t('hotel.stays.voucherRefPh')">
              </div>
              <div>
                <FieldLabel icon="coins">{{ t('hotel.reservations.deposit') }}</FieldLabel>
                <div class="stay__money">
                  <span>$</span>
                  <input v-model="form.deposit" class="field" inputmode="decimal" :placeholder="t('hotel.reservations.depositPh')">
                </div>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('hotel.stays.specialPrice') }}</FieldLabel>
                <div class="stay__money">
                  <span>$</span>
                  <input v-model="form.special_price" class="field" inputmode="decimal" :placeholder="t('hotel.stays.specialPricePh')">
                </div>
              </div>
              <div class="stay__span">
                <FieldLabel icon="note">{{ t('hotel.stays.specialPriceReason') }}</FieldLabel>
                <input v-model="form.special_price_reason" class="field" :placeholder="t('hotel.stays.specialPriceReasonPh')">
              </div>
            </div>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="sparkles" :size="15" /> {{ t('hotel.reservations.requestsTitle') }}</h3>
            <FieldLabel icon="sparkles">{{ t('hotel.reservations.specialRequests') }}</FieldLabel>
            <textarea
              v-model="form.special_requests"
              class="field"
              rows="3"
              :placeholder="t('hotel.reservations.specialRequestsPh')"
            />
          </section>

          <section class="stay__block">
            <h3><AppIcon name="check" :size="15" /> {{ t('hotel.stays.signaturesTitle') }}</h3>
            <div class="stay__sig-reception">
              <p class="stay__label">{{ t('hotel.stays.receptionist') }}</p>
              <p class="stay__sig-auto">
                {{ t('hotel.stays.receptionistLine', { name: receptionistName }) }}
              </p>
            </div>

            <p class="stay__label">{{ t('hotel.stays.guestSignature') }}</p>
            <div class="stay__modes">
              <label class="stay__mode" :class="{ 'stay__mode--on': form.guest_signature_mode === 'upload' }">
                <input v-model="form.guest_signature_mode" type="radio" value="upload" @change="setSigMode('upload')">
                <AppIcon name="upload" :size="13" />
                <span>{{ t('hotel.stays.upload') }}</span>
              </label>
              <label class="stay__mode" :class="{ 'stay__mode--on': form.guest_signature_mode === 'blank' }">
                <input v-model="form.guest_signature_mode" type="radio" value="blank" @change="setSigMode('blank')">
                <AppIcon name="note" :size="13" />
                <span>{{ t('hotel.stays.fillBlank') }}</span>
              </label>
              <label class="stay__mode" :class="{ 'stay__mode--on': form.guest_signature_mode === 'dotted' }">
                <input v-model="form.guest_signature_mode" type="radio" value="dotted" @change="setSigMode('dotted')">
                <AppIcon name="note" :size="13" />
                <span>{{ t('hotel.stays.fillDotted') }}</span>
              </label>
            </div>

            <label v-if="form.guest_signature_mode === 'upload'" class="stay__drop">
              <input type="file" accept="image/*" class="sr-only" @change="onSigFile">
              <img v-if="sigPreview" :src="sigPreview" alt="" class="stay__drop-preview">
              <AppIcon v-else name="upload" :size="22" />
              <strong>{{ form.guest_signature_name || t('hotel.stays.uploadHint') }}</strong>
            </label>
            <div v-else-if="form.guest_signature_mode === 'dotted'" class="stay__dotted" aria-hidden="true">
              ………………………………
            </div>
            <div v-else class="stay__blank-sig">
              <span>{{ t('hotel.stays.signatureBlankHint') }}</span>
            </div>
          </section>
        </template>

        <template v-else>
          <section class="stay__block">
            <h3><AppIcon name="check" :size="15" /> {{ t('hotel.stays.steps.confirm') }}</h3>

            <dl class="stay__recap">
              <div>
                <dt>{{ t('hotel.reservations.guestName') }}</dt>
                <dd>{{ form.guest_name || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.nationality') }}</dt>
                <dd>{{ form.nationality || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.residence') }}</dt>
                <dd>{{ form.residence || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.reservations.phone') }}</dt>
                <dd>{{ form.guest_phone || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.originPlace') }}</dt>
                <dd>{{ form.origin_place || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.purpose') }}</dt>
                <dd>{{ form.purpose || '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.rooms.room') }}</dt>
                <dd>{{ roomConfirmLabel }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.reservations.arriveOn') }}</dt>
                <dd>{{ form.arrive_on }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.reservations.departOn') }}</dt>
                <dd>{{ form.depart_on }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.people') }}</dt>
                <dd>{{ peopleConfirmLabel }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.paymentMethod') }}</dt>
                <dd>{{ form.payment_mode === 'collect_now' ? payMethodLabel(form.payment_method) : '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.paymentOfStay') }}</dt>
                <dd>{{ paymentStayLabel }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.reservations.deposit') }}</dt>
                <dd>{{ depositCents ? formatMoney(depositCents, currency) : '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.specialPrice') }}</dt>
                <dd>{{ specialPriceCents ? formatMoney(specialPriceCents, currency) : '—' }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.documentTitle') }}</dt>
                <dd>{{ documentConfirmLabel }}</dd>
              </div>
              <div class="stay__recap-span">
                <dt>{{ t('hotel.stays.signaturesTitle') }}</dt>
                <dd>{{ guestSignatureConfirmLabel }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.reservations.channelField') }}</dt>
                <dd>{{ channelLabel(form.channel) }}</dd>
              </div>
            </dl>
          </section>

          <section class="stay__block">
            <h3><AppIcon name="receipt" :size="15" /> {{ t('hotel.stays.totalsTitle') }}</h3>
            <dl class="stay__totals">
              <div>
                <dt>{{ t('hotel.stays.roomRateLine', { nights }) }}</dt>
                <dd>{{ formatMoney(roomSubtotalCents, currency) }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.vatLine') }}{{ hotelSettings.vat_enabled === false ? '' : ` (${hotelSettings.vat_rate}%)` }}</dt>
                <dd>{{ formatMoney(vatCents, currency) }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.tcLine') }}{{ hotelSettings.tc_enabled === false ? '' : ` (${hotelSettings.tc_rate}%)` }}</dt>
                <dd>{{ formatMoney(tcCents, currency) }}</dd>
              </div>
              <div class="stay__totals-total">
                <dt>{{ t('hotel.stays.estimatedTotal') }}</dt>
                <dd>{{ formatMoney(amountDueCents, currency) }}</dd>
              </div>
            </dl>
            <p class="stay__confirm-hint">{{ t('hotel.stays.confirmHint') }}</p>
          </section>
        </template>

        <div class="stay__actions">
          <button v-if="step > 1" type="button" class="btn-secondary" @click="goStep((step - 1) as Step)">
            {{ t('hotel.stays.back') }}
          </button>
          <button type="button" class="btn-secondary" @click="closeForm">{{ t('common.cancel') }}</button>
          <button v-if="step < 3" type="submit" class="btn-primary">{{ t('hotel.stays.next') }}</button>
          <button v-else type="submit" class="btn-primary" :disabled="saving || !vacantRooms.length">
            {{ t('hotel.stays.confirmArrival') }}
          </button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="signOpen"
      :title="signModalTitle"
      icon="key"
      size="md"
      @close="closeSign"
    >
      <div v-if="signingStay" class="stay-sign">
        <div class="stay-sign__head">
          <h4>{{ signingStay.guest_name }}</h4>
          <p>{{ stayRoomLabel(signingStay) }}</p>
        </div>

        <div v-if="!signRemoteDone" class="stay-sign__tabs">
          <button
            type="button"
            class="stay-sign__tab"
            :class="{ 'stay-sign__tab--on': signTab === 'scan' }"
            @click="signTab = 'scan'"
          >
            {{ t('hotel.stays.sign.scanTab') }}
          </button>
          <button
            type="button"
            class="stay-sign__tab"
            :class="{ 'stay-sign__tab--on': signTab === 'draw' }"
            @click="signTab = 'draw'"
          >
            {{ t('hotel.stays.sign.drawTab') }}
          </button>
        </div>

        <div v-if="signTab === 'scan'" class="stay-sign__scan">
          <template v-if="signRemoteDone">
            <div class="stay-sign__done" role="status">
              <AppIcon name="check" :size="28" />
              <h5>{{ t('hotel.stays.sign.doneTitle') }}</h5>
              <p>{{ t('hotel.stays.sign.received') }}</p>
              <span class="stay__ok">{{ t('hotel.stays.sign.signed') }}</span>
            </div>
            <button type="button" class="btn-primary stay-sign__skip" @click="closeSign">
              {{ t('command.close') }}
            </button>
          </template>
          <template v-else>
            <h5>{{ t('hotel.stays.sign.scanTitle') }}</h5>
            <p class="stay-sign__hint">{{ t('hotel.stays.sign.scanHint') }}</p>
            <LoadingBlock v-if="signLoading" variant="detail" :rows="3" :label="t('common.loading')" />
            <template v-else>
              <img v-if="qrImageUrl" :src="qrImageUrl" :alt="t('hotel.stays.sign.scanTitle')" class="stay-sign__qr">
              <div v-if="signUrl" class="stay-sign__link-box">
                <a :href="signUrl" target="_blank" rel="noopener" class="stay-sign__url">{{ signUrl }}</a>
                <button type="button" class="btn-secondary" @click="copySignLink">
                  {{ signLinkCopied ? t('hotel.stays.sign.copied') : t('hotel.stays.sign.copyLink') }}
                </button>
              </div>
              <p v-if="signUrl" class="stay-sign__waiting">{{ t('hotel.stays.sign.waiting') }}</p>
            </template>
            <p v-if="error" class="stay__error">{{ error }}</p>
            <button type="button" class="btn-secondary stay-sign__skip" @click="closeSign">
              {{ t('hotel.stays.sign.skip') }}
            </button>
          </template>
        </div>

        <div v-else class="stay-sign__draw">
          <p class="stay-sign__hint">{{ t('hotel.stays.sign.drawHint') }}</p>
          <canvas
            ref="signCanvas"
            class="stay-sign__canvas"
            @pointerdown="startSignDraw"
            @pointermove="moveSignDraw"
            @pointerup="endSignDraw"
            @pointercancel="endSignDraw"
          />
          <div class="stay__actions">
            <button type="button" class="btn-secondary" @click="setupSignCanvas">{{ t('hotel.stays.sign.clear') }}</button>
            <button type="button" class="btn-primary" :disabled="signSaving || !signDrawn" @click="saveDrawnSignature">
              {{ t('hotel.stays.sign.confirm') }}
            </button>
          </div>
          <p v-if="error" class="stay__error">{{ error }}</p>
        </div>
      </div>
    </AppModal>

    <AppModal
      :open="detailOpen"
      :title="t('hotel.stays.board.detailTitle')"
      size="xl"
      @close="closeDetail"
    >
      <div v-if="detailStay" class="sd">
        <header class="sd__hero">
          <div class="sd__hero-main">
            <span class="stay__avatar stay__avatar--lg">{{ initials(detailStay.guest_name) }}</span>
            <div>
              <h3>{{ detailStay.guest_name || '—' }}</h3>
              <div class="sd__pills">
                <span class="stay__badge" :class="`stay__badge--${stayBoardStatus(detailStay)}`">{{ boardStatusLabel(detailStay) }}</span>
                <span class="sd__pill">{{ stayChannelLabel(detailStay) }}</span>
                <span class="sd__pill" :class="detailFolioBalanceCents(detailStay) <= 0 ? 'sd__pill--ok' : 'sd__pill--warn'">
                  {{ detailFolioBalanceCents(detailStay) <= 0 ? t('hotel.stays.fullyPaidShort') : t('hotel.stays.onCreditShort') }}
                </span>
              </div>
            </div>
          </div>
          <button
            v-if="detailStay.status === 'checked_in'"
            type="button"
            class="btn-primary"
            @click="checkoutFromDetail"
          >
            {{ t('desk.checkOut') }}
          </button>
        </header>

        <div class="sd__stats">
          <article>
            <span>{{ t('hotel.stays.detail.stayNo') }}</span>
            <strong>{{ detailStay.stay_code || '—' }}</strong>
          </article>
          <article>
            <span>{{ t('hotel.rooms.room') }}</span>
            <strong>#{{ stayRoomNumber(detailStay) }} · {{ stayTypeName(detailStay) }}</strong>
          </article>
          <article>
            <span>{{ t('hotel.reservations.nights') }}</span>
            <strong>{{ t('hotel.stays.detail.nightsValue', { count: stayNights(detailStay) }) }}</strong>
          </article>
          <article>
            <span>{{ t('hotel.stays.detail.folioBalance') }}</span>
            <strong>{{ formatMoney(detailFolioBalanceCents(detailStay), stayCurrency(detailStay)) }}</strong>
          </article>
          <article>
            <span>{{ t('hotel.stays.detail.deposit') }}</span>
            <strong>
              {{ formatMoney(detailDepositCents(detailStay), stayCurrency(detailStay)) }}
              <small v-if="detailDepositCents(detailStay) > 0"> · {{ t('hotel.stays.detail.depositHeld') }}</small>
            </strong>
          </article>
        </div>

        <section class="sd__journey">
          <h4>{{ t('hotel.stays.detail.journeyTitle') }}</h4>
          <ol>
            <li
              v-for="stepItem in journeySteps(detailStay)"
              :key="stepItem.id"
              :class="{
                'sd__journey-step--done': stepItem.done,
                'sd__journey-step--current': stepItem.current,
              }"
            >
              <i />
              <span>{{ stepItem.label }}</span>
            </li>
          </ol>
        </section>

        <div class="sd__grid">
          <section class="sd__card">
            <h4>{{ t('hotel.stays.detail.client') }}</h4>
            <dl class="sd__kv">
              <div><dt>{{ t('hotel.stays.detail.name') }}</dt><dd>{{ detailStay.guest_name || '—' }}</dd></div>
              <div><dt>{{ t('hotel.reservations.email') }}</dt><dd>{{ detailStay.guest_email || '—' }}</dd></div>
              <div><dt>{{ t('hotel.reservations.phone') }}</dt><dd>{{ detailStay.guest_phone || '—' }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.guests') }}</dt><dd>{{ Number(detailStay.adults || 1) + Number(detailStay.children || 0) }}</dd></div>
            </dl>
            <div class="sd__sign-box">
              <strong>{{ t('hotel.stays.guestSignature') }}</strong>
              <p v-if="isStaySigned(detailStay)" class="stay__ok">{{ t('hotel.stays.sign.signed') }}</p>
              <button v-else-if="canOpenSign(detailStay)" type="button" class="btn-secondary" @click="openSignFromDetail">
                {{ t('hotel.stays.sign.button') }}
              </button>
              <span v-else>—</span>
            </div>
            <div class="sd__guest-list">
              <p>{{ t('hotel.stays.detail.allGuests') }}</p>
              <article>
                <strong>{{ detailStay.guest_name }}</strong>
                <span class="sd__pill">{{ t('hotel.stays.detail.principal') }}</span>
                <small>{{ documentTypeShort(detailStay) }}</small>
              </article>
            </div>
          </section>

          <section class="sd__card">
            <div class="sd__card-head">
              <h4>{{ t('hotel.stays.detail.stayDetails') }}</h4>
              <RouterLink
                v-if="!detailStay.walk_in"
                to="/admin/hotel/reservations"
                class="stay__link"
              >
                {{ t('hotel.stays.detail.viewReservation') }}
              </RouterLink>
            </div>
            <dl class="sd__kv">
              <div><dt>{{ t('hotel.stays.detail.checkIn') }}</dt><dd>{{ formatDateTime(detailStay.checked_in_at || detailStay.arrive_on) }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.expectedOut') }}</dt><dd>{{ formatDateTime(detailStay.depart_on) }}</dd></div>
              <div><dt>{{ t('hotel.reservations.nights') }}</dt><dd>{{ stayNights(detailStay) }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.priceNight') }}</dt><dd>{{ formatMoney(detailPricePerNight(detailStay), stayCurrency(detailStay)) }}</dd></div>
              <div><dt>{{ t('hotel.stays.detail.source') }}</dt><dd>{{ stayChannelLabel(detailStay) }}</dd></div>
            </dl>
          </section>

          <aside class="sd__aside">
            <section class="sd__card">
              <h4>{{ t('hotel.stays.guestSignature') }}</h4>
              <div class="sd__sign-panel">
                <img
                  v-if="String(detailStay.guest_signature_data || '').startsWith('data:image')"
                  :src="detailStay.guest_signature_data"
                  alt=""
                  class="sd__sign-img"
                >
                <template v-else-if="isStaySigned(detailStay)">
                  <p class="stay__ok">{{ t('hotel.stays.sign.signed') }}</p>
                  <small v-if="detailStay.guest_signed_at">{{ formatDateTime(detailStay.guest_signed_at) }}</small>
                </template>
                <template v-else>
                  <p class="stay__muted">{{ t('hotel.stays.detail.signatureMissing') }}</p>
                  <button
                    v-if="canOpenSign(detailStay)"
                    type="button"
                    class="btn-secondary"
                    @click="openSignFromDetail"
                  >
                    {{ t('hotel.stays.sign.button') }}
                  </button>
                </template>
              </div>
            </section>

            <section class="sd__card">
              <h4>{{ t('hotel.stays.detail.quickActions') }}</h4>
              <div class="sd__quick">
                <button
                  type="button"
                  class="sd__quick-btn"
                  :disabled="!canManageStay(detailStay)"
                  @click="openChangeRoom"
                >
                  <AppIcon name="bed" :size="14" />
                  {{ t('hotel.stays.detail.changeRoom') }}
                </button>
                <button
                  type="button"
                  class="sd__quick-btn"
                  :disabled="!canManageStay(detailStay)"
                  @click="openCollect"
                >
                  <AppIcon name="coins" :size="14" />
                  {{ t('hotel.stays.detail.collect') }}
                </button>
                <button type="button" class="sd__quick-btn" @click="exportStayLodging(detailStay)">
                  <AppIcon name="receipt" :size="14" />
                  {{ t('hotel.stays.detail.exportLodging') }}
                </button>
                <button type="button" class="sd__quick-btn" @click="exportStayConsumption(detailStay)">
                  <AppIcon name="layers" :size="14" />
                  {{ t('hotel.stays.detail.exportConsumption') }}
                </button>
                <button type="button" class="sd__quick-btn" @click="exportStayRegistration(detailStay)">
                  <AppIcon name="account" :size="14" />
                  {{ t('hotel.stays.detail.exportRegistration') }}
                </button>
              </div>
            </section>
          </aside>
        </div>

        <section class="sd__card sd__chrono">
          <h4>{{ t('hotel.stays.detail.timeline') }}</h4>
          <ol v-if="detailTimeline(detailStay).length" class="sd__timeline sd__timeline--rich">
            <li v-for="(event, idx) in detailTimeline(detailStay)" :key="event.key || `${event.title}-${idx}`">
              <i class="sd__timeline-dot" />
              <div>
                <strong>{{ event.title }}</strong>
                <span>{{ event.at }}</span>
              </div>
            </li>
          </ol>
          <p v-else class="stay__muted">{{ t('hotel.stays.detail.timelineEmpty') }}</p>
        </section>

        <div class="sd__tabs">
          <button
            v-for="tab in detailTabs"
            :key="tab.id"
            type="button"
            class="sd__tab"
            :class="{ 'sd__tab--on': detailTab === tab.id }"
            @click="detailTab = tab.id"
          >
            {{ tab.label }}
          </button>
        </div>

        <template v-if="detailTab === 'overview' || detailTab === 'folio'">
          <div class="sd__folio-stats">
            <article>
              <span>{{ t('hotel.stays.detail.totalCharges') }}</span>
              <strong>{{ formatMoney(detailChargesCents(detailStay), stayCurrency(detailStay)) }}</strong>
            </article>
            <article>
              <span>{{ t('hotel.stays.detail.paid') }}</span>
              <strong>{{ formatMoney(detailPaidCents(detailStay), stayCurrency(detailStay)) }}</strong>
            </article>
            <article>
              <span>{{ t('hotel.stays.detail.balance') }}</span>
              <strong>{{ formatMoney(detailFolioBalanceCents(detailStay), stayCurrency(detailStay)) }}</strong>
            </article>
            <article>
              <span>{{ t('hotel.stays.detail.payment') }}</span>
              <strong :class="detailFolioBalanceCents(detailStay) <= 0 ? 'stay__ok' : 'stay__warn'">
                {{ detailFolioBalanceCents(detailStay) <= 0 ? t('hotel.stays.fullyPaidShort') : t('hotel.stays.onCreditShort') }}
              </strong>
            </article>
          </div>

          <section class="sd__card">
            <h4>{{ t('hotel.stays.detail.depositTitle') }}</h4>
            <dl class="sd__kv sd__kv--3">
              <div>
                <dt>{{ t('hotel.stays.detail.depositRequired') }}</dt>
                <dd>{{ formatMoney(detailDepositCents(detailStay), stayCurrency(detailStay)) }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.detail.depositHeld') }}</dt>
                <dd>{{ formatMoney(detailDepositCents(detailStay), stayCurrency(detailStay)) }}</dd>
              </div>
              <div>
                <dt>{{ t('hotel.stays.detail.depositRemain') }}</dt>
                <dd>{{ formatMoney(0, stayCurrency(detailStay)) }}</dd>
              </div>
            </dl>
          </section>

          <section class="sd__card">
            <div class="sd__card-head">
              <h4>{{ t('hotel.stays.detail.transactions') }}</h4>
              <span>{{ detailFolioLines(detailStay).length }}</span>
            </div>
            <div class="sd__table-wrap">
              <table class="ui-table sd__table">
                <thead>
                  <tr>
                    <th>{{ t('hotel.stays.detail.colType') }}</th>
                    <th>{{ t('hotel.stays.detail.colLabel') }}</th>
                    <th>{{ t('hotel.stays.detail.colAmount') }}</th>
                    <th>{{ t('hotel.stays.detail.colDate') }}</th>
                    <th>{{ t('hotel.stays.detail.colBy') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="line in detailFolioLines(detailStay)" :key="line.id || line.description">
                    <td>
                      <div class="sd__tx-type">
                        <strong>{{ lineGroupLabel(line) }}</strong>
                        <small>{{ lineStatusLabel(line) }}</small>
                      </div>
                    </td>
                    <td>{{ line.description || '—' }}</td>
                    <td>{{ formatMoney(Math.abs(Number(line.amount || 0)), stayCurrency(detailStay)) }}</td>
                    <td>{{ formatDateTime(line.created_at || detailStay.arrive_on) }}</td>
                    <td>{{ line.by || detailStay.receptionist_name || '—' }}</td>
                  </tr>
                </tbody>
              </table>
              <p v-if="!detailFolioLines(detailStay).length" class="stay__muted">{{ t('hotel.stays.detail.noTransactions') }}</p>
            </div>
          </section>
        </template>

        <template v-else-if="detailTab === 'room_service'">
          <div class="stay__placeholder">
            <AppIcon name="receipt" :size="22" />
            <p>{{ t('hotel.stays.detail.roomServiceSoon') }}</p>
          </div>
        </template>

        <template v-else>
          <section class="sd__card sd__chrono">
            <h4>{{ t('hotel.stays.detail.timeline') }}</h4>
            <ol v-if="detailTimeline(detailStay).length" class="sd__timeline sd__timeline--rich">
              <li v-for="(event, idx) in detailTimeline(detailStay)" :key="event.key || `${event.title}-${idx}`">
                <i class="sd__timeline-dot" />
                <div>
                  <strong>{{ event.title }}</strong>
                  <span>{{ event.at }}</span>
                </div>
              </li>
            </ol>
            <p v-else class="stay__muted">{{ t('hotel.stays.detail.timelineEmpty') }}</p>
          </section>
        </template>

        <div class="sd__grid">
          <section class="sd__card sd__room">
            <h4>{{ t('hotel.rooms.room') }}</h4>
            <div class="sd__room-body">
              <div>
                <strong>#{{ stayRoomNumber(detailStay) }}</strong>
                <p>{{ stayTypeName(detailStay) }}</p>
                <small v-if="detailRoom(detailStay)?.floor_number != null">
                  {{ t('hotel.stays.detail.floor') }} {{ detailRoom(detailStay)?.floor_number }}
                </small>
              </div>
              <div class="sd__room-meta">
                <span>{{ t('hotel.stays.detail.priceNight') }}</span>
                <strong>{{ formatMoney(detailPricePerNight(detailStay), stayCurrency(detailStay)) }}</strong>
                <em>{{ detailStay.status === 'checked_in' ? t('hotel.stays.board.planOccupied') : t('hotel.stays.board.planAvailable') }}</em>
              </div>
            </div>
            <div v-if="stayInventory(detailStay).length" class="sd__amenities">
              <span v-for="item in stayInventory(detailStay)" :key="item.id" class="sd__amenity">
                <AppIcon :name="item.icon_key || 'sparkles'" :size="11" />
                {{ item.name }}
              </span>
            </div>
            <div class="sd__actions">
              <button
                type="button"
                class="btn-secondary"
                :disabled="!canManageStay(detailStay)"
                @click="openChangeRoom"
              >
                {{ t('hotel.stays.detail.changeRoom') }}
              </button>
              <button
                type="button"
                class="btn-secondary"
                :disabled="!canManageStay(detailStay)"
                @click="openCollect"
              >
                {{ t('hotel.stays.detail.collect') }}
              </button>
              <button v-if="canOpenSign(detailStay)" type="button" class="btn-secondary" @click="openSignFromDetail">
                {{ t('hotel.stays.sign.button') }}
              </button>
            </div>
          </section>
        </div>
      </div>
    </AppModal>

    <AppModal
      :open="changeRoomOpen"
      :title="t('hotel.stays.detail.changeRoom')"
      icon="bed"
      size="md"
      @close="changeRoomOpen = false"
    >
      <p class="stay__intro-text">{{ t('hotel.stays.detail.changeRoomHint') }}</p>
      <p v-if="error" class="stay__error">{{ error }}</p>
      <FieldLabel icon="bed">{{ t('hotel.stays.availableRoom') }}</FieldLabel>
      <select v-model="changeRoomId" class="field">
        <option disabled value="">{{ t('hotel.stays.chooseRoom') }}</option>
        <option v-for="room in detailVacantRooms" :key="room.id" :value="room.id">{{ roomLabel(room) }}</option>
      </select>
      <p v-if="!detailVacantRooms.length" class="stay__hint">{{ t('hotel.stays.noVacantRooms') }}</p>
      <div class="stay__actions">
        <button type="button" class="btn-secondary" @click="changeRoomOpen = false">{{ t('common.cancel') }}</button>
        <button type="button" class="btn-primary" :disabled="changeRoomSaving || !changeRoomId" @click="saveChangeRoom">
          {{ t('common.save') }}
        </button>
      </div>
    </AppModal>

    <AppModal
      :open="collectOpen"
      :title="t('hotel.stays.detail.collect')"
      icon="coins"
      size="md"
      @close="collectOpen = false"
    >
      <p class="stay__intro-text">{{ t('hotel.stays.detail.collectHint') }}</p>
      <p v-if="error" class="stay__error">{{ error }}</p>
      <div class="stay__grid">
        <div>
          <FieldLabel icon="coins">{{ t('hotel.stays.amountCollected') }}</FieldLabel>
          <input v-model="collectAmount" class="field" inputmode="decimal">
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('hotel.stays.paymentOfStay') }}</FieldLabel>
          <select v-model="collectMethod" class="field">
            <option v-for="m in payMethods" :key="m" :value="m">{{ payMethodLabel(m) }}</option>
          </select>
        </div>
      </div>
      <div class="stay__actions">
        <button type="button" class="btn-secondary" @click="collectOpen = false">{{ t('common.cancel') }}</button>
        <button type="button" class="btn-primary" :disabled="collectSaving" @click="saveCollect">
          {{ t('hotel.stays.detail.collect') }}
        </button>
      </div>
    </AppModal>

    <AppModal
      :open="checkoutOpen"
      :title="t('hotel.stays.checkoutTitle')"
      icon="key"
      size="lg"
      @close="closeCheckout"
    >
      <p class="stay__intro-text">
        {{ t('hotel.stays.checkoutConfirm', { name: checkoutStay?.guest_name || '' }) }}
      </p>
      <p class="stay__hint">{{ t('hotel.stays.checkoutHint') }}</p>
      <p v-if="error" class="stay__error">{{ error }}</p>

      <h4 class="co__title">{{ t('hotel.stays.checkoutInventory') }}</h4>
      <p v-if="!checkoutItems.length" class="stay__muted">{{ t('hotel.stays.checkoutEmpty') }}</p>
      <ul v-else class="co__list">
        <li v-for="(item, index) in checkoutItems" :key="item.amenity_id" class="co__item">
          <div class="co__head">
            <strong>
              <AppIcon :name="item.icon_key || 'sparkles'" :size="14" />
              {{ item.name }}
            </strong>
            <small>{{ formatMoney(item.replacement_value_cents, stayCurrency(checkoutStay || {})) }}</small>
          </div>
          <div class="co__status">
            <button
              type="button"
              class="co__pill"
              :class="{ 'co__pill--ok': item.status === 'ok' }"
              @click="setCheckoutStatus(index, 'ok')"
            >
              {{ t('hotel.stays.checkoutOk') }}
            </button>
            <button
              type="button"
              class="co__pill"
              :class="{ 'co__pill--missing': item.status === 'missing' }"
              @click="setCheckoutStatus(index, 'missing')"
            >
              {{ t('hotel.stays.checkoutMissing') }}
            </button>
            <button
              type="button"
              class="co__pill"
              :class="{ 'co__pill--damaged': item.status === 'damaged' }"
              @click="setCheckoutStatus(index, 'damaged')"
            >
              {{ t('hotel.stays.checkoutDamaged') }}
            </button>
          </div>
          <label v-if="item.status !== 'ok'" class="co__amount">
            <span>{{ t('hotel.stays.checkoutCharge') }}</span>
            <input v-model="item.amount" class="field" inputmode="decimal">
          </label>
        </li>
      </ul>

      <div class="co__total">
        <span>{{ t('hotel.stays.checkoutTotal') }}</span>
        <strong>{{ checkoutChargeCents > 0 ? formatMoney(checkoutChargeCents, stayCurrency(checkoutStay || {})) : t('hotel.stays.checkoutNoCharge') }}</strong>
      </div>

      <div class="stay__actions">
        <button type="button" class="btn-secondary" @click="closeCheckout">{{ t('common.cancel') }}</button>
        <button type="button" class="btn-primary" :disabled="checkoutSaving" @click="confirmCheckout">
          {{ t('hotel.stays.checkoutConfirmBtn') }}
        </button>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.stay {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  min-height: 0;
  width: 100%;
  height: 100%;
}
.stay__board {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
  overflow: auto;
  padding: 1.05rem 1.15rem 1.15rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  background: #fff;
}
.stay__board-top {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  flex-wrap: wrap;
  flex-shrink: 0;
}
.stay__board-top h2 {
  margin: 0;
  font-size: 1.2rem;
  color: #1c2830;
}
.stay__board-links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem 0.85rem;
  margin-top: 0.35rem;
}
.stay__board-link {
  border: 0;
  background: transparent;
  padding: 0;
  font-size: 0.82rem;
  color: #7b8d9a;
  cursor: pointer;
}
.stay__board-link--on,
.stay__board-link:hover {
  color: var(--color-brand-700, #3d5c73);
  font-weight: 650;
}
.stay__board-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  align-items: center;
}
.stay__view-toggle {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.2rem;
  border-radius: 0.7rem;
  background: #eef3f7;
  width: fit-content;
  flex-shrink: 0;
}
.stay__toggle {
  border: 0;
  background: transparent;
  border-radius: 0.55rem;
  padding: 0.4rem 0.75rem;
  font-size: 0.8rem;
  font-weight: 650;
  color: #64748b;
  cursor: pointer;
}
.stay__toggle--on {
  background: #fff;
  color: #1c2830;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.stay__stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.55rem;
  flex-shrink: 0;
}
@media (min-width: 720px) {
  .stay__stats { grid-template-columns: repeat(5, minmax(0, 1fr)); }
}
.stay__stat {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.75rem;
  background: #f8fafc;
}
.stay__stat span {
  font-size: 0.72rem;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.stay__stat strong {
  font-size: 1.15rem;
  color: #1c2830;
}
.stay__stat--money strong { font-size: 0.95rem; }
.stay__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  align-items: center;
  justify-content: space-between;
  flex-shrink: 0;
}
.stay__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}
.stay__chip {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  border: 1px solid #d7e2ea;
  border-radius: 999px;
  background: #fff;
  padding: 0.3rem 0.65rem;
  font-size: 0.78rem;
  color: #4b5d6b;
  cursor: pointer;
}
.stay__chip em {
  font-style: normal;
  font-weight: 700;
  color: #94a3b8;
}
.stay__chip--on {
  border-color: var(--color-brand-500, var(--color-brand-600));
  background: #eef4f8;
  color: #1c2830;
}
.stay__chip--on em { color: var(--color-brand-700, #3d5c73); }
.stay__search {
  min-width: min(100%, 16rem);
  max-width: 20rem;
}
.stay__table-wrap {
  flex: 1 1 0;
  min-height: 0;
  overflow: auto;
  overscroll-behavior: contain;
  border: 1px solid #e8eef3;
  border-radius: 0.75rem;
}
.stay__table {
  width: 100%;
  min-width: 56rem;
}
.stay__client,
.stay__room-cell,
.stay__balance {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}
.stay__client {
  flex-direction: row;
  align-items: center;
  gap: 0.55rem;
}
.stay__client strong,
.stay__room-cell strong,
.stay__balance strong {
  font-size: 0.88rem;
  color: #1c2830;
}
.stay__client small,
.stay__room-cell small,
.stay__balance small {
  font-size: 0.72rem;
  color: #7b8d9a;
}
.stay__avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  background: #e8eef3;
  color: #3d5c73;
  font-size: 0.72rem;
  font-weight: 750;
  flex-shrink: 0;
}
.stay__avatar--lg {
  width: 3rem;
  height: 3rem;
  font-size: 0.95rem;
}
.stay__badge {
  display: inline-flex;
  align-items: center;
  padding: 0.18rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  background: #eef2f6;
  color: #475569;
  width: fit-content;
}
.stay__badge--en_sejour { background: #ecfdf5; color: #047857; }
.stay__badge--enregistre { background: #eff6ff; color: #1d4ed8; }
.stay__badge--en_attente { background: #fff7ed; color: #c2410c; }
.stay__badge--parti { background: #f1f5f9; color: #475569; }
.stay__badge--annule { background: #fef2f2; color: #b91c1c; }
.stay__badge--no_show { background: #faf5ff; color: #7e22ce; }
.stay__ok { color: #047857; font-weight: 650; }
.stay__warn { color: #b45309; font-weight: 650; }
.stay__row-actions {
  text-align: right;
  white-space: nowrap;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.55rem;
  position: sticky;
  right: 0;
  background: #fff;
  padding-left: 0.5rem;
  z-index: 1;
}
.stay-card__sign {
  font-size: 0.8rem;
  padding: 0.35rem 0.75rem;
  flex-shrink: 0;
}
.stay__view {
  border: 0;
  background: transparent;
  color: var(--color-brand-600, var(--color-brand-600));
  font-weight: 650;
  font-size: 0.82rem;
  cursor: pointer;
  padding: 0;
}
.stay__view:hover { text-decoration: underline; }
.stay__placeholder {
  flex: 1;
  min-height: 12rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.55rem;
  color: #7b8d9a;
  border: 1px dashed #d7e2ea;
  border-radius: 0.8rem;
  background: #f8fafc;
}
.stay__placeholder p { margin: 0; font-size: 0.88rem; }
.stay-plan {
  flex: 1 1 auto;
  min-height: 16rem;
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  overflow: visible;
}
.stay-plan__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem 1rem;
  flex-shrink: 0;
}
.stay-plan__legend-item {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.78rem;
  color: #4b5d6b;
  font-weight: 600;
}
.stay-plan__dot {
  width: 0.65rem;
  height: 0.65rem;
  border-radius: 999px;
  display: inline-block;
}
.stay-plan__dot--available,
.stay-plan__card--available {
  --plan-bg: #d1fae5;
  --plan-border: #059669;
  --plan-accent: #047857;
  --plan-strip: #10b981;
}
.stay-plan__dot--occupied,
.stay-plan__card--occupied {
  --plan-bg: #fee2e2;
  --plan-border: #dc2626;
  --plan-accent: #b91c1c;
  --plan-strip: #ef4444;
}
.stay-plan__dot--reserved,
.stay-plan__card--reserved {
  --plan-bg: #ffedd5;
  --plan-border: #ea580c;
  --plan-accent: #c2410c;
  --plan-strip: #f97316;
}
.stay-plan__dot--dirty,
.stay-plan__card--dirty {
  --plan-bg: #fef3c7;
  --plan-border: #d97706;
  --plan-accent: #b45309;
  --plan-strip: #f59e0b;
}
.stay-plan__dot--maintenance,
.stay-plan__card--maintenance {
  --plan-bg: #e2e8f0;
  --plan-border: #64748b;
  --plan-accent: #475569;
  --plan-strip: #94a3b8;
}
.stay-plan__dot {
  background: var(--plan-accent, #94a3b8);
}
.stay-plan__floors {
  flex: 1 1 auto;
  min-height: 12rem;
  overflow: visible;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-right: 0.15rem;
}
.stay-plan__floor-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.55rem;
}
.stay-plan__floor-head h3 {
  margin: 0;
  font-size: 0.95rem;
  color: #1c2830;
}
.stay-plan__floor-head span {
  font-size: 0.78rem;
  color: #7b8d9a;
  font-weight: 600;
}
.stay-plan__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(8.5rem, 1fr));
  gap: 0.55rem;
}
.stay-plan__card {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.15rem;
  min-height: 5.75rem;
  padding: 0.55rem 0.7rem 0.65rem 0.85rem;
  border: 1.5px solid var(--plan-border, #d7e2ea);
  border-radius: 0.7rem;
  background: var(--plan-bg, #fff);
  box-shadow: inset 4px 0 0 var(--plan-strip, #94a3b8);
  text-align: left;
  cursor: pointer;
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}
.stay-plan__card:hover {
  transform: translateY(-1px);
  box-shadow:
    inset 4px 0 0 var(--plan-strip, #94a3b8),
    0 4px 12px rgba(15, 23, 42, 0.1);
}
.stay-plan__status {
  align-self: flex-start;
  margin-bottom: 0.1rem;
  padding: 0.1rem 0.4rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--plan-accent, #64748b) 14%, #fff);
  color: var(--plan-accent, #475569);
  font-size: 0.62rem;
  font-weight: 750;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  line-height: 1.35;
}
.stay-plan__num {
  font-size: 1.05rem;
  font-weight: 750;
  color: var(--plan-accent, #0f172a);
  line-height: 1.1;
}
.stay-plan__type {
  font-size: 0.7rem;
  color: #64748b;
  line-height: 1.25;
}
.stay-plan__guest {
  margin-top: 0.25rem;
  font-size: 0.78rem;
  font-weight: 650;
  color: var(--plan-accent, #1c2830);
  line-height: 1.25;
  word-break: break-word;
}
.stay-plan__out,
.stay-plan__meta {
  font-size: 0.68rem;
  color: #64748b;
  line-height: 1.25;
}
.stay-plan__meta {
  font-weight: 600;
  color: #475569;
}
.stay-detail { display: flex; flex-direction: column; gap: 1rem; }
.stay-detail__hero {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.stay-detail__hero h3 { margin: 0; font-size: 1.05rem; }
.stay-detail__hero p { margin: 0.15rem 0 0.35rem; font-size: 0.82rem; color: #7b8d9a; }
.sd { display: flex; flex-direction: column; gap: 1rem; }
.sd__hero {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  flex-wrap: wrap;
}
.sd__hero-main {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.sd__hero h3 { margin: 0 0 0.35rem; font-size: 1.2rem; }
.sd__pills { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.sd__pill {
  display: inline-flex;
  align-items: center;
  padding: 0.18rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  background: #eef2f6;
  color: #475569;
}
.sd__pill--ok { background: #ecfdf5; color: #047857; }
.sd__pill--warn { background: #fff7ed; color: #c2410c; }
.sd__stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr));
  gap: 0.55rem;
}
.sd__stats article,
.sd__folio-stats article {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.75rem;
  background: #f8fafc;
}
.sd__stats span,
.sd__folio-stats span {
  font-size: 0.7rem;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.sd__stats strong,
.sd__folio-stats strong {
  font-size: 0.95rem;
  color: #1c2830;
}
.sd__stats small { font-size: 0.72rem; color: #7b8d9a; font-weight: 600; }
.sd__folio-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
  gap: 0.55rem;
}
.sd__journey {
  padding: 0.85rem 0.95rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.85rem;
  background: #fff;
}
.sd__journey h4 { margin: 0 0 0.75rem; font-size: 0.92rem; }
.sd__journey ol {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 0.35rem;
}
.sd__journey li {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  text-align: center;
  font-size: 0.72rem;
  color: #94a3b8;
  font-weight: 650;
}
.sd__journey li i {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 999px;
  background: #dbe3ea;
}
.sd__journey-step--done { color: #3d5c73; }
.sd__journey-step--done i { background: var(--color-brand-600, var(--color-brand-600)); }
.sd__journey-step--current { color: #047857; }
.sd__journey-step--current i { background: #047857; box-shadow: 0 0 0 4px #d1fae5; }
.sd__grid {
  display: grid;
  gap: 0.85rem;
  grid-template-columns: 1fr;
}
@media (min-width: 900px) {
  .sd__grid { grid-template-columns: 1fr 1fr minmax(14rem, 0.95fr); }
}
.sd__aside {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}
.sd__sign-panel {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  align-items: flex-start;
}
.sd__sign-img {
  max-width: 100%;
  width: 100%;
  max-height: 7rem;
  object-fit: contain;
  border: 1px solid #d7e2ea;
  border-radius: 0.65rem;
  background: #fff;
  padding: 0.35rem;
}
.sd__quick {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
.sd__quick-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  width: 100%;
  text-align: left;
  border: 1px solid #d7e2ea;
  border-radius: 0.7rem;
  background: #fff;
  padding: 0.55rem 0.7rem;
  font-size: 0.82rem;
  font-weight: 650;
  color: #1c2830;
  cursor: pointer;
}
.sd__quick-btn:hover:not(:disabled) {
  border-color: var(--color-brand-500, var(--color-brand-600));
  background: #f3f6f8;
}
.sd__quick-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.sd__quick-btn :deep(svg) { color: var(--color-brand-600, var(--color-brand-600)); flex-shrink: 0; }
.sd__card {
  border: 1px solid #e4e8ec;
  border-radius: 0.85rem;
  padding: 0.9rem 1rem;
  background: #fff;
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}
.sd__card h4 { margin: 0; font-size: 0.95rem; }
.sd__card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}
.sd__kv { margin: 0; display: grid; gap: 0.55rem; }
.sd__kv > div {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: baseline;
}
.sd__kv dt { font-size: 0.78rem; color: #7b8d9a; }
.sd__kv dd { margin: 0; font-size: 0.88rem; font-weight: 650; color: #1c2830; text-align: right; }
.sd__kv--3 {
  grid-template-columns: 1fr;
}
@media (min-width: 720px) {
  .sd__kv--3 { grid-template-columns: repeat(3, 1fr); }
  .sd__kv--3 > div { flex-direction: column; align-items: flex-start; }
  .sd__kv--3 dd { text-align: left; }
}
.sd__sign-box {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0.7rem 0.8rem;
  border-radius: 0.7rem;
  background: #f8fafc;
  border: 1px solid #e8eef3;
}
.sd__guest-list p {
  margin: 0 0 0.4rem;
  font-size: 0.78rem;
  color: #7b8d9a;
  font-weight: 650;
}
.sd__guest-list article {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.65rem 0.75rem;
  border-radius: 0.7rem;
  border: 1px solid #e8eef3;
  background: #f8fafc;
}
.sd__guest-list small { color: #7b8d9a; }
.sd__tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  padding: 0.2rem;
  border-radius: 0.75rem;
  background: #eef3f7;
}
.sd__tab {
  border: 0;
  background: transparent;
  border-radius: 0.55rem;
  padding: 0.45rem 0.8rem;
  font-size: 0.8rem;
  font-weight: 650;
  color: #64748b;
  cursor: pointer;
}
.sd__tab--on {
  background: #fff;
  color: #1c2830;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.sd__table-wrap { overflow: auto; }
.sd__table { min-width: 40rem; }
.sd__tx-type { display: flex; flex-direction: column; gap: 0.1rem; }
.sd__tx-type small { color: #7b8d9a; }
.sd__room-body {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}
.sd__room-body p { margin: 0.15rem 0; color: #64748b; font-size: 0.84rem; }
.sd__room-body small { color: #94a3b8; }
.sd__room-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.15rem;
}
.sd__room-meta span { font-size: 0.72rem; color: #7b8d9a; }
.sd__room-meta em { font-style: normal; font-size: 0.72rem; font-weight: 700; color: #1d4ed8; }
.sd__actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.sd__timeline {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}
.sd__timeline--rich {
  gap: 0;
  position: relative;
}
.sd__timeline--rich li {
  display: grid;
  grid-template-columns: 1rem 1fr;
  gap: 0.7rem;
  align-items: flex-start;
  padding: 0.65rem 0.25rem 0.65rem 0;
  border: 0;
  background: transparent;
  border-radius: 0;
  position: relative;
}
.sd__timeline--rich li + li {
  border-top: 1px solid #eef2f6;
}
.sd__timeline-dot {
  width: 0.55rem;
  height: 0.55rem;
  margin-top: 0.35rem;
  border-radius: 999px;
  background: var(--color-brand-600, var(--color-brand-600));
  box-shadow: 0 0 0 3px #e8f0f5;
  flex-shrink: 0;
}
.sd__chrono h4 { margin: 0 0 0.35rem; }
.sd__timeline li {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  padding: 0.55rem 0.65rem;
  border-radius: 0.65rem;
  background: #f8fafc;
  border: 1px solid #e8eef3;
}
.sd__timeline strong { font-size: 0.84rem; color: #1c2830; }
.sd__timeline span { font-size: 0.74rem; color: #7b8d9a; }
@media (max-width: 720px) {
  .sd__journey ol { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.sd { display: flex; flex-direction: column; gap: 1rem; }
.sd__hero {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
  flex-wrap: wrap;
}
.sd__hero-main {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.sd__hero h3 { margin: 0 0 0.35rem; font-size: 1.2rem; }
.sd__pills { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.sd__pill {
  display: inline-flex;
  align-items: center;
  padding: 0.18rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  background: #eef2f6;
  color: #475569;
}
.sd__pill--ok { background: #ecfdf5; color: #047857; }
.sd__pill--warn { background: #fff7ed; color: #c2410c; }
.sd__stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr));
  gap: 0.55rem;
}
.sd__stats article,
.sd__folio-stats article {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.75rem;
  background: #f8fafc;
}
.sd__stats span,
.sd__folio-stats span {
  font-size: 0.7rem;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.sd__stats strong,
.sd__folio-stats strong {
  font-size: 0.95rem;
  color: #1c2830;
}
.sd__stats small { font-size: 0.72rem; color: #7b8d9a; font-weight: 600; }
.sd__folio-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
  gap: 0.55rem;
}
.sd__journey {
  padding: 0.85rem 0.95rem;
  border: 1px solid #e4e8ec;
  border-radius: 0.85rem;
  background: #fff;
}
.sd__journey h4 { margin: 0 0 0.75rem; font-size: 0.92rem; }
.sd__journey ol {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 0.35rem;
}
.sd__journey li {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  text-align: center;
  font-size: 0.72rem;
  color: #94a3b8;
  font-weight: 650;
}
.sd__journey li i {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 999px;
  background: #dbe3ea;
}
.sd__journey-step--done { color: #3d5c73; }
.sd__journey-step--done i { background: var(--color-brand-600, var(--color-brand-600)); }
.sd__journey-step--current { color: #047857; }
.sd__journey-step--current i { background: #047857; box-shadow: 0 0 0 4px #d1fae5; }
.sd__grid {
  display: grid;
  gap: 0.85rem;
  grid-template-columns: 1fr;
}
@media (min-width: 900px) {
  .sd__grid { grid-template-columns: 1fr 1fr minmax(14rem, 0.95fr); }
}
.sd__aside {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}
.sd__sign-panel {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  align-items: flex-start;
}
.sd__sign-img {
  max-width: 100%;
  width: 100%;
  max-height: 7rem;
  object-fit: contain;
  border: 1px solid #d7e2ea;
  border-radius: 0.65rem;
  background: #fff;
  padding: 0.35rem;
}
.sd__quick {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
.sd__quick-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  width: 100%;
  text-align: left;
  border: 1px solid #d7e2ea;
  border-radius: 0.7rem;
  background: #fff;
  padding: 0.55rem 0.7rem;
  font-size: 0.82rem;
  font-weight: 650;
  color: #1c2830;
  cursor: pointer;
}
.sd__quick-btn:hover:not(:disabled) {
  border-color: var(--color-brand-500, var(--color-brand-600));
  background: #f3f6f8;
}
.sd__quick-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.sd__quick-btn :deep(svg) { color: var(--color-brand-600, var(--color-brand-600)); flex-shrink: 0; }
.sd__card {
  border: 1px solid #e4e8ec;
  border-radius: 0.85rem;
  padding: 0.9rem 1rem;
  background: #fff;
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}
.sd__card h4 { margin: 0; font-size: 0.95rem; }
.sd__card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}
.sd__kv { margin: 0; display: grid; gap: 0.55rem; }
.sd__kv > div {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: baseline;
}
.sd__kv dt { font-size: 0.78rem; color: #7b8d9a; }
.sd__kv dd { margin: 0; font-size: 0.88rem; font-weight: 650; color: #1c2830; text-align: right; }
.sd__kv--3 {
  grid-template-columns: 1fr;
}
@media (min-width: 720px) {
  .sd__kv--3 { grid-template-columns: repeat(3, 1fr); }
  .sd__kv--3 > div { flex-direction: column; align-items: flex-start; }
  .sd__kv--3 dd { text-align: left; }
}
.sd__sign-box {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0.7rem 0.8rem;
  border-radius: 0.7rem;
  background: #f8fafc;
  border: 1px solid #e8eef3;
}
.sd__guest-list p {
  margin: 0 0 0.4rem;
  font-size: 0.78rem;
  color: #7b8d9a;
  font-weight: 650;
}
.sd__guest-list article {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.65rem 0.75rem;
  border-radius: 0.7rem;
  border: 1px solid #e8eef3;
  background: #f8fafc;
}
.sd__guest-list small { color: #7b8d9a; }
.sd__tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  padding: 0.2rem;
  border-radius: 0.75rem;
  background: #eef3f7;
}
.sd__tab {
  border: 0;
  background: transparent;
  border-radius: 0.55rem;
  padding: 0.45rem 0.8rem;
  font-size: 0.8rem;
  font-weight: 650;
  color: #64748b;
  cursor: pointer;
}
.sd__tab--on {
  background: #fff;
  color: #1c2830;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.sd__table-wrap { overflow: auto; }
.sd__table { min-width: 40rem; }
.sd__tx-type { display: flex; flex-direction: column; gap: 0.1rem; }
.sd__tx-type small { color: #7b8d9a; }
.sd__room-body {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}
.sd__room-body p { margin: 0.15rem 0; color: #64748b; font-size: 0.84rem; }
.sd__room-body small { color: #94a3b8; }
.sd__room-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.15rem;
}
.sd__room-meta span { font-size: 0.72rem; color: #7b8d9a; }
.sd__room-meta em { font-style: normal; font-size: 0.72rem; font-weight: 700; color: #1d4ed8; }
.sd__actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.sd__timeline {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}
.sd__timeline--rich {
  gap: 0;
  position: relative;
}
.sd__timeline--rich li {
  display: grid;
  grid-template-columns: 1rem 1fr;
  gap: 0.7rem;
  align-items: flex-start;
  padding: 0.65rem 0.25rem 0.65rem 0;
  border: 0;
  background: transparent;
  border-radius: 0;
  position: relative;
}
.sd__timeline--rich li + li {
  border-top: 1px solid #eef2f6;
}
.sd__timeline-dot {
  width: 0.55rem;
  height: 0.55rem;
  margin-top: 0.35rem;
  border-radius: 999px;
  background: var(--color-brand-600, var(--color-brand-600));
  box-shadow: 0 0 0 3px #e8f0f5;
  flex-shrink: 0;
}
.sd__chrono h4 { margin: 0 0 0.35rem; }
.sd__timeline li {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  padding: 0.55rem 0.65rem;
  border-radius: 0.65rem;
  background: #f8fafc;
  border: 1px solid #e8eef3;
}
.sd__timeline strong { font-size: 0.84rem; color: #1c2830; }
.sd__timeline span { font-size: 0.74rem; color: #7b8d9a; }
@media (max-width: 720px) {
  .sd__journey ol { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.stay__form--modal {
  padding: 0;
  border: 0;
  background: transparent;
}
.stay__intro-text {
  margin: 0 0 0.85rem;
  font-size: 0.875rem;
  color: #66727c;
  line-height: 1.45;
}
.stay__error--inline {
  margin: 0;
}
.stay-card__signed { color: #047857; font-weight: 650; }
.stay-sign { display: flex; flex-direction: column; gap: 0.85rem; }
.stay-sign__head h4 { margin: 0; font-size: 1.1rem; color: #0f172a; }
.stay-sign__head p { margin: 0.2rem 0 0; color: #64748b; font-size: 0.88rem; }
.stay-sign__tabs {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.2rem;
  border-radius: 0.7rem;
  background: #eef3f7;
  width: fit-content;
}
.stay-sign__tab {
  border: 0;
  background: transparent;
  border-radius: 0.55rem;
  padding: 0.4rem 0.85rem;
  font-size: 0.82rem;
  font-weight: 650;
  color: #64748b;
  cursor: pointer;
}
.stay-sign__tab--on {
  background: #fff;
  color: #1c2830;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.08);
}
.stay-sign__scan {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.65rem;
  text-align: center;
}
.stay-sign__scan h5 {
  margin: 0;
  font-size: 0.95rem;
  color: #1c2830;
}
.stay-sign__hint {
  margin: 0;
  font-size: 0.82rem;
  color: #64748b;
  line-height: 1.45;
  max-width: 28rem;
}
.stay-sign__qr {
  width: 11rem;
  height: 11rem;
  border-radius: 0.75rem;
  border: 1px solid #e2e8f0;
  background: #fff;
}
.stay-sign__link-box {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  align-items: stretch;
}
.stay-sign__url {
  display: block;
  padding: 0.55rem 0.7rem;
  border-radius: 0.6rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  color: var(--color-brand-700, #3d5c73);
  font-size: 0.72rem;
  word-break: break-all;
  text-align: left;
  text-decoration: none;
}
.stay-sign__waiting {
  margin: 0.25rem 0 0;
  font-size: 0.84rem;
  color: #64748b;
  font-weight: 600;
}
.stay-sign__done {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.45rem;
  padding: 1.25rem 1rem;
  border-radius: 14px;
  background: #ecfdf5;
  border: 1px solid #a7f3d0;
  text-align: center;
  color: #065f46;
}
.stay-sign__done h5 {
  margin: 0;
  font-size: 1.05rem;
  color: #064e3b;
}
.stay-sign__done p {
  margin: 0;
  font-size: 0.9rem;
  color: #047857;
  max-width: 22rem;
}
.stay-sign__skip { width: 100%; }
.stay-sign__draw { display: flex; flex-direction: column; gap: 0.55rem; }
.stay-sign__canvas {
  width: 100%; height: 160px; border: 1.5px dashed #94a3b8; border-radius: 0.75rem;
  background: #fff; touch-action: none; cursor: crosshair;
}
.stay__form,
.stay__list {
  padding: 1.15rem 1.2rem 1.3rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.9rem;
  background: #fff;
  min-height: 0;
}
.stay__intro h2,
.stay__list-head h3,
.stay__block h3 {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  color: #1c2830;
}
.stay__intro h2 { font-size: 1.05rem; }
.stay__intro p { margin: 0.35rem 0 0; font-size: 0.875rem; color: #66727c; line-height: 1.45; }
.stay__heading-icon {
  display: inline-flex; align-items: center; justify-content: center;
  width: 1.7rem; height: 1.7rem; border-radius: 0.45rem;
  background: #eef4f8; color: var(--color-brand-600, var(--color-brand-600));
}

.stay__steps {
  list-style: none;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.4rem;
  margin: 1rem 0 0;
  padding: 0;
}
.stay__step {
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
  border: 0;
  background: transparent;
  color: #7b8d9a;
  font-size: 0.72rem;
  font-weight: 650;
  cursor: pointer;
}
.stay__step span {
  width: 1.7rem; height: 1.7rem; border-radius: 999px;
  display: inline-flex; align-items: center; justify-content: center;
  background: #e8eef3; color: #5b6d7a; font-size: 0.78rem;
}
.stay__step--on { color: var(--color-brand-700, #3d5c73); }
.stay__step--on span,
.stay__step--done span { background: var(--color-brand-600, var(--color-brand-600)); color: #fff; }

.stay__error {
  margin: 0.85rem 0 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fef2f2;
  color: #b91c1c;
  font-size: 0.85rem;
}
.stay__notice {
  margin: 0;
  padding: 0.7rem 0.85rem;
  border-radius: 0.7rem;
  background: #fff8eb;
  color: #92400e;
  font-size: 0.85rem;
}
.stay__block { margin-top: 1.2rem; display: flex; flex-direction: column; gap: 0.7rem; }
.stay__block h3 { font-size: 0.92rem; }
.stay__block h3 :deep(svg) { color: var(--color-brand-600, var(--color-brand-600)); }
.stay__label {
  margin: 0;
  font-size: 0.78rem;
  font-weight: 650;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.stay__hint { margin: 0; font-size: 0.72rem; color: #94a3b8; }
.stay__guest-banner {
  display: flex; align-items: center; gap: 0.5rem;
  margin-top: 1rem; padding: 0.7rem 0.85rem;
  border-radius: 0.75rem; background: #eef4f8; color: #1c2830;
}
.stay__guest-banner strong { font-size: 1rem; }
.stay__pay-modes { display: grid; gap: 0.55rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .stay__pay-modes { grid-template-columns: 1fr 1fr; }
}
.stay__pay-card {
  position: relative; display: flex; flex-direction: column; gap: 0.25rem;
  border: 1px solid #d7e2ea; border-radius: 0.8rem; padding: 0.8rem 0.85rem; cursor: pointer; background: #fff;
}
.stay__pay-card input { position: absolute; opacity: 0; pointer-events: none; }
.stay__pay-card strong { font-size: 0.86rem; color: #1c2830; }
.stay__pay-card span { font-size: 0.72rem; color: #7b8d9a; line-height: 1.35; }
.stay__pay-card--on { border-color: var(--color-brand-500); background: #f3f6f8; }
.stay__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.stay__money span { font-weight: 700; color: #3d5c73; }
.stay__due {
  display: flex; flex-direction: column; gap: 0.2rem;
  min-height: 2.4rem; justify-content: center;
  padding: 0.45rem 0.65rem; border-radius: 0.65rem; background: #f8fafc; border: 1px solid #e4e8ec;
}
.stay__due strong { font-size: 0.95rem; color: #1c2830; }
.stay__due small { font-size: 0.72rem; }
.stay__due--ok { color: #047857; font-weight: 650; }
.stay__due--credit { color: #b45309; }
.stay__due--partial { color: #1d4ed8; }
.stay__sig-reception { display: flex; flex-direction: column; gap: 0.35rem; }
.stay__sig-auto {
  margin: 0; padding: 0.7rem 0.8rem; border-radius: 0.7rem;
  background: #f8fafc; border: 1px solid #e4e8ec; font-size: 0.84rem; color: #334155; line-height: 1.4;
}
.stay__dotted {
  padding: 1.4rem 0.8rem 0.5rem; border-bottom: 2px dotted #94a3b8;
  color: #94a3b8; letter-spacing: 0.12em; font-size: 1.1rem;
}
.stay__blank-sig {
  min-height: 4.5rem; border: 1px dashed #c5d3dc; border-radius: 0.75rem;
  display: flex; align-items: center; justify-content: center;
  color: #94a3b8; font-size: 0.8rem; background: #f8fafc;
}
.stay__link { color: var(--color-brand-600, var(--color-brand-600)); font-weight: 600; text-decoration: none; }
.stay__grid { display: grid; gap: 0.85rem 1rem; grid-template-columns: 1fr; }
@media (min-width: 720px) {
  .stay__grid { grid-template-columns: 1fr 1fr; }
  .stay__span { grid-column: 1 / -1; }
}
.stay__modes { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.stay__mode {
  display: inline-flex; align-items: center; gap: 0.35rem;
  border: 1px solid #d7e2ea; border-radius: 999px; padding: 0.35rem 0.7rem;
  font-size: 0.8rem; cursor: pointer; background: #fff;
}
.stay__mode input { accent-color: var(--color-brand-600); }
.stay__mode--on { border-color: var(--color-brand-500); background: #f3f6f8; }
.stay__pick { display: flex; flex-direction: column; gap: 0.45rem; }
.stay__picked {
  display: flex; flex-direction: column; gap: 0.15rem;
  padding: 0.65rem 0.75rem; border-radius: 0.7rem; background: #f3f6f8; border: 1px solid #d7e2ea;
}
.stay__picked strong { font-size: 0.9rem; color: #1c2830; }
.stay__picked small { color: #7b8d9a; }
.stay__customer-list {
  max-height: 10rem; overflow: auto; border: 1px solid #e4e8ec; border-radius: 0.7rem;
  display: flex; flex-direction: column;
}
.stay__customer {
  display: flex; flex-direction: column; gap: 0.1rem; text-align: left;
  padding: 0.55rem 0.7rem; border: 0; border-bottom: 1px solid #eef2f6; background: #fff; cursor: pointer;
}
.stay__customer:hover { background: #f8fafc; }
.stay__customer strong { font-size: 0.84rem; color: #1c2830; }
.stay__customer small { font-size: 0.72rem; color: #7b8d9a; }
.stay__drop {
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 0.45rem;
  min-height: 7.5rem; border: 1.5px dashed #c5d3dc; border-radius: 0.85rem;
  background: #f8fafc; color: #64748b; cursor: pointer; text-align: center; padding: 0.9rem;
}
.stay__drop strong { font-size: 0.82rem; font-weight: 600; color: #334155; }
.stay__drop-preview { max-height: 5.5rem; border-radius: 0.4rem; object-fit: contain; }
.sr-only {
  position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
  overflow: hidden; clip: rect(0, 0, 0, 0); border: 0;
}
.stay__summary {
  margin: 0;
  display: grid;
  gap: 0.65rem;
}
.stay__summary div {
  display: grid;
  gap: 0.15rem;
  padding: 0.65rem 0.75rem;
  border: 1px solid #e8eef3;
  border-radius: 0.7rem;
  background: #f8fafc;
}
.stay__summary dt { font-size: 0.72rem; color: #7b8d9a; text-transform: uppercase; letter-spacing: 0.03em; }
.stay__summary dd { margin: 0; font-size: 0.9rem; font-weight: 650; color: #1c2830; }
.stay__recap {
  margin: 0;
  display: grid;
  gap: 0.55rem;
  grid-template-columns: 1fr;
}
@media (min-width: 720px) {
  .stay__recap { grid-template-columns: 1fr 1fr; }
  .stay__recap-span { grid-column: 1 / -1; }
}
.stay__recap > div {
  display: grid;
  gap: 0.15rem;
  padding: 0.6rem 0.7rem;
  border: 1px solid #e8eef3;
  border-radius: 0.65rem;
  background: #f8fafc;
}
.stay__recap dt {
  font-size: 0.7rem;
  color: #7b8d9a;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.stay__recap dd {
  margin: 0;
  font-size: 0.88rem;
  font-weight: 650;
  color: #1c2830;
  word-break: break-word;
}
.stay__totals {
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0.75rem 0.85rem;
  border: 1px solid #d7e2ea;
  border-radius: 0.8rem;
  background: #f8fafc;
}
.stay__totals > div {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: baseline;
}
.stay__totals dt { font-size: 0.84rem; color: #64748b; }
.stay__totals dd { margin: 0; font-size: 0.88rem; font-weight: 650; color: #1c2830; }
.stay__totals-total {
  margin-top: 0.35rem;
  padding-top: 0.55rem;
  border-top: 1px solid #d7e2ea;
}
.stay__totals-total dt,
.stay__totals-total dd {
  font-size: 0.95rem;
  font-weight: 750;
  color: #0f172a;
}
.stay__confirm-hint {
  margin: 0.65rem 0 0;
  font-size: 0.78rem;
  color: #7b8d9a;
  line-height: 1.4;
}
.stay__actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.1rem; }
.stay__empty, .stay__muted { margin: 0; padding: 1.2rem; text-align: center; color: #7b8d9a; font-size: 0.85rem; }
.text-brand-600 { color: var(--color-brand-600); }

.sd__amenities,
.co__status {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.sd__amenities {
  margin-top: 0.65rem;
}

.sd__amenity {
  display: inline-flex;
  align-items: center;
  gap: 0.28rem;
  padding: 0.22rem 0.5rem;
  border: 1px solid #d7e2ea;
  border-radius: 999px;
  background: #f8fafc;
  font-size: 0.72rem;
  color: #334155;
}

.co__title {
  margin: 1rem 0 0.55rem;
  font-size: 0.88rem;
  color: #1c2830;
}

.co__list {
  margin: 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  max-height: 22rem;
  overflow: auto;
}

.co__item {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  padding: 0.7rem 0.75rem;
  border: 1px solid #e8eef3;
  border-radius: 0.75rem;
  background: #fff;
}

.co__head {
  display: flex;
  justify-content: space-between;
  gap: 0.6rem;
  align-items: center;
}

.co__head strong {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.86rem;
  color: #1c2830;
}

.co__head small { color: #7b8d9a; font-size: 0.75rem; }

.co__pill {
  border: 1px solid #d7e2ea;
  border-radius: 999px;
  background: #fff;
  padding: 0.28rem 0.6rem;
  font-size: 0.72rem;
  cursor: pointer;
  color: #475569;
}

.co__pill--ok { background: #ecfdf5; color: #047857; border-color: #a7f3d0; font-weight: 700; }
.co__pill--missing { background: #fef2f2; color: #b91c1c; border-color: #fecaca; font-weight: 700; }
.co__pill--damaged { background: #fffbeb; color: #b45309; border-color: #fde68a; font-weight: 700; }

.co__amount {
  display: grid;
  gap: 0.25rem;
  font-size: 0.72rem;
  color: #64748b;
}

.co__total {
  margin-top: 0.85rem;
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  align-items: center;
  padding: 0.7rem 0.8rem;
  border-radius: 0.75rem;
  background: #f8fafc;
  border: 1px solid #e8eef3;
}

.co__total span { font-size: 0.78rem; color: #64748b; }
.co__total strong { font-size: 0.95rem; color: #0f172a; }
</style>
