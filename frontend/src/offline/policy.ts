import type { OfflineDomain } from './types'
import { isUuid } from './uuid'

export interface ClassifiedWrite {
  domain: OfflineDomain
  entityType: string
  operation: string
  entityId: string | null
  payload: Record<string, unknown>
}

const RESTAURANT = new Set([
  'open_order', 'add_line', 'send_course', 'set_ticket_status', 'split_lines', 'pay_check',
  'charge_room', 'upsert_zone', 'delete_zone', 'upsert_table', 'delete_table',
])

const HOTEL = new Set([
  'create_reservation', 'upsert_reservation', 'delete_reservation', 'check_in', 'walk_in_check_in',
  'check_out', 'post_folio', 'change_stay_room', 'collect_stay_payment',
  'set_room_housekeeping', 'upsert_housekeeping_task', 'delete_housekeeping_task', 'set_housekeeping_task_status',
  'upsert_room_type', 'delete_room_type', 'upsert_amenity', 'delete_amenity',
  'upsert_building', 'delete_building', 'upsert_wing', 'delete_wing', 'upsert_floor', 'delete_floor',
  'upsert_room', 'delete_room', 'upsert_hotel_settings', 'upsert_concierge_request',
  'delete_concierge_request', 'set_concierge_status',
])

const SKIPPED_ACTIONS = new Set(['create_stay_sign_link', 'submit_stay_signature'])

const REFERENCE_KEYS = [
  'sale_id', 'cashier_shift_id', 'customer_id', 'order_id', 'reservation_id',
  'check_id', 'stay_id', 'room_id', 'table_id',
]

export function isCacheableRead(path: string): boolean {
  return path.startsWith('/hospitality')
    || path.startsWith('/sync/references')
    || path === '/me/cashier-shifts/current'
    || /^\/stores\/[^/]+\/pos\/catalog/.test(path)
    || /^\/stores\/[^/]+\/cash-registers/.test(path)
}

export function classifyWrite(method: string, path: string, body: unknown): ClassifiedWrite | null {
  const verb = method.toUpperCase()
  const payload = isRecord(body) ? { ...body } : {}

  const saleCreate = path.match(/^\/stores\/([^/]+)\/sales$/)
  if (verb === 'POST' && saleCreate) {
    return { domain: 'pos', entityType: 'sale', operation: 'create', entityId: null, payload }
  }

  const hold = path.match(/^\/stores\/([^/]+)\/sales\/holds$/)
  if (verb === 'POST' && hold) {
    return { domain: payload.table_id ? 'restaurant' : 'pos', entityType: 'sale', operation: 'hold', entityId: null, payload }
  }

  const saleItem = path.match(/^\/sales\/([^/]+)$/)
  if (saleItem && (verb === 'PUT' || verb === 'PATCH')) {
    return {
      domain: payload.table_id ? 'restaurant' : 'pos',
      entityType: 'sale',
      operation: 'update',
      entityId: saleItem[1],
      payload,
    }
  }
  if (saleItem && verb === 'DELETE') {
    return { domain: 'pos', entityType: 'sale', operation: 'delete', entityId: saleItem[1], payload }
  }

  if (verb === 'POST' && path === '/customers') {
    return { domain: 'pos', entityType: 'customer', operation: 'create', entityId: null, payload }
  }

  if (verb === 'POST' && path === '/hospitality/actions') {
    const action = typeof payload.action === 'string' ? payload.action : ''
    if (!action || SKIPPED_ACTIONS.has(action)) return null
    if (RESTAURANT.has(action)) {
      return { domain: 'restaurant', entityType: 'desk', operation: action, entityId: null, payload }
    }
    if (HOTEL.has(action)) {
      return { domain: 'hotel', entityType: 'desk', operation: action, entityId: null, payload }
    }
    return null
  }

  const cash = classifyCash(verb, path, payload)
  if (cash) return cash

  return null
}

function classifyCash(method: string, path: string, payload: Record<string, unknown>): ClassifiedWrite | null {
  if (method !== 'POST') return null
  const openPin = path.match(/^\/cash-registers\/([^/]+)\/cashier-shifts\/open-with-pin$/)
  const open = path.match(/^\/cash-registers\/([^/]+)\/cashier-shifts\/open$/)
  const closePin = path.match(/^\/cash-registers\/([^/]+)\/cashier-shifts\/close-with-pin$/)
  const close = path.match(/^\/cash-registers\/([^/]+)\/cashier-shifts\/close$/)
  const movement = path.match(/^\/cash-registers\/([^/]+)\/cashier-shifts\/([^/]+)\/movements$/)
  const sessionOpen = path.match(/^\/cash-registers\/([^/]+)\/sessions\/open$/)
  const sessionClose = path.match(/^\/cash-registers\/([^/]+)\/sessions\/close$/)
  const registerMovement = path.match(/^\/cash-registers\/([^/]+)\/movements$/)

  if (openPin || open) {
    const registerId = (openPin ?? open)![1]
    return { domain: 'cash_register', entityType: 'cashier_shift', operation: 'open', entityId: null, payload: { ...payload, cash_register_id: registerId } }
  }
  if (closePin || close) {
    const registerId = (closePin ?? close)![1]
    return { domain: 'cash_register', entityType: 'cashier_shift', operation: 'close', entityId: null, payload: { ...payload, cash_register_id: registerId } }
  }
  if (movement) {
    return {
      domain: 'cash_register',
      entityType: 'cash_movement',
      operation: 'movement',
      entityId: null,
      payload: { ...payload, cash_register_id: movement[1], cashier_shift_id: movement[2] },
    }
  }
  if (sessionOpen) {
    return { domain: 'cash_register', entityType: 'cash_session', operation: 'open_session', entityId: null, payload: { ...payload, cash_register_id: sessionOpen[1] } }
  }
  if (sessionClose) {
    return { domain: 'cash_register', entityType: 'cash_session', operation: 'close_session', entityId: null, payload: { ...payload, cash_register_id: sessionClose[1] } }
  }
  if (registerMovement) {
    return { domain: 'cash_register', entityType: 'cash_movement', operation: 'movement', entityId: null, payload: { ...payload, cash_register_id: registerMovement[1] } }
  }
  return null
}

export function referencedIds(payload: Record<string, unknown>): string[] {
  const ids: string[] = []
  for (const key of REFERENCE_KEYS) {
    const value = payload[key]
    if (typeof value === 'string' && value !== '') ids.push(value)
  }
  return ids
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

export function versionTarget(action: string, payload: Record<string, unknown>): string | null {
  const pick = (...keys: string[]) => {
    for (const key of keys) {
      const value = payload[key]
      if (typeof value === 'string' && value !== '') return value
    }
    return null
  }
  switch (action) {
    case 'open_order': return pick('table_id')
    case 'add_line':
    case 'send_course':
    case 'pay_check':
    case 'charge_room':
    case 'split_lines':
      return pick('order_id')
    case 'set_ticket_status': return pick('ticket_id')
    case 'check_in':
    case 'check_out':
    case 'change_stay_room':
    case 'collect_stay_payment':
      return pick('reservation_id', 'stay_id')
    case 'post_folio':
    case 'set_room_housekeeping':
      return pick('room_id')
    default:
      return pick('id')
  }
}

export { isUuid }
