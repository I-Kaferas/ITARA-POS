export type HotelDoc = Record<string, any>

export type DailyPoint = { date: string; cents: number }
export type MonthlyPoint = { key: string; label: string; cents: number; occupancy: number; nights: number }
export type TypePoint = { id: string; name: string; cents: number; stays: number }
export type HkPoint = { id: string; count: number }

export type HotelReport = {
  from: string
  to: string
  currency: string
  roomCount: number
  occupiedToday: number
  availableToday: number
  occupancyToday: number
  stayCount: number
  roomNights: number
  avgStayNights: number
  revenueCents: number
  adrCents: number
  revparCents: number
  openHkTasks: number
  daily: DailyPoint[]
  monthly: MonthlyPoint[]
  byType: TypePoint[]
  hk: HkPoint[]
  reservations: {
    total: number
    confirmed: number
    pending: number
    cancelled: number
  }
}

const HK_ORDER = ['clean', 'dirty', 'cleaning', 'inspected', 'maintenance', 'out_of_service'] as const
type HkStatus = (typeof HK_ORDER)[number]

function hkStatusOf(room: HotelDoc): HkStatus {
  const status = String(room.housekeeping_status ?? 'clean')
  return (HK_ORDER as readonly string[]).includes(status) ? status as HkStatus : 'clean'
}

export function toIsoDate(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function parseIsoDate(iso: string): Date {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  return new Date(y, (m || 1) - 1, d || 1)
}

export function addDaysIso(iso: string, days: number): string {
  const d = parseIsoDate(iso)
  d.setDate(d.getDate() + days)
  return toIsoDate(d)
}

export function lastDaysRange(days: number, today = new Date()): { from: string; to: string } {
  const to = toIsoDate(today)
  return { from: addDaysIso(to, 1 - days), to }
}

export function daysBetween(from: string, to: string): number {
  const a = parseIsoDate(from).getTime()
  const b = parseIsoDate(to).getTime()
  return Math.round((b - a) / 86400000)
}

function dayKey(value?: string | null): string {
  if (!value) return ''
  return String(value).slice(0, 10)
}

function maxIso(a: string, b: string) {
  return a > b ? a : b
}

function minIso(a: string, b: string) {
  return a < b ? a : b
}

/** Hotel nights overlapping [from, to] inclusive, using checkout as exclusive. */
export function overlapNights(arrive: string, depart: string, from: string, to: string): number {
  const start = maxIso(dayKey(arrive) || from, from)
  const endExclusive = minIso(dayKey(depart) || addDaysIso(to, 1), addDaysIso(to, 1))
  return Math.max(0, daysBetween(start, endExclusive))
}

function isActiveRoom(room: HotelDoc) {
  return room.is_active !== false && room.status !== 'inactive'
}

function isOccupiedRoom(room: HotelDoc, stays: HotelDoc[]) {
  if (String(room.status ?? '') === 'occupied') return true
  return stays.some(s => s.room_id === room.id && s.status === 'checked_in')
}

function folioOf(stay: HotelDoc, folios: HotelDoc[]) {
  if (stay.folio_id) return folios.find(f => f.id === stay.folio_id) ?? null
  return folios.find(f => f.reservation_id === stay.id) ?? null
}

export function stayRevenueCents(stay: HotelDoc, folios: HotelDoc[]): number {
  const folio = folioOf(stay, folios)
  if (folio?.lines && Array.isArray(folio.lines)) {
    const paid = folio.lines
      .filter((line: HotelDoc) => String(line.kind) === 'payment')
      .reduce((sum: number, line: HotelDoc) => sum + Math.abs(Number(line.amount || 0)), 0)
    if (paid > 0) return paid
    const charges = folio.lines
      .filter((line: HotelDoc) => String(line.kind) !== 'payment')
      .reduce((sum: number, line: HotelDoc) => sum + Math.max(0, Number(line.amount || 0)), 0)
    if (charges > 0) return charges
  }
  const collected = Number(stay.amount_collected_cents ?? folio?.amount_collected_cents ?? 0)
  if (collected > 0) return collected
  return Math.max(0, Number(stay.amount_due_cents ?? folio?.amount_due_cents ?? 0))
}

function paymentEvents(stay: HotelDoc, folios: HotelDoc[]): { date: string; cents: number }[] {
  const folio = folioOf(stay, folios)
  const events: { date: string; cents: number }[] = []
  if (folio?.lines && Array.isArray(folio.lines)) {
    for (const line of folio.lines) {
      if (String(line.kind) !== 'payment') continue
      const date = dayKey(line.created_at)
      const cents = Math.abs(Number(line.amount || 0))
      if (date && cents > 0) events.push({ date, cents })
    }
  }
  if (!events.length) {
    const cents = Number(stay.amount_collected_cents ?? 0)
    const date = dayKey(stay.checked_in_at || stay.arrive_on)
    if (cents > 0 && date) events.push({ date, cents })
  }
  return events
}

function isStay(doc: HotelDoc) {
  const status = String(doc.status ?? '')
  return doc.kind === 'reservation' && (status === 'checked_in' || status === 'checked_out')
}

export function buildHotelReport(docs: HotelDoc[], from: string, to: string): HotelReport {
  const rooms = docs.filter(d => d.kind === 'room' && isActiveRoom(d))
  const reservations = docs.filter(d => d.kind === 'reservation')
  const folios = docs.filter(d => d.kind === 'folio')
  const settings = docs.find(d => d.kind === 'hotel_settings')
  const currency = String(settings?.currency_code || rooms[0]?.type_currency || 'USD').toUpperCase()

  const types = docs.filter(d => d.kind === 'room_type')
  const stays = reservations.filter(isStay)
  const periodStays = stays.filter(s => overlapNights(dayKey(s.arrive_on), dayKey(s.depart_on), from, to) > 0)
  const roomsById = new Map(rooms.map(r => [String(r.id), r]))
  const typesById = new Map(types.map(t => [String(t.id), t]))

  const occupiedToday = rooms.filter(r => isOccupiedRoom(r, stays)).length
  const roomCount = rooms.length
  const availableToday = Math.max(0, roomCount - occupiedToday)
  const occupancyToday = roomCount ? occupiedToday / roomCount : 0

  let roomNights = 0
  let revenueCents = 0
  const typeMap = new Map<string, TypePoint>()
  for (const stay of periodStays) {
    const nights = overlapNights(dayKey(stay.arrive_on), dayKey(stay.depart_on), from, to)
    roomNights += nights
    const cents = stayRevenueCents(stay, folios)
    revenueCents += cents
    const room = roomsById.get(String(stay.room_id ?? ''))
    const id = String(stay.type_id || room?.type_id || stay.type_name || 'other')
    const name = String(stay.type_name || typesById.get(id)?.name || room?.type_name || id)
    const prev = typeMap.get(id) ?? { id, name, cents: 0, stays: 0 }
    prev.cents += cents
    prev.stays += 1
    typeMap.set(id, prev)
  }

  const stayCount = periodStays.length
  const avgStayNights = stayCount ? roomNights / stayCount : 0
  const adrCents = roomNights ? Math.round(revenueCents / roomNights) : 0
  const revparCents = roomCount ? Math.round(revenueCents / roomCount) : 0

  const openHkTasks = docs.filter(d =>
    d.kind === 'housekeeping_task'
    && !['done', 'cancelled'].includes(String(d.status ?? 'pending')),
  ).length

  const dayCount = Math.max(0, daysBetween(from, to)) + 1
  const dailyMap = new Map<string, number>()
  for (let i = 0; i < dayCount; i++) dailyMap.set(addDaysIso(from, i), 0)

  const foliosWithPayments = new Set<string>()
  for (const folio of folios) {
    if (!Array.isArray(folio.lines)) continue
    for (const line of folio.lines) {
      if (String(line.kind) !== 'payment') continue
      const date = dayKey(line.created_at)
      const cents = Math.abs(Number(line.amount || 0))
      if (!date || cents <= 0 || date < from || date > to) continue
      if (folio.id) foliosWithPayments.add(String(folio.id))
      dailyMap.set(date, (dailyMap.get(date) ?? 0) + cents)
    }
  }
  for (const stay of stays) {
    const folio = folioOf(stay, folios)
    if (folio?.id && foliosWithPayments.has(String(folio.id))) continue
    for (const event of paymentEvents(stay, folios)) {
      if (event.date < from || event.date > to) continue
      dailyMap.set(event.date, (dailyMap.get(event.date) ?? 0) + event.cents)
    }
  }
  const daily = [...dailyMap.entries()].map(([date, cents]) => ({ date, cents }))

  const hkCounts = new Map<string, number>(HK_ORDER.map(id => [id, 0]))
  for (const room of rooms) {
    const key = hkStatusOf(room)
    hkCounts.set(key, (hkCounts.get(key) ?? 0) + 1)
  }
  const hk = HK_ORDER.map(id => ({ id, count: hkCounts.get(id) ?? 0 }))

  const arrived = reservations.filter((r) => {
    const arrive = dayKey(r.arrive_on)
    return arrive >= from && arrive <= to
  })

  let confirmed = 0
  let pending = 0
  let cancelled = 0
  for (const row of arrived) {
    const status = String(row.status ?? 'confirmed')
    if (status === 'cancelled') cancelled++
    else if (status === 'pending' || status === 'reserved') pending++
    else confirmed++
  }

  const monthly: MonthlyPoint[] = []
  const end = parseIsoDate(to)
  for (let i = 5; i >= 0; i--) {
    const cursor = new Date(end.getFullYear(), end.getMonth() - i, 1)
    const monthFrom = toIsoDate(cursor)
    const monthTo = toIsoDate(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0))
    const days = daysBetween(monthFrom, monthTo) + 1
    let cents = 0
    let nights = 0
    for (const stay of stays) {
      const n = overlapNights(dayKey(stay.arrive_on), dayKey(stay.depart_on), monthFrom, monthTo)
      if (n <= 0) continue
      nights += n
      cents += stayRevenueCents(stay, folios)
    }
    monthly.push({
      key: monthFrom.slice(0, 7),
      label: cursor.toLocaleString(undefined, { month: 'short' }),
      cents,
      nights,
      occupancy: roomCount && days ? nights / (roomCount * days) : 0,
    })
  }

  const byType = [...typeMap.values()].sort((a, b) => b.cents - a.cents)

  return {
    from,
    to,
    currency,
    roomCount,
    occupiedToday,
    availableToday,
    occupancyToday,
    stayCount,
    roomNights,
    avgStayNights,
    revenueCents,
    adrCents,
    revparCents,
    openHkTasks,
    daily,
    monthly,
    byType,
    hk,
    reservations: {
      total: arrived.length,
      confirmed,
      pending,
      cancelled,
    },
  }
}
