import { readSnapshot, saveSnapshot } from './storage'
import { isRecord } from './policy'

export type DeskDoc = Record<string, unknown>

export async function rememberHospitality(path: string, body: unknown): Promise<void> {
  await saveSnapshot(cacheKey(path), body)
  const docs = extractDocs(body)
  if (!docs) return
  const current = extractDocs(await readSnapshot<unknown>('hospitality:latest')) ?? []
  const merged = new Map<string, DeskDoc>()
  for (const doc of current) {
    const id = typeof doc.id === 'string' ? doc.id : ''
    if (id) merged.set(id, doc)
  }
  for (const doc of docs) {
    const id = typeof doc.id === 'string' ? doc.id : ''
    if (id) merged.set(id, doc)
  }
  await saveSnapshot('hospitality:latest', { data: { docs: [...merged.values()] } })
}

export async function hospitalityDocs(): Promise<DeskDoc[]> {
  return extractDocs(await readSnapshot<unknown>('hospitality:latest')) ?? []
}

export function cacheKey(path: string): string {
  return `read:${path}`
}

export function extractDocs(body: unknown): DeskDoc[] | null {
  if (!isRecord(body) || !isRecord(body.data) || !Array.isArray(body.data.docs)) return null
  return body.data.docs.filter(isRecord)
}

export function applyOptimistic(docs: DeskDoc[], action: Record<string, unknown>, uuid: string): DeskDoc[] {
  const next = docs.map((doc) => ({ ...doc }))
  const name = typeof action.action === 'string' ? action.action : ''
  const find = (id: unknown) => next.find((doc) => doc.id === id)

  if (name === 'open_order') {
    const table = find(action.table_id)
    if (table) {
      table.status = 'occupied'
      table.order_id = uuid
    }
    next.push({
      id: uuid,
      kind: 'order',
      status: 'open',
      table_id: action.table_id,
      lines: [],
      checks: [{ id: uuid, label: 'Addition 1', status: 'open' }],
      _offline_uuid: uuid,
    })
  } else if (name === 'add_line') {
    const order = find(action.order_id)
    if (order) {
      const lines = Array.isArray(order.lines) ? [...order.lines] : []
      lines.push({
        id: uuid,
        name: action.name,
        quantity: action.quantity ?? 1,
        unit_price: action.unit_price ?? 0,
        course: action.course ?? 'plat',
        check_id: uuid,
      })
      order.lines = lines
    }
  } else if (name === 'pay_check' || name === 'charge_room') {
    const order = find(action.order_id)
    if (order) order.status = 'paid'
  } else if (name === 'create_reservation' || name === 'upsert_reservation' && !action.id) {
    next.push({
      id: uuid,
      kind: 'reservation',
      status: 'confirmed',
      room_id: action.room_id,
      guest_name: action.guest_name,
      _offline_uuid: uuid,
    })
    const room = find(action.room_id)
    if (room) room.status = 'reserved'
  } else if (name === 'walk_in_check_in' || name === 'check_in') {
    const stayId = name === 'check_in' ? action.reservation_id : uuid
    const stay = find(stayId)
    if (stay) stay.status = 'checked_in'
    else next.push({ id: uuid, kind: 'reservation', status: 'checked_in', guest_name: action.guest_name, room_id: action.room_id, _offline_uuid: uuid })
    const room = find(action.room_id ?? stay?.room_id)
    if (room) room.status = 'occupied'
  } else if (name === 'check_out') {
    const stay = find(action.reservation_id ?? action.stay_id)
    if (stay) stay.status = 'checked_out'
  } else if (name === 'post_folio' || name === 'collect_stay_payment') {
    const target = find(action.reservation_id ?? action.room_id)
    if (target) target._offline_uuid = uuid
  }

  return next
}
